-- =============================================================================
-- Khaustan onboarding script: Greens Veg. Restaurant
-- Source: Greens_Veg_Restaurant_Menu.json (OCR JSON from a scanned PDF ("NON AC GREEN.pdf"))
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
--
-- SOURCE-SPECIFIC WARNING: this source JSON is materially more corrupted than
-- the other three restaurants in this batch (garbled item numbers, truncated
-- names, scrambled prices). 339 items were recovered with a confirmed name and
-- price; 92 fragments were excluded outright as unrecoverable rather than guessed
-- at. Every recovered row still carries a lower baseline confidence than the rest
-- of this batch as a result -- see the REVIEW NOTES block, which is unusually long
-- for this file by design.
-- =============================================================================

-- Ensure your pgAdmin4 Query Tool (or other client) is connected to the
-- "KhaustanRestaurantMenu" database before running this script.


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
  WHERE normalized_name = lower(trim('Greens Veg. Restaurant')) AND postal_code = '400066';

  IF NOT FOUND THEN
    v_establishment_id := 400066001;
    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, city, state, country_code, latitude, longitude)
    VALUES (v_establishment_id, 'Greens Veg. Restaurant', lower(trim('Greens Veg. Restaurant')), 'Shop No. 8, Amita Apartment, 5 Kasthurba Rd', 'Borivali East', '400066', 'Mumbai', 'Maharashtra', 'IN', 19.230111280386154, 72.86202092988793);
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant
  WHERE establishment_id = v_establishment_id AND display_name = 'Greens Veg. Restaurant';

  IF NOT FOUND THEN
    v_restaurant_id := 400066001;
    INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, has_bar, bar_license_type, veg_nonveg_status)
    VALUES (v_restaurant_id, v_establishment_id, 'Greens Veg. Restaurant', lower(trim('Greens Veg. Restaurant')), FALSE, 'none', 'pure_veg');
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
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Greens_Veg_Restaurant_Menu.json')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant. Aborting.', 'Greens_Veg_Restaurant_Menu.json';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400066001001, 'ai_menu_extraction', 'Greens_Veg_Restaurant_Menu.json');
UPDATE khaustan_onboarding_ctx SET source_id = 400066001001;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400066001001, ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx SET extraction_batch_id = 400066001001;

-- No phone numbers were found anywhere in the source for this restaurant.

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name, batched
-- into one set-based statement (safe: normalized_name is the identity
-- key and the candidate list is de-duplicated before generation).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_dish_id, canonical_dish_name_id, canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    (400066001001, 400066001001, 'Idli', 'idli', 'veg', NULL),
    (400066001002, 400066001002, 'Idli Va', 'idli va', 'veg', NULL),
    (400066001003, 400066001003, 'Mendu Vada', 'mendu vada', 'veg', NULL),
    (400066001004, 400066001004, 'Idli Butter', 'idli butter', 'veg', NULL),
    (400066001005, 400066001005, 'Idli Dahi', 'idli dahi', 'veg', NULL),
    (400066001006, 400066001006, 'Idli Fry', 'idli fry', 'veg', NULL),
    (400066001007, 400066001007, 'Dahi Vada', 'dahi vada', 'veg', NULL),
    (400066001008, 400066001008, 'Sada Dosa', 'sada dosa', 'veg', NULL),
    (400066001009, 400066001009, 'Masala Dosa', 'masala dosa', 'veg', NULL),
    (400066001010, 400066001010, 'Paper Sada', 'paper sada', 'veg', NULL),
    (400066001011, 400066001011, 'Cheese Pa', 'cheese pa', 'veg', NULL),
    (400066001012, 400066001012, 'Mysore Sa', 'mysore sa', 'veg', NULL),
    (400066001013, 400066001013, 'Mysore Masa', 'mysore masa', 'veg', NULL),
    (400066001014, 400066001014, 'Uttappam', 'uttappam', 'veg', NULL),
    (400066001015, 400066001015, 'Onion Uttapp:', 'onion uttapp:', 'veg', NULL),
    (400066001016, 400066001016, 'Spri', 'spri', 'veg', NULL),
    (400066001017, 400066001017, 'Chinese Dosa', 'chinese dosa', 'veg', NULL),
    (400066001018, 400066001018, 'Puri Bhaji', 'puri bhaji', 'veg', NULL),
    (400066001019, 400066001019, 'Cheese Spring Dos:', 'cheese spring dos:', 'veg', NULL),
    (400066001020, 400066001020, 'Finger Chips', 'finger chips', 'veg', NULL),
    (400066001021, 400066001021, 'Kachori', 'kachori', 'veg', NULL),
    (400066001022, 400066001022, 'Potato Toast', 'potato toast', 'veg', NULL),
    (400066001023, 400066001023, 'Bread Butter', 'bread butter', 'veg', NULL),
    (400066001024, 400066001024, 'Chatni Sandwich', 'chatni sandwich', 'veg', NULL),
    (400066001025, 400066001025, 'Toast Butter', 'toast butter', 'veg', NULL),
    (400066001026, 400066001026, 'Jam Bread', 'jam bread', 'veg', NULL),
    (400066001027, 400066001027, 'Jam Toast', 'jam toast', 'veg', NULL),
    (400066001028, 400066001028, 'Veg. Sandwich', 'veg. sandwich', 'veg', NULL),
    (400066001029, 400066001029, 'Jam Sandwich', 'jam sandwich', 'veg', NULL),
    (400066001030, 400066001030, 'Toast Veg. Sandwich', 'toast veg. sandwich', 'veg', NULL),
    (400066001031, 400066001031, 'Toast Chatni Sandwich', 'toast chatni sandwich', 'veg', NULL),
    (400066001032, 400066001032, 'Cheese Sandwich', 'cheese sandwich', 'veg', NULL),
    (400066001033, 400066001033, 'Cheese Toast Sandwich', 'cheese toast sandwich', 'veg', NULL),
    (400066001034, 400066001034, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'veg', NULL),
    (400066001035, 400066001035, 'Cheese Veg. Toast Sandwich', 'cheese veg. toast sandwich', 'veg', NULL),
    (400066001036, 400066001036, 'Grilled Sandwich', 'grilled sandwich', 'veg', NULL),
    (400066001037, 400066001037, 'Club Sandwich', 'club sandwich', 'veg', NULL),
    (400066001038, 400066001038, 'Russian Sandwich', 'russian sandwich', 'veg', NULL),
    (400066001039, 400066001039, 'Only Cheese Grilled Sandwich', 'only cheese grilled sandwich', 'veg', NULL),
    (400066001040, 400066001040, 'Pineapple Pizza', 'pineapple pizza', 'veg', NULL),
    (400066001041, 400066001041, 'Veg. Pizza', 'veg. pizza', 'veg', NULL),
    (400066001042, 400066001042, 'Mushroom Pizza', 'mushroom pizza', 'veg', NULL),
    (400066001043, 400066001043, 'Baby Corn Pizza', 'baby corn pizza', 'veg', NULL),
    (400066001044, 400066001044, 'Cheese Pizza', 'cheese pizza', 'veg', NULL),
    (400066001045, 400066001045, 'Masala Pizza', 'masala pizza', 'veg', NULL),
    (400066001046, 400066001046, 'Green Spl. Pizza', 'green spl. pizza', 'veg', NULL),
    (400066001047, 400066001047, 'Mushroom Babycorn Pizza', 'mushroom babycorn pizza', 'veg', NULL),
    (400066001048, 400066001048, 'Cheese Paneer Pizza', 'cheese paneer pizza', 'veg', NULL),
    (400066001049, 400066001049, 'Nescafe', 'nescafe', 'veg', NULL),
    (400066001050, 400066001050, 'Pav Bhaji', 'pav bhaji', 'veg', NULL),
    (400066001051, 400066001051, 'Tomato Pav Bhaji', 'tomato pav bhaji', 'veg', NULL),
    (400066001052, 400066001052, 'Jain Pav Bhaji', 'jain pav bhaji', 'veg', NULL),
    (400066001053, 400066001053, 'Masala Pav ( 2 Pcs )', 'masala pav ( 2 pcs )', 'veg', NULL),
    (400066001054, 400066001054, 'Butter Pav', 'butter pav', 'veg', NULL),
    (400066001055, 400066001055, 'Tawa Pulav', 'tawa pulav', 'veg', NULL),
    (400066001056, 400066001056, 'Paneer Tawa Pulav', 'paneer tawa pulav', 'veg', NULL),
    (400066001057, 400066001057, 'Special Pav Bhaji', 'special pav bhaji', 'veg', NULL),
    (400066001058, 400066001058, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'veg', NULL),
    (400066001059, 400066001059, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', 'veg', NULL),
    (400066001060, 400066001060, 'Khada Bhaji', 'khada bhaji', 'veg', NULL),
    (400066001061, 400066001061, 'Jain Bhaji', 'jain bhaji', 'veg', NULL),
    (400066001062, 400066001062, 'Tomato Soup', 'tomato soup', 'veg', NULL),
    (400066001063, 400066001063, 'Green Palak Soup', 'green palak soup', 'veg', NULL),
    (400066001064, 400066001064, 'Vegetable Soup', 'vegetable soup', 'veg', NULL),
    (400066001065, 400066001065, 'Veg. Sweetcorn Soup', 'veg. sweetcorn soup', 'veg', NULL),
    (400066001066, 400066001066, 'Hot & Sour Soup', 'hot & sour soup', 'veg', NULL),
    (400066001067, 400066001067, 'Veg. Manchow Soup', 'veg. manchow soup', 'veg', NULL),
    (400066001068, 400066001068, 'Veg. Clear So', 'veg. clear so', 'veg', NULL),
    (400066001069, 400066001069, 'Veg. Noodle', 'veg. noodle', 'veg', NULL),
    (400066001070, 400066001070, 'Veg. Mushroo', 'veg. mushroo', 'veg', NULL),
    (400066001071, 400066001071, 'Royal Soup', 'royal soup', 'veg', NULL),
    (400066001072, 400066001072, 'Hong Kong', 'hong kong', 'veg', NULL),
    (400066001073, 400066001073, 'Tumyum S', 'tumyum s', 'veg', NULL),
    (400066001074, 400066001074, 'Mix Veg. Pal', 'mix veg. pal', 'veg', NULL),
    (400066001075, 400066001075, 'Cheese', 'cheese', 'veg', NULL),
    (400066001076, 400066001076, 'Veg', 'veg', 'veg', NULL),
    (400066001077, 400066001077, 'Veg. Hara Bara Kabab', 'veg. hara bara kabab', 'veg', NULL),
    (400066001078, 400066001078, 'Veg. Lollypop', 'veg. lollypop', 'veg', NULL),
    (400066001079, 400066001079, 'Flower Lollypop', 'flower lollypop', 'veg', NULL),
    (400066001080, 400066001080, 'Veg. Gold Coi', 'veg. gold coi', 'veg', NULL),
    (400066001081, 400066001081, 'Veg. Crispy', 'veg. crispy', 'veg', NULL),
    (400066001082, 400066001082, 'Paneer Chilly', 'paneer chilly', 'veg', NULL),
    (400066001083, 400066001083, 'Mushroom Chilly', 'mushroom chilly', 'veg', NULL),
    (400066001084, 400066001084, 'Mushroom Manchurian', 'mushroom manchurian', 'veg', NULL),
    (400066001085, 400066001085, 'Paneer 65', 'paneer 65', 'veg', NULL),
    (400066001086, 400066001086, 'Paneer Schezwan', 'paneer schezwan', 'veg', NULL),
    (400066001087, 400066001087, 'Baby Corn Manchurian', 'baby corn manchurian', 'veg', NULL),
    (400066001088, 400066001088, 'Paneer Manchurian', 'paneer manchurian', 'veg', NULL),
    (400066001089, 400066001089, 'Kaju Makhanwala', 'kaju makhanwala', 'veg', NULL),
    (400066001090, 400066001090, 'Green''s Spl. Veg.', 'green''s spl. veg.', 'veg', NULL),
    (400066001091, 400066001091, 'Koya Kaju', 'koya kaju', 'veg', NULL),
    (400066001092, 400066001092, 'Veg. Masthi ( Your Choice )', 'veg. masthi ( your choice )', 'veg', NULL),
    (400066001093, 400066001093, 'Hara Bara Kabab Masala', 'hara bara kabab masala', 'veg', NULL),
    (400066001094, 400066001094, 'Veg. Seekh Kabab Masala', 'veg. seekh kabab masala', 'veg', NULL),
    (400066001095, 400066001095, 'Veg. Patiyala', 'veg. patiyala', 'veg', NULL),
    (400066001096, 400066001096, 'Veg. Cheese Butter Masala', 'veg. cheese butter masala', 'veg', NULL),
    (400066001097, 400066001097, 'Veg. Chilly Milly Masala', 'veg. chilly milly masala', 'veg', NULL),
    (400066001098, 400066001098, 'Veg. Hariyali', 'veg. hariyali', 'veg', NULL),
    (400066001099, 400066001099, 'Veg. Maharaja', 'veg. maharaja', 'veg', NULL),
    (400066001100, 400066001100, 'Veg. Jaipuri', 'veg. jaipuri', 'veg', NULL),
    (400066001101, 400066001101, 'Veg. Rajsthani', 'veg. rajsthani', 'veg', NULL),
    (400066001102, 400066001102, 'Veg. Jalfrezi', 'veg. jalfrezi', 'veg', NULL),
    (400066001103, 400066001103, 'Veg. Tawa', 'veg. tawa', 'veg', NULL),
    (400066001104, 400066001104, 'Veg. Kneema', 'veg. kneema', 'veg', NULL),
    (400066001105, 400066001105, 'Veg. Hyderabadi', 'veg. hyderabadi', 'veg', NULL),
    (400066001106, 400066001106, 'Malai Kofta', 'malai kofta', 'veg', NULL),
    (400066001107, 400066001107, 'Veg. Nawabi', 'veg. nawabi', 'veg', NULL),
    (400066001108, 400066001108, 'Kaju Curry', 'kaju curry', 'veg', NULL),
    (400066001109, 400066001109, 'Kaju Handi', 'kaju handi', 'veg', NULL),
    (400066001110, 400066001110, 'Deevani Handi', 'deevani handi', 'veg', NULL),
    (400066001111, 400066001111, 'Kaju Kadai', 'kaju kadai', 'veg', NULL),
    (400066001112, 400066001112, 'Kaju Masala', 'kaju masala', 'veg', NULL),
    (400066001113, 400066001113, 'Paneer Kaju Masala', 'paneer kaju masala', 'veg', NULL),
    (400066001114, 400066001114, 'Veg. Mumtaj', 'veg. mumtaj', 'veg', NULL),
    (400066001115, 400066001115, 'Veg. Peshwari', 'veg. peshwari', 'veg', NULL),
    (400066001116, 400066001116, 'Veg. Dilkhush', 'veg. dilkhush', 'veg', NULL),
    (400066001117, 400066001117, 'Veg. Koliwada', 'veg. koliwada', 'veg', NULL),
    (400066001118, 400066001118, 'Mix Vegetable', 'mix vegetable', 'veg', NULL),
    (400066001119, 400066001119, 'Navaratan Kurma', 'navaratan kurma', 'veg', NULL),
    (400066001120, 400066001120, 'Methi Malai Mutter', 'methi malai mutter', 'veg', NULL),
    (400066001121, 400066001121, 'Nargis Kofta', 'nargis kofta', 'veg', NULL),
    (400066001122, 400066001122, 'Kashmiri Kofta', 'kashmiri kofta', 'veg', NULL),
    (400066001123, 400066001123, 'Cheese Kofta', 'cheese kofta', 'veg', NULL),
    (400066001124, 400066001124, 'Cheese Butter Masala', 'cheese butter masala', 'veg', NULL),
    (400066001125, 400066001125, 'Paneer Lasuni', 'paneer lasuni', 'veg', NULL),
    (400066001126, 400066001126, 'Paneer Methi', 'paneer methi', 'veg', NULL),
    (400066001127, 400066001127, 'Paneer Hydrabadi', 'paneer hydrabadi', 'veg', NULL),
    (400066001128, 400066001128, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL),
    (400066001129, 400066001129, 'Paneer Lajwab', 'paneer lajwab', 'veg', NULL),
    (400066001130, 400066001130, 'Paneer Kofta', 'paneer kofta', 'veg', NULL),
    (400066001131, 400066001131, 'Paneer Kadai', 'paneer kadai', 'veg', NULL),
    (400066001132, 400066001132, 'Paneer Butter Masala', 'paneer butter masala', 'veg', NULL),
    (400066001133, 400066001133, 'Paneer Pasanda', 'paneer pasanda', 'veg', NULL),
    (400066001134, 400066001134, 'Paneer Handi', 'paneer handi', 'veg', NULL),
    (400066001135, 400066001135, 'Paneer Bhurji', 'paneer bhurji', 'veg', NULL),
    (400066001136, 400066001136, 'Paneer Makha''', 'paneer makha''', 'veg', NULL),
    (400066001137, 400066001137, 'Paneer Kurm;', 'paneer kurm;', 'veg', NULL),
    (400066001138, 400066001138, 'Paneer Mu', 'paneer mu', 'veg', NULL),
    (400066001139, 400066001139, 'Paneer Pal', 'paneer pal', 'veg', NULL),
    (400066001140, 400066001140, 'Paneer Kol', 'paneer kol', 'veg', NULL),
    (400066001141, 400066001141, 'Paneer Tawa', 'paneer tawa', 'veg', NULL),
    (400066001142, 400066001142, 'Paneer Masal', 'paneer masal', 'veg', NULL),
    (400066001143, 400066001143, 'Paneer Koli', 'paneer koli', 'veg', NULL),
    (400066001144, 400066001144, 'Paneer Punjab', 'paneer punjab', 'veg', NULL),
    (400066001145, 400066001145, 'om Hand', 'om hand', 'veg', NULL),
    (400066001146, 400066001146, 'Green Peas Masala', 'green peas masala', 'veg', NULL),
    (400066001147, 400066001147, 'Stuffed Tomato', 'stuffed tomato', 'veg', NULL),
    (400066001148, 400066001148, 'Alu Gobi', 'alu gobi', 'veg', NULL),
    (400066001149, 400066001149, 'Alu Methi', 'alu methi', 'veg', NULL),
    (400066001150, 400066001150, 'Alu Palak', 'alu palak', 'veg', NULL),
    (400066001151, 400066001151, 'Palak', 'palak', 'veg', NULL),
    (400066001152, 400066001152, 'Alu Mutter', 'alu mutter', 'veg', NULL),
    (400066001153, 400066001153, 'Alu Jeera', 'alu jeera', 'veg', NULL),
    (400066001154, 400066001154, 'Gobi Masala', 'gobi masala', 'veg', NULL),
    (400066001155, 400066001155, 'Palak Mutter', 'palak mutter', 'veg', NULL),
    (400066001156, 400066001156, 'Alu Capsicum', 'alu capsicum', 'veg', NULL),
    (400066001157, 400066001157, 'Methi Mutter Masala', 'methi mutter masala', 'veg', NULL),
    (400066001158, 400066001158, 'Channa Masala', 'channa masala', 'veg', NULL),
    (400066001159, 400066001159, 'Dahi Pakoda Curry', 'dahi pakoda curry', 'veg', NULL),
    (400066001160, 400066001160, 'Dal Tadka', 'dal tadka', 'veg', NULL),
    (400066001161, 400066001161, 'Dal Fry', 'dal fry', 'veg', NULL),
    (400066001162, 400066001162, 'Dal Fry Butter', 'dal fry butter', 'veg', NULL),
    (400066001163, 400066001163, 'Methi Dal Fry', 'methi dal fry', 'veg', NULL),
    (400066001164, 400066001164, 'Palak Dal Fry', 'palak dal fry', 'veg', NULL),
    (400066001165, 400066001165, 'Kolhapuri Dal Fry', 'kolhapuri dal fry', 'veg', NULL),
    (400066001166, 400066001166, 'Dal Makhani', 'dal makhani', 'veg', NULL),
    (400066001167, 400066001167, 'Punjabi Dal Fry', 'punjabi dal fry', 'veg', NULL),
    (400066001168, 400066001168, 'Dal (Plain)', 'dal (plain)', 'veg', NULL),
    (400066001169, 400066001169, 'Chole Bathora', 'chole bathora', 'veg', NULL),
    (400066001170, 400066001170, 'Sambar Plate', 'sambar plate', 'veg', NULL),
    (400066001171, 400066001171, 'Butter Roti he', 'butter roti he', 'veg', NULL),
    (400066001172, 400066001172, 'Chapati', 'chapati', 'veg', NULL),
    (400066001173, 400066001173, 'Butter Chapati', 'butter chapati', 'veg', NULL),
    (400066001174, 400066001174, 'Parotha', 'parotha', 'veg', NULL),
    (400066001175, 400066001175, 'Butter Parotha', 'butter parotha', 'veg', NULL),
    (400066001176, 400066001176, 'Nan', 'nan', 'veg', NULL),
    (400066001177, 400066001177, 'Kulcha', 'kulcha', 'veg', NULL),
    (400066001178, 400066001178, 'Butter Nan', 'butter nan', 'veg', NULL),
    (400066001179, 400066001179, 'Butter Kulcha', 'butter kulcha', 'veg', NULL),
    (400066001180, 400066001180, 'Cheese Garlic Nan', 'cheese garlic nan', 'veg', NULL),
    (400066001181, 400066001181, 'Kashmiri Nan', 'kashmiri nan', 'veg', NULL),
    (400066001182, 400066001182, 'Cheese Kulcha', 'cheese kulcha', 'veg', NULL),
    (400066001183, 400066001183, 'Cheese Garlic Kulcha', 'cheese garlic kulcha', 'veg', NULL),
    (400066001184, 400066001184, 'Methi Roti', 'methi roti', 'veg', NULL),
    (400066001185, 400066001185, 'Makai Roti', 'makai roti', 'veg', NULL),
    (400066001186, 400066001186, 'Missi Roti', 'missi roti', 'veg', NULL),
    (400066001187, 400066001187, 'Masala Kulcha', 'masala kulcha', 'veg', NULL),
    (400066001188, 400066001188, 'Alu Parotha', 'alu parotha', 'veg', NULL),
    (400066001189, 400066001189, 'Methi Parotha', 'methi parotha', 'veg', NULL),
    (400066001190, 400066001190, 'Pudina Parotha', 'pudina parotha', 'veg', NULL),
    (400066001191, 400066001191, 'Cheese Nan', 'cheese nan', 'veg', NULL),
    (400066001192, 400066001192, 'Garlic Nan', 'garlic nan', 'veg', NULL),
    (400066001193, 400066001193, 'Basket Roti', 'basket roti', 'veg', NULL),
    (400066001194, 400066001194, 'Bathura (S)', 'bathura (s)', 'veg', NULL),
    (400066001195, 400066001195, 'Steam Rice (I', 'steam rice (i', 'veg', NULL),
    (400066001196, 400066001196, 'Steam Rice', 'steam rice', 'veg', NULL),
    (400066001197, 400066001197, 'Jeera Rice', 'jeera rice', 'veg', NULL),
    (400066001198, 400066001198, 'Veg. Pulav', 'veg. pulav', 'veg', NULL),
    (400066001199, 400066001199, 'Green Peas P''', 'green peas p''', 'veg', NULL),
    (400066001200, 400066001200, 'Kashmiri', 'kashmiri', 'veg', NULL),
    (400066001201, 400066001201, 'Tawa Pula’', 'tawa pula’', 'veg', NULL),
    (400066001202, 400066001202, 'Mushroom Bi', 'mushroom bi', 'veg', NULL),
    (400066001203, 400066001203, 'se P', 'se p', 'veg', NULL),
    (400066001204, 400066001204, 'Palak Rice', 'palak rice', 'veg', NULL),
    (400066001205, 400066001205, 'Curd Rice ( Tadka', 'curd rice ( tadka', 'veg', NULL),
    (400066001206, 400066001206, 'Green Spl. Briyani', 'green spl. briyani', 'veg', NULL),
    (400066001207, 400066001207, 'Dum Biriyani', 'dum biriyani', 'veg', NULL),
    (400066001208, 400066001208, 'Manchurian With Garlic Sauce', 'manchurian with garlic sauce', 'veg', NULL),
    (400066001209, 400066001209, 'Manchurian Veg', 'manchurian veg', 'veg', NULL),
    (400066001210, 400066001210, 'Flower Manchurian', 'flower manchurian', 'veg', NULL),
    (400066001211, 400066001211, 'Veg. Hong Kong', 'veg. hong kong', 'veg', NULL),
    (400066001212, 400066001212, 'Veg. Chopsuey', 'veg. chopsuey', 'veg', NULL),
    (400066001213, 400066001213, 'American Chopsuey', 'american chopsuey', 'veg', NULL),
    (400066001214, 400066001214, 'Veg. Chowmein', 'veg. chowmein', 'veg', NULL),
    (400066001215, 400066001215, 'Veg. Schezwan', 'veg. schezwan', 'veg', NULL),
    (400066001216, 400066001216, 'Paneer Chilli', 'paneer chilli', 'veg', NULL),
    (400066001217, 400066001217, 'Veg. 65', 'veg. 65', 'veg', NULL),
    (400066001218, 400066001218, 'Veg. Combination Fried Rice', 'veg. combination fried rice', 'veg', NULL),
    (400066001219, 400066001219, 'Veg. Ginger Garlic Fried Rice', 'veg. ginger garlic fried rice', 'veg', NULL),
    (400066001220, 400066001220, 'Veg. Tripple Schezwan Fried Rice', 'veg. tripple schezwan fried rice', 'veg', NULL),
    (400066001221, 400066001221, 'Veg. Mushroom Fried Rice', 'veg. mushroom fried rice', 'veg', NULL),
    (400066001222, 400066001222, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'veg', NULL),
    (400066001223, 400066001223, 'Veg. Hong Kong Noodles', 'veg. hong kong noodles', 'veg', NULL),
    (400066001224, 400066001224, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'veg', NULL),
    (400066001225, 400066001225, 'Veg. Mushroom Noodles', 'veg. mushroom noodles', 'veg', NULL),
    (400066001226, 400066001226, 'Veg. Tripple Schezwan Noodles', 'veg. tripple schezwan noodles', 'veg', NULL),
    (400066001227, 400066001227, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'veg', NULL),
    (400066001228, 400066001228, 'Veg. Fried Rice With Manchurian', 'veg. fried rice with manchurian', 'veg', NULL),
    (400066001229, 400066001229, 'Green Salad', 'green salad', 'veg', NULL),
    (400066001230, 400066001230, 'Veg. Raitha', 'veg. raitha', 'veg', NULL),
    (400066001231, 400066001231, 'Bundi Raitha', 'bundi raitha', 'veg', NULL),
    (400066001232, 400066001232, 'Pineapple Raitha', 'pineapple raitha', 'veg', NULL),
    (400066001233, 400066001233, 'Curd', 'curd', 'veg', NULL),
    (400066001234, 400066001234, 'Masala Papad', 'masala papad', 'veg', NULL),
    (400066001235, 400066001235, 'Roasted Papad', 'roasted papad', 'veg', NULL),
    (400066001236, 400066001236, 'Soft Drinks', 'soft drinks', 'veg', NULL),
    (400066001237, 400066001237, 'Soda', 'soda', 'veg', NULL),
    (400066001238, 400066001238, 'Fresh Lime Soda', 'fresh lime soda', 'veg', NULL),
    (400066001239, 400066001239, 'Fresh Lime Water', 'fresh lime water', 'veg', NULL),
    (400066001240, 400066001240, 'Mineral Water (1000 Ml)', 'mineral water (1000 ml)', 'veg', NULL),
    (400066001241, 400066001241, 'Cold Drinks (200 Ml)', 'cold drinks (200 ml)', 'veg', NULL),
    (400066001242, 400066001242, 'Cold Drinks (50', 'cold drinks (50', 'veg', NULL),
    (400066001243, 400066001243, 'Bisleri (500', 'bisleri (500', 'veg', NULL),
    (400066001244, 400066001244, 'Red Bull', 'red bull', 'veg', NULL),
    (400066001245, 400066001245, 'Kesar Lassi', 'kesar lassi', 'veg', NULL),
    (400066001246, 400066001246, 'Mango Lassi', 'mango lassi', 'veg', NULL),
    (400066001247, 400066001247, 'Sweet Lassi', 'sweet lassi', 'veg', NULL),
    (400066001248, 400066001248, 'Salted Lassi', 'salted lassi', 'veg', NULL),
    (400066001249, 400066001249, 'Chikku Milk Shake', 'chikku milk shake', 'veg', NULL),
    (400066001250, 400066001250, 'Banana Milk Shake', 'banana milk shake', 'veg', NULL),
    (400066001251, 400066001251, 'Apple Milk Shai', 'apple milk shai', 'veg', NULL),
    (400066001252, 400066001252, 'Chocolate Milk Shal', 'chocolate milk shal', 'veg', NULL),
    (400066001253, 400066001253, 'Rose Milk Shake', 'rose milk shake', 'veg', NULL),
    (400066001254, 400066001254, 'Kesar Milk Shake', 'kesar milk shake', 'veg', NULL),
    (400066001255, 400066001255, 'Mango Milk Shake', 'mango milk shake', 'veg', NULL),
    (400066001256, 400066001256, 'Vanilla Milk Shake', 'vanilla milk shake', 'veg', NULL),
    (400066001257, 400066001257, 'Seetaphal Milk Shake (Seasonal)', 'seetaphal milk shake (seasonal)', 'veg', NULL),
    (400066001258, 400066001258, 'Cold Coffee', 'cold coffee', 'veg', NULL),
    (400066001259, 400066001259, 'Fruit Salad', 'fruit salad', 'veg', NULL),
    (400066001260, 400066001260, 'Jelly Plain', 'jelly plain', 'veg', NULL),
    (400066001261, 400066001261, 'Green Special Falooda', 'green special falooda', 'veg', NULL),
    (400066001262, 400066001262, 'Kulfi Falooda', 'kulfi falooda', 'veg', NULL),
    (400066001263, 400066001263, 'Kesar Falooda', 'kesar falooda', 'veg', NULL),
    (400066001264, 400066001264, 'Royal Falooda', 'royal falooda', 'veg', NULL),
    (400066001265, 400066001265, 'Vanilla (Small)', 'vanilla (small)', 'veg', NULL),
    (400066001266, 400066001266, 'Vanilla (Big)', 'vanilla (big)', 'veg', NULL),
    (400066001267, 400066001267, 'Strawberry', 'strawberry', 'veg', NULL),
    (400066001268, 400066001268, 'Butter Scotch', 'butter scotch', 'veg', NULL),
    (400066001269, 400066001269, 'Classic Casata', 'classic casata', 'veg', NULL),
    (400066001270, 400066001270, 'Kesar Pista', 'kesar pista', 'veg', NULL),
    (400066001271, 400066001271, 'Chocolate Feast', 'chocolate feast', 'veg', NULL),
    (400066001272, 400066001272, 'Chocolate Cone', 'chocolate cone', 'veg', NULL),
    (400066001273, 400066001273, 'Butter Scotch Cone', 'butter scotch cone', 'veg', NULL),
    (400066001274, 400066001274, 'Choco Bar', 'choco bar', 'veg', NULL),
    (400066001275, 400066001275, 'Mango Duet', 'mango duet', 'veg', NULL),
    (400066001276, 400066001276, 'Raspberry Duet', 'raspberry duet', 'veg', NULL),
    (400066001277, 400066001277, 'Omlet Sandwich', 'omlet sandwich', 'egg', 'EGG'),
    (400066001278, 400066001278, 'Toast Omlet Sandwich', 'toast omlet sandwich', 'egg', 'EGG'),
    (400066001279, 400066001279, 'Paper Masala', 'paper masala', 'veg', NULL),
    (400066001280, 400066001280, 'Sabudana Wada', 'sabudana wada', 'veg', NULL),
    (400066001281, 400066001281, 'Veg. Cheese Grilled Sandwich', 'veg. cheese grilled sandwich', 'veg', NULL),
    (400066001282, 400066001282, 'Cheese Chilli Toast', 'cheese chilli toast', 'veg', NULL),
    (400066001283, 400066001283, 'Tea', 'tea', 'veg', NULL),
    (400066001284, 400066001284, 'Tea (Without Sugar)', 'tea (without sugar)', 'veg', NULL),
    (400066001285, 400066001285, 'Khada Pav Bhaji', 'khada pav bhaji', 'veg', NULL),
    (400066001286, 400066001286, 'Only Bhaji', 'only bhaji', 'veg', NULL),
    (400066001287, 400066001287, 'Cheese Tawa Pulav', 'cheese tawa pulav', 'veg', NULL),
    (400066001288, 400066001288, 'Mushroom Tawa Pulav', 'mushroom tawa pulav', 'veg', NULL),
    (400066001289, 400066001289, 'Tawa Idli', 'tawa idli', 'veg', NULL),
    (400066001290, 400066001290, 'Paneer Crispy', 'paneer crispy', 'veg', NULL),
    (400066001291, 400066001291, 'Veg. Kadai', 'veg. kadai', 'veg', NULL),
    (400066001292, 400066001292, 'Veg. Handi', 'veg. handi', 'veg', NULL),
    (400066001293, 400066001293, 'Veg. Kofta', 'veg. kofta', 'veg', NULL),
    (400066001294, 400066001294, 'Veg. Kolhapuri', 'veg. kolhapuri', 'veg', NULL),
    (400066001295, 400066001295, 'Veg. Makhanwala', 'veg. makhanwala', 'veg', NULL),
    (400066001296, 400066001296, 'Veg. Kashmiri', 'veg. kashmiri', 'veg', NULL),
    (400066001297, 400066001297, 'Veg. Moglai', 'veg. moglai', 'veg', NULL),
    (400066001298, 400066001298, 'Veg. Kurma', 'veg. kurma', 'veg', NULL),
    (400066001299, 400066001299, 'Veg. Afghani', 'veg. afghani', 'veg', NULL),
    (400066001300, 400066001300, 'Tomato Bartha', 'tomato bartha', 'veg', NULL),
    (400066001301, 400066001301, 'Palak Methi', 'palak methi', 'veg', NULL),
    (400066001302, 400066001302, 'Palak Lasooni', 'palak lasooni', 'veg', NULL),
    (400066001303, 400066001303, 'Alu Sukka Bhaji', 'alu sukka bhaji', 'veg', NULL),
    (400066001304, 400066001304, 'Cheese Patiyala', 'cheese patiyala', 'veg', NULL),
    (400066001305, 400066001305, 'Paneer Amrutisari', 'paneer amrutisari', 'veg', NULL),
    (400066001306, 400066001306, 'Paneer Angara', 'paneer angara', 'veg', NULL),
    (400066001307, 400066001307, 'Sev Tomato Masala', 'sev tomato masala', 'veg', NULL),
    (400066001308, 400066001308, 'Veg Khajana', 'veg khajana', 'veg', NULL),
    (400066001309, 400066001309, 'Dal Fry (Gujarati)', 'dal fry (gujarati)', 'veg', NULL),
    (400066001310, 400066001310, 'Roti (Tandoori)', 'roti (tandoori)', 'veg', NULL),
    (400066001311, 400066001311, 'Stuff Parotha', 'stuff parotha', 'veg', NULL),
    (400066001312, 400066001312, 'Paneer Stuff Parotha', 'paneer stuff parotha', 'veg', NULL),
    (400066001313, 400066001313, 'Puri', 'puri', 'veg', NULL),
    (400066001314, 400066001314, 'Butter Basket Roti', 'butter basket roti', 'veg', NULL),
    (400066001315, 400066001315, 'Maida Roti', 'maida roti', 'veg', NULL),
    (400066001316, 400066001316, 'Butter Maida Roti', 'butter maida roti', 'veg', NULL),
    (400066001317, 400066001317, 'Veg. Masala Pulav', 'veg. masala pulav', 'veg', NULL),
    (400066001318, 400066001318, 'Veg. Chow Chow', 'veg. chow chow', 'veg', NULL),
    (400066001319, 400066001319, 'Veg. Chilli', 'veg. chilli', 'veg', NULL),
    (400066001320, 400066001320, 'Veg. Fried Rice', 'veg. fried rice', 'veg', NULL),
    (400066001321, 400066001321, 'Paneer Fried Rice', 'paneer fried rice', 'veg', NULL),
    (400066001322, 400066001322, 'Fried Papad', 'fried papad', 'veg', NULL),
    (400066001323, 400066001323, 'Khichiya Masala Papad', 'khichiya masala papad', 'veg', NULL),
    (400066001324, 400066001324, 'Khichiya Roasted Papad', 'khichiya roasted papad', 'veg', NULL),
    (400066001325, 400066001325, 'Cocktail Milk Shake', 'cocktail milk shake', 'veg', NULL),
    (400066001326, 400066001326, 'Dry Fruit Milk Shake', 'dry fruit milk shake', 'veg', NULL),
    (400066001327, 400066001327, 'Fruit Salad Jelly', 'fruit salad jelly', 'veg', NULL),
    (400066001328, 400066001328, 'Gadbad Special', 'gadbad special', 'veg', NULL),
    (400066001329, 400066001329, 'Fruit Punch', 'fruit punch', 'veg', NULL),
    (400066001330, 400066001330, 'Yadeen', 'yadeen', 'veg', NULL),
    (400066001331, 400066001331, 'Green Cooler', 'green cooler', 'veg', NULL),
    (400066001332, 400066001332, 'Exotica', 'exotica', 'veg', NULL),
    (400066001333, 400066001333, 'Malai Kulfi', 'malai kulfi', 'veg', NULL),
    (400066001334, 400066001334, 'Kesar Kulfi', 'kesar kulfi', 'veg', NULL)
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
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400066001001, 'South Indian Dishes', 1), (400066001002, 'Ice Cream', 2), (400066001003, 'Soups', 3), (400066001004, 'Punjabi Dishes', 4), (400066001005, 'Roti / Naan / Parotha', 5), (400066001006, 'Rice, Biryani, Pulav', 6), (400066001007, 'Chinese Dishes -- Vegetable', 7), (400066001008, 'Chinese Rice & Noodles', 8), (400066001009, 'Salad / Raitha', 9), (400066001010, 'Cold Drinks', 10), (400066001011, 'Lassi', 11), (400066001012, 'Milk Shakes', 12), (400066001013, 'Fruit Special', 13), (400066001014, 'Falooda', 14), (400066001015, 'Mocktails', 15)) AS x(menu_category_id, name, display_sequence);

-- =============================================================================
-- Menu items (339 priced)
-- =============================================================================

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001001, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Idli', 'idli', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001001, new_variant.variant_id, 78.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001002, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Idli Va', 'idli va', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli va'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001002, new_variant.variant_id, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001003, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Mendu Vada', 'mendu vada', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mendu vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001003, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001004, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Idli Butter', 'idli butter', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001004, new_variant.variant_id, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001005, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Idli Dahi', 'idli dahi', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli dahi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001005, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001006, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Idli Fry', 'idli fry', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001006, new_variant.variant_id, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001007, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Dahi Vada', 'dahi vada', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001007, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001008, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Sada Dosa', 'sada dosa', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001008, new_variant.variant_id, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001009, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Masala Dosa', 'masala dosa', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001009, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001010, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Paper Sada', 'paper sada', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paper sada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001010, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001011, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Pa', 'cheese pa', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001011, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001012, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Mysore Sa', 'mysore sa', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore sa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001012, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001013, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Mysore Masa', 'mysore masa', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore masa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001013, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001014, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Uttappam', 'uttappam', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001014, new_variant.variant_id, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001015, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Onion Uttapp:', 'onion uttapp:', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'onion uttapp:'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001015, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001016, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Spri', 'spri', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'spri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001016, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001017, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Chinese Dosa', 'chinese dosa', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001017, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001018, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Puri Bhaji', 'puri bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'puri bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001018, new_variant.variant_id, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001019, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Spring Dos:', 'cheese spring dos:', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese spring dos:'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001019, new_variant.variant_id, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001020, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Finger Chips', 'finger chips', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'finger chips'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001020, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001021, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Kachori', 'kachori', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kachori'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001021, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001022, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Potato Toast', 'potato toast', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato toast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001022, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001023, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Bread Butter', 'bread butter', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bread butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001023, new_variant.variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001024, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Chatni Sandwich', 'chatni sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chatni sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001024, new_variant.variant_id, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001025, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Toast Butter', 'toast butter', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'toast butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001025, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001026, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Jam Bread', 'jam bread', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jam bread'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001026, new_variant.variant_id, 72.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001027, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Jam Toast', 'jam toast', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jam toast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001027, new_variant.variant_id, 82.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001028, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Veg. Sandwich', 'veg. sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001028, new_variant.variant_id, 78.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001029, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Jam Sandwich', 'jam sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jam sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001029, new_variant.variant_id, 89.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001030, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Toast Veg. Sandwich', 'toast veg. sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'toast veg. sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001030, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001031, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Toast Chatni Sandwich', 'toast chatni sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'toast chatni sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001031, new_variant.variant_id, 78.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001032, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Sandwich', 'cheese sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001032, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001033, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Toast Sandwich', 'cheese toast sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001033, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001034, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001034, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001035, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Veg. Toast Sandwich', 'cheese veg. toast sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese veg. toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001035, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001036, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Grilled Sandwich', 'grilled sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'grilled sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001036, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001037, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Club Sandwich', 'club sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'club sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001037, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001038, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Russian Sandwich', 'russian sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'russian sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001038, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001039, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Only Cheese Grilled Sandwich', 'only cheese grilled sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'only cheese grilled sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001039, new_variant.variant_id, 177.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001040, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Pineapple Pizza', 'pineapple pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001040, new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001041, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Veg. Pizza', 'veg. pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001041, new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001042, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Mushroom Pizza', 'mushroom pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001042, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001043, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Baby Corn Pizza', 'baby corn pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001043, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001044, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Pizza', 'cheese pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001044, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001045, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Masala Pizza', 'masala pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001045, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001046, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Green Spl. Pizza', 'green spl. pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green spl. pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001046, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001047, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Mushroom Babycorn Pizza', 'mushroom babycorn pizza', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom babycorn pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001047, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001048, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Cheese Paneer Pizza', 'cheese paneer pizza', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese paneer pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001048, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001049, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Nescafe', 'nescafe', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nescafe'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001049, new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001050, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Pav Bhaji', 'pav bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001050, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001051, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Tomato Pav Bhaji', 'tomato pav bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001051, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001052, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Jain Pav Bhaji', 'jain pav bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001052, new_variant.variant_id, 164.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001053, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Masala Pav ( 2 Pcs )', 'masala pav ( 2 pcs )', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala pav ( 2 pcs )'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001053, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001054, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Butter Pav', 'butter pav', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001054, new_variant.variant_id, 14.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001055, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Tawa Pulav', 'tawa pulav', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001055, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001056, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Paneer Tawa Pulav', 'paneer tawa pulav', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001056, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001057, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Special Pav Bhaji', 'special pav bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'special pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001057, new_variant.variant_id, 206.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001058, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001058, new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001059, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001059, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001060, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Khada Bhaji', 'khada bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khada bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001060, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001061, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Jain Bhaji', 'jain bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001061, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001062, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Tomato Soup', 'tomato soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001062, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001063, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Green Palak Soup', 'green palak soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green palak soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001063, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001064, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Vegetable Soup', 'vegetable soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'vegetable soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001064, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001065, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Sweetcorn Soup', 'veg. sweetcorn soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. sweetcorn soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001065, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001066, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Hot & Sour Soup', 'hot & sour soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot & sour soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001066, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001067, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Manchow Soup', 'veg. manchow soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchow soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001067, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001068, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Clear So', 'veg. clear so', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. clear so'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001068, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001069, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Noodle', 'veg. noodle', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. noodle'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001069, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001070, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Mushroo', 'veg. mushroo', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. mushroo'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001070, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001071, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Royal Soup', 'royal soup', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'royal soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001071, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001072, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Hong Kong', 'hong kong', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hong kong'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001072, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001073, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Tumyum S', 'tumyum s', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tumyum s'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001073, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001074, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Mix Veg. Pal', 'mix veg. pal', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix veg. pal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001074, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001075, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Cheese', 'cheese', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001075, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001076, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg', 'veg', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001076, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001077, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Hara Bara Kabab', 'veg. hara bara kabab', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hara bara kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001077, new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001078, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Lollypop', 'veg. lollypop', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. lollypop'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001078, new_variant.variant_id, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001079, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Flower Lollypop', 'flower lollypop', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'flower lollypop'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001079, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001080, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Gold Coi', 'veg. gold coi', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. gold coi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001080, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001081, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Veg. Crispy', 'veg. crispy', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001081, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001082, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Paneer Chilly', 'paneer chilly', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001082, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001083, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Mushroom Chilly', 'mushroom chilly', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001083, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001084, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Mushroom Manchurian', 'mushroom manchurian', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001084, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001085, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Paneer 65', 'paneer 65', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001085, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001086, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Paneer Schezwan', 'paneer schezwan', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001086, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001087, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Baby Corn Manchurian', 'baby corn manchurian', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001087, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Soups" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001088, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001003, 'Paneer Manchurian', 'paneer manchurian', 'Soups', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001088, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001089, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kaju Makhanwala', 'kaju makhanwala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju makhanwala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001089, new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001090, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Green''s Spl. Veg.', 'green''s spl. veg.', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green''s spl. veg.'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001090, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001091, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Koya Kaju', 'koya kaju', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'koya kaju'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001091, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001092, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Masthi ( Your Choice )', 'veg. masthi ( your choice )', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. masthi ( your choice )'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001092, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001093, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Hara Bara Kabab Masala', 'hara bara kabab masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hara bara kabab masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001093, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001094, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Seekh Kabab Masala', 'veg. seekh kabab masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. seekh kabab masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001094, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001095, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Patiyala', 'veg. patiyala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. patiyala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001095, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001096, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Cheese Butter Masala', 'veg. cheese butter masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese butter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001096, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001097, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Chilly Milly Masala', 'veg. chilly milly masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilly milly masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001097, new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001098, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Hariyali', 'veg. hariyali', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hariyali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001098, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001099, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Maharaja', 'veg. maharaja', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. maharaja'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001099, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001100, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Jaipuri', 'veg. jaipuri', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. jaipuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001100, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001101, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Veg. Rajsthani', 'veg. rajsthani', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. rajsthani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001101, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001102, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Jalfrezi', 'veg. jalfrezi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. jalfrezi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001102, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001103, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Tawa', 'veg. tawa', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. tawa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001103, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001104, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Kneema', 'veg. kneema', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kneema'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001104, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001105, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Hyderabadi', 'veg. hyderabadi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hyderabadi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001105, new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001106, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Malai Kofta', 'malai kofta', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001106, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001107, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Nawabi', 'veg. nawabi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. nawabi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001107, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001108, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kaju Curry', 'kaju curry', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001108, new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001109, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kaju Handi', 'kaju handi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001109, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001110, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Deevani Handi', 'deevani handi', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'deevani handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001110, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001111, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kaju Kadai', 'kaju kadai', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju kadai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001111, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001112, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kaju Masala', 'kaju masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001112, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001113, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Paneer Kaju Masala', 'paneer kaju masala', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kaju masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001113, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001114, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Mumtaj', 'veg. mumtaj', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. mumtaj'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001114, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001115, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Peshwari', 'veg. peshwari', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. peshwari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001115, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001116, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Dilkhush', 'veg. dilkhush', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. dilkhush'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001116, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001117, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Koliwada', 'veg. koliwada', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. koliwada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001117, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001118, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Mix Vegetable', 'mix vegetable', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix vegetable'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001118, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001119, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Navaratan Kurma', 'navaratan kurma', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'navaratan kurma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001119, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001120, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Methi Malai Mutter', 'methi malai mutter', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi malai mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001120, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001121, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Nargis Kofta', 'nargis kofta', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nargis kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001121, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001122, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kashmiri Kofta', 'kashmiri kofta', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001122, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001123, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Cheese Kofta', 'cheese kofta', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001123, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001124, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Cheese Butter Masala', 'cheese butter masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese butter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001124, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001125, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Paneer Lasuni', 'paneer lasuni', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lasuni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001125, new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001126, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Paneer Methi', 'paneer methi', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001126, new_variant.variant_id, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001127, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Paneer Hydrabadi', 'paneer hydrabadi', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hydrabadi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001127, new_variant.variant_id, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001128, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Tikka Masala', 'paneer tikka masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001128, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001129, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Lajwab', 'paneer lajwab', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lajwab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001129, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001130, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Kofta', 'paneer kofta', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001130, new_variant.variant_id, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001131, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Kadai', 'paneer kadai', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kadai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001131, new_variant.variant_id, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001132, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Butter Masala', 'paneer butter masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001132, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001133, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Pasanda', 'paneer pasanda', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pasanda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001133, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001134, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Handi', 'paneer handi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001134, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001135, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Bhurji', 'paneer bhurji', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer bhurji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001135, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001136, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Makha''', 'paneer makha''', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer makha'''
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001136, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001137, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Kurm;', 'paneer kurm;', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kurm;'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001137, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001138, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Mu', 'paneer mu', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mu'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001138, new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001139, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Pal', 'paneer pal', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001139, new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001140, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Kol', 'paneer kol', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kol'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001140, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001141, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Tawa', 'paneer tawa', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tawa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001141, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001142, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Masal', 'paneer masal', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer masal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001142, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001143, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Koli', 'paneer koli', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer koli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001143, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001144, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Punjab', 'paneer punjab', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer punjab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001144, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001145, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'om Hand', 'om hand', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'om hand'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001145, new_variant.variant_id, 5.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001146, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Green Peas Masala', 'green peas masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001146, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001147, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Stuffed Tomato', 'stuffed tomato', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuffed tomato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001147, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001148, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Gobi', 'alu gobi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu gobi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001148, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001149, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Methi', 'alu methi', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001149, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001149, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001150, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Palak', 'alu palak', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001150, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001151, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Palak', 'palak', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001151, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001152, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Mutter', 'alu mutter', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001152, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001153, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Jeera', 'alu jeera', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu jeera'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001153, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001154, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Gobi Masala', 'gobi masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'gobi masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001154, new_variant.variant_id, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001155, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Palak Mutter', 'palak mutter', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001155, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001156, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Capsicum', 'alu capsicum', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu capsicum'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001156, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001157, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Methi Mutter Masala', 'methi mutter masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi mutter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001157, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001158, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Channa Masala', 'channa masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'channa masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001158, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001159, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Dahi Pakoda Curry', 'dahi pakoda curry', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi pakoda curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001159, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001160, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Dal Tadka', 'dal tadka', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001160, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001161, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Dal Fry', 'dal fry', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001161, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001162, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Dal Fry Butter', 'dal fry butter', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001162, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001163, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Methi Dal Fry', 'methi dal fry', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001163, new_variant.variant_id, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001164, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Palak Dal Fry', 'palak dal fry', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001164, new_variant.variant_id, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001165, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Kolhapuri Dal Fry', 'kolhapuri dal fry', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kolhapuri dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001165, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001166, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Dal Makhani', 'dal makhani', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal makhani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001166, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001167, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Punjabi Dal Fry', 'punjabi dal fry', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'punjabi dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001167, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001168, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Dal (Plain)', 'dal (plain)', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal (plain)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001168, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001169, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Chole Bathora', 'chole bathora', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chole bathora'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001169, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001170, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Sambar Plate', 'sambar plate', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sambar plate'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001170, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001171, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Roti he', 'butter roti he', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter roti he'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001171, new_variant.variant_id, 38.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001172, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Chapati', 'chapati', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chapati'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001172, new_variant.variant_id, 14.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001173, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Chapati', 'butter chapati', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter chapati'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001173, new_variant.variant_id, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001174, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Parotha', 'parotha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001174, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001175, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Parotha', 'butter parotha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001175, new_variant.variant_id, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001176, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Nan', 'nan', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001176, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001177, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Kulcha', 'kulcha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001177, new_variant.variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001178, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Nan', 'butter nan', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter nan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001178, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001179, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Kulcha', 'butter kulcha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001179, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001179, new_variant.variant_id, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001180, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Cheese Garlic Nan', 'cheese garlic nan', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese garlic nan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001180, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001181, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Kashmiri Nan', 'kashmiri nan', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri nan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001181, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001182, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Cheese Kulcha', 'cheese kulcha', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001182, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001183, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Cheese Garlic Kulcha', 'cheese garlic kulcha', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese garlic kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001183, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001184, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Methi Roti', 'methi roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001184, new_variant.variant_id, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001185, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Makai Roti', 'makai roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'makai roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001185, new_variant.variant_id, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001186, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Missi Roti', 'missi roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'missi roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001186, new_variant.variant_id, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001187, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Masala Kulcha', 'masala kulcha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001187, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001188, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Alu Parotha', 'alu parotha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001188, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001189, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Methi Parotha', 'methi parotha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001189, new_variant.variant_id, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001190, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Pudina Parotha', 'pudina parotha', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pudina parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001190, new_variant.variant_id, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001191, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Cheese Nan', 'cheese nan', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese nan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001191, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001192, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Garlic Nan', 'garlic nan', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic nan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001192, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001193, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Basket Roti', 'basket roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'basket roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001193, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001194, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Bathura (S)', 'bathura (s)', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bathura (s)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001194, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001195, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Steam Rice (I', 'steam rice (i', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steam rice (i'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001195, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001196, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Steam Rice', 'steam rice', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steam rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001196, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001197, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Jeera Rice', 'jeera rice', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001197, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001198, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Veg. Pulav', 'veg. pulav', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001198, new_variant.variant_id, 199.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001199, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Green Peas P''', 'green peas p''', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas p'''
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001199, new_variant.variant_id, 99.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001200, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Kashmiri', 'kashmiri', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001200, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001201, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Tawa Pula’', 'tawa pula’', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa pula’'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001201, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001202, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Mushroom Bi', 'mushroom bi', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom bi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001202, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001203, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'se P', 'se p', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'se p'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001203, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001204, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Palak Rice', 'palak rice', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001204, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001205, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Curd Rice ( Tadka', 'curd rice ( tadka', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd rice ( tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001205, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001206, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Green Spl. Briyani', 'green spl. briyani', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green spl. briyani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001206, new_variant.variant_id, 5.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Rice, Biryani, Pulav" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001207, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001006, 'Dum Biriyani', 'dum biriyani', 'Rice, Biryani, Pulav', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dum biriyani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001207, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001208, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Manchurian With Garlic Sauce', 'manchurian with garlic sauce', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'manchurian with garlic sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001208, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001209, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Manchurian Veg', 'manchurian veg', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'manchurian veg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001209, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001210, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Mushroom Manchurian', 'mushroom manchurian', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001210, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001211, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Paneer Manchurian', 'paneer manchurian', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001211, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001212, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Baby Corn Manchurian', 'baby corn manchurian', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001212, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001213, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Flower Manchurian', 'flower manchurian', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'flower manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001213, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001214, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. Hong Kong', 'veg. hong kong', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hong kong'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001214, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001215, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. Chopsuey', 'veg. chopsuey', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chopsuey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001215, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001216, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'American Chopsuey', 'american chopsuey', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'american chopsuey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001216, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001217, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. Chowmein', 'veg. chowmein', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chowmein'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001217, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001218, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Paneer Schezwan', 'paneer schezwan', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001218, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001219, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Paneer 65', 'paneer 65', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001219, new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001220, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. Schezwan', 'veg. schezwan', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001220, new_variant.variant_id, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001221, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Paneer Chilli', 'paneer chilli', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001221, new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001222, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. 65', 'veg. 65', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001222, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001223, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Combination Fried Rice', 'veg. combination fried rice', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. combination fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001223, new_variant.variant_id, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001224, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Ginger Garlic Fried Rice', 'veg. ginger garlic fried rice', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. ginger garlic fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001224, new_variant.variant_id, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001225, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Tripple Schezwan Fried Rice', 'veg. tripple schezwan fried rice', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. tripple schezwan fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001225, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001226, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Mushroom Fried Rice', 'veg. mushroom fried rice', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. mushroom fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001226, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001227, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hakka noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001227, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001228, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Hong Kong Noodles', 'veg. hong kong noodles', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hong kong noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001228, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001229, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. singapore noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001229, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001230, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Mushroom Noodles', 'veg. mushroom noodles', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. mushroom noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001230, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001231, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Veg. Tripple Schezwan Noodles', 'veg. tripple schezwan noodles', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. tripple schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001231, new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001232, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001232, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001233, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Fried Rice With Manchurian', 'veg. fried rice with manchurian', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fried rice with manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001233, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001234, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Green Salad', 'green salad', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001234, new_variant.variant_id, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001235, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Veg. Raitha', 'veg. raitha', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. raitha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001235, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001236, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Bundi Raitha', 'bundi raitha', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bundi raitha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001236, new_variant.variant_id, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001237, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Pineapple Raitha', 'pineapple raitha', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple raitha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001237, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001238, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Curd', 'curd', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001238, new_variant.variant_id, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001239, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Masala Papad', 'masala papad', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001239, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001240, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Roasted Papad', 'roasted papad', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roasted papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001240, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Cold Drinks" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001241, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001010, 'Soft Drinks', 'soft drinks', 'Cold Drinks', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soft drinks'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001241, new_variant.variant_id, 33.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Cold Drinks" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001242, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001010, 'Soda', 'soda', 'Cold Drinks', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001242, new_variant.variant_id, 28.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Cold Drinks" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001243, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001010, 'Fresh Lime Soda', 'fresh lime soda', 'Cold Drinks', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fresh lime soda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001243, new_variant.variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Cold Drinks" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001244, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001010, 'Fresh Lime Water', 'fresh lime water', 'Cold Drinks', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fresh lime water'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001244, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Cold Drinks" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001245, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001010, 'Mineral Water (1000 Ml)', 'mineral water (1000 ml)', 'Cold Drinks', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mineral water (1000 ml)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001245, new_variant.variant_id, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001246, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Cold Drinks (200 Ml)', 'cold drinks (200 ml)', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cold drinks (200 ml)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001246, new_variant.variant_id, 8.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001247, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Cold Drinks (50', 'cold drinks (50', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cold drinks (50'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001247, new_variant.variant_id, 9.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001248, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Bisleri (500', 'bisleri (500', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bisleri (500'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001248, new_variant.variant_id, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001249, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Red Bull', 'red bull', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'red bull'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001249, new_variant.variant_id, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Lassi" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001250, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001011, 'Kesar Lassi', 'kesar lassi', 'Lassi', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001250, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Lassi" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001251, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001011, 'Mango Lassi', 'mango lassi', 'Lassi', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001251, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Lassi" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001252, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001011, 'Sweet Lassi', 'sweet lassi', 'Lassi', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001252, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001252, new_variant.variant_id, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Lassi" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001253, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001011, 'Salted Lassi', 'salted lassi', 'Lassi', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'salted lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001253, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001253, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001254, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Chikku Milk Shake', 'chikku milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chikku milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001254, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001255, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Banana Milk Shake', 'banana milk shake', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banana milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001255, new_variant.variant_id, 5.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001256, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Apple Milk Shai', 'apple milk shai', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'apple milk shai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001256, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001257, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Chocolate Milk Shal', 'chocolate milk shal', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate milk shal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001257, new_variant.variant_id, 0.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001258, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Rose Milk Shake', 'rose milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rose milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001258, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001258, new_variant.variant_id, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001259, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Kesar Milk Shake', 'kesar milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001259, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001259, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001260, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Mango Milk Shake', 'mango milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001260, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001260, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001261, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Vanilla Milk Shake', 'vanilla milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'vanilla milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001261, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001261, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001262, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Seetaphal Milk Shake (Seasonal)', 'seetaphal milk shake (seasonal)', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'seetaphal milk shake (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001262, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001262, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001263, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Cold Coffee', 'cold coffee', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cold coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001263, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001263, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Fruit Special" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001264, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001013, 'Fruit Salad', 'fruit salad', 'Fruit Special', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001264, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001264, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Fruit Special" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001265, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001013, 'Jelly Plain', 'jelly plain', 'Fruit Special', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jelly plain'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001265, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001265, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Falooda" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001266, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001014, 'Green Special Falooda', 'green special falooda', 'Falooda', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green special falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001266, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001266, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Falooda" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001267, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001014, 'Kulfi Falooda', 'kulfi falooda', 'Falooda', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulfi falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001267, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001267, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Falooda" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001268, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001014, 'Kesar Falooda', 'kesar falooda', 'Falooda', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001268, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001268, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Falooda" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001269, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001014, 'Royal Falooda', 'royal falooda', 'Falooda', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'royal falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001269, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001269, new_variant.variant_id, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001270, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Vanilla (Small)', 'vanilla (small)', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'vanilla (small)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001270, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001270, new_variant.variant_id, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001271, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Vanilla (Big)', 'vanilla (big)', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'vanilla (big)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001271, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001271, new_variant.variant_id, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001272, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Strawberry', 'strawberry', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001272, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001272, new_variant.variant_id, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001273, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Butter Scotch', 'butter scotch', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter scotch'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001273, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001273, new_variant.variant_id, 37.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001274, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Classic Casata', 'classic casata', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'classic casata'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001274, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001274, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001275, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Kesar Pista', 'kesar pista', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar pista'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001275, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001275, new_variant.variant_id, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001276, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Chocolate Feast', 'chocolate feast', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate feast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001276, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001276, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001277, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Chocolate Cone', 'chocolate cone', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate cone'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001277, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001277, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001278, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Butter Scotch Cone', 'butter scotch cone', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter scotch cone'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001278, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001278, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001279, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Choco Bar', 'choco bar', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'choco bar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001279, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001279, new_variant.variant_id, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001280, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Mango Duet', 'mango duet', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango duet'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001280, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001280, new_variant.variant_id, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001281, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Raspberry Duet', 'raspberry duet', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'raspberry duet'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001281, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001281, new_variant.variant_id, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400066001282, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Omlet Sandwich', 'omlet sandwich', 'South Indian Dishes', 'egg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'omlet sandwich' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001282, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001282, new_variant.variant_id, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400066001283, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Toast Omlet Sandwich', 'toast omlet sandwich', 'South Indian Dishes', 'egg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'toast omlet sandwich' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001283, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001283, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001284, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Paper Masala', 'paper masala', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paper masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001284, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001284, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001285, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Sabudana Wada', 'sabudana wada', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sabudana wada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001285, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001285, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001286, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Veg. Cheese Grilled Sandwich', 'veg. cheese grilled sandwich', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese grilled sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001286, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001286, new_variant.variant_id, 177.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001287, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Chilli Toast', 'cheese chilli toast', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese chilli toast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001287, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001287, new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001288, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Tea', 'tea', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tea'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001288, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001288, new_variant.variant_id, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001289, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Tea (Without Sugar)', 'tea (without sugar)', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tea (without sugar)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001289, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001289, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001290, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Khada Pav Bhaji', 'khada pav bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khada pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001290, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001290, new_variant.variant_id, 164.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001291, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Only Bhaji', 'only bhaji', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'only bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001291, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001291, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001292, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Cheese Tawa Pulav', 'cheese tawa pulav', 'South Indian Dishes', 'veg', 'split-tawa-pulav-82', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001292, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001292, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001293, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Mushroom Tawa Pulav', 'mushroom tawa pulav', 'South Indian Dishes', 'veg', 'split-tawa-pulav-82', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001293, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001293, new_variant.variant_id, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001294, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Tawa Idli', 'tawa idli', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001294, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001294, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001295, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Paneer Crispy', 'paneer crispy', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001295, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001295, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001296, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Kadai', 'veg. kadai', 'Punjabi Dishes', 'veg', 'split-veg-kadai-handi-141', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kadai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001296, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001296, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001297, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Handi', 'veg. handi', 'Punjabi Dishes', 'veg', 'split-veg-kadai-handi-141', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001297, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001297, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001298, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Kofta', 'veg. kofta', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001298, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001298, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001299, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Kolhapuri', 'veg. kolhapuri', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001299, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001299, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001300, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Makhanwala', 'veg. makhanwala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. makhanwala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001300, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001300, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001301, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Kashmiri', 'veg. kashmiri', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kashmiri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001301, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001301, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001302, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Moglai', 'veg. moglai', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. moglai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001302, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001302, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001303, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Kurma', 'veg. kurma', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kurma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001303, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001303, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001304, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg. Afghani', 'veg. afghani', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. afghani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001304, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001304, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001305, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Tomato Bartha', 'tomato bartha', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato bartha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001305, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001305, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001306, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Palak Methi', 'palak methi', 'Punjabi Dishes', 'veg', 'split-palak-215', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001306, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001306, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001307, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Palak Lasooni', 'palak lasooni', 'Punjabi Dishes', 'veg', 'split-palak-215', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001307, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001307, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001308, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Alu Sukka Bhaji', 'alu sukka bhaji', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu sukka bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001308, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001308, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001309, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Cheese Patiyala', 'cheese patiyala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese patiyala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001309, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001309, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001310, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Amrutisari', 'paneer amrutisari', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer amrutisari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001310, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001310, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001311, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Paneer Angara', 'paneer angara', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer angara'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001311, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001311, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001312, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Sev Tomato Masala', 'sev tomato masala', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sev tomato masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001312, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001312, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001313, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Veg Khajana', 'veg khajana', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg khajana'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001313, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001313, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Punjabi Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001314, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001004, 'Dal Fry (Gujarati)', 'dal fry (gujarati)', 'Punjabi Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry (gujarati)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001314, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001314, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001315, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Roti (Tandoori)', 'roti (tandoori)', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roti (tandoori)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001315, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001315, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001316, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Stuff Parotha', 'stuff parotha', 'Roti / Naan / Parotha', 'veg', 'split-parotha-246', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuff parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001316, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001316, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400066001317, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Paneer Stuff Parotha', 'paneer stuff parotha', 'Roti / Naan / Parotha', 'veg', 'split-parotha-246', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer stuff parotha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001317, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001317, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001318, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Puri', 'puri', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'puri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001318, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001318, new_variant.variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001319, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Basket Roti', 'butter basket roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter basket roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001319, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001319, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001320, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Maida Roti', 'maida roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'maida roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001320, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001320, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Roti / Naan / Parotha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001321, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001005, 'Butter Maida Roti', 'butter maida roti', 'Roti / Naan / Parotha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter maida roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001321, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001321, new_variant.variant_id, 48.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.60 FROM new_price, ctx;

-- Source: docx/json, "South Indian Dishes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001322, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001001, 'Veg. Masala Pulav', 'veg. masala pulav', 'South Indian Dishes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. masala pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001322, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001322, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001323, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. Chow Chow', 'veg. chow chow', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chow chow'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001323, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001323, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Dishes -- Vegetable" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001324, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001007, 'Veg. Chilli', 'veg. chilli', 'Chinese Dishes -- Vegetable', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001324, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001324, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001325, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Veg. Fried Rice', 'veg. fried rice', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001325, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001325, new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.60 FROM new_price, ctx;

-- Source: docx/json, "Chinese Rice & Noodles" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001326, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001008, 'Paneer Fried Rice', 'paneer fried rice', 'Chinese Rice & Noodles', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001326, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001326, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001327, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Fried Papad', 'fried papad', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fried papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001327, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001327, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001328, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Khichiya Masala Papad', 'khichiya masala papad', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khichiya masala papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001328, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001328, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Salad / Raitha" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001329, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001009, 'Khichiya Roasted Papad', 'khichiya roasted papad', 'Salad / Raitha', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khichiya roasted papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001329, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001329, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001330, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Cocktail Milk Shake', 'cocktail milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cocktail milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001330, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001330, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Milk Shakes" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001331, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001012, 'Dry Fruit Milk Shake', 'dry fruit milk shake', 'Milk Shakes', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dry fruit milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001331, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001331, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Fruit Special" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001332, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001013, 'Fruit Salad Jelly', 'fruit salad jelly', 'Fruit Special', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad jelly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001332, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001332, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Falooda" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001333, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001014, 'Gadbad Special', 'gadbad special', 'Falooda', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'gadbad special'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001333, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001333, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Mocktails" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001334, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001015, 'Fruit Punch', 'fruit punch', 'Mocktails', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit punch'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001334, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001334, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Mocktails" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001335, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001015, 'Yadeen', 'yadeen', 'Mocktails', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'yadeen'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001335, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001335, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Mocktails" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001336, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001015, 'Green Cooler', 'green cooler', 'Mocktails', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green cooler'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001336, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001336, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Mocktails" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001337, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001015, 'Exotica', 'exotica', 'Mocktails', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'exotica'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001337, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001337, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001338, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Malai Kulfi', 'malai kulfi', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001338, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001338, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx/json, "Ice Cream" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400066001339, ctx.restaurant_id, item_cd.canonical_dish_id, 400066001002, 'Kesar Kulfi', 'kesar kulfi', 'Ice Cream', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400066001339, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400066001339, new_variant.variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- -----------------------------------------------------------------------
-- One menu board per restaurant, linked to every category and every item.
-- board_type_code = 'a_la_carte': none of this batch's sources describe a
-- buffet/thali/combo-style board, just a standard printed menu.
-- -----------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 400066001001, ctx.restaurant_id, 'Main Menu', 'a_la_carte' FROM khaustan_onboarding_ctx ctx;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT ctx.restaurant_id, 400066001001, x.menu_category_id, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400066001001, 1), (400066001002, 2), (400066001003, 3), (400066001004, 4), (400066001005, 5), (400066001006, 6), (400066001007, 7), (400066001008, 8), (400066001009, 9), (400066001010, 10), (400066001011, 11), (400066001012, 12), (400066001013, 13), (400066001014, 14), (400066001015, 15)) AS x(menu_category_id, display_sequence);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence, is_featured)
SELECT x.menu_board_item_id, ctx.restaurant_id, 400066001001, x.menu_item_id, x.menu_category_id, x.display_sequence, x.is_featured
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400066001001, 400066001001, 400066001001, 1, FALSE), (400066001002, 400066001002, 400066001001, 2, FALSE), (400066001003, 400066001003, 400066001001, 3, FALSE), (400066001004, 400066001004, 400066001001, 4, FALSE), (400066001005, 400066001005, 400066001001, 5, FALSE), (400066001006, 400066001006, 400066001001, 6, FALSE), (400066001007, 400066001007, 400066001001, 7, FALSE), (400066001008, 400066001008, 400066001001, 8, FALSE), (400066001009, 400066001009, 400066001001, 9, FALSE), (400066001010, 400066001010, 400066001001, 10, FALSE), (400066001011, 400066001011, 400066001001, 11, FALSE), (400066001012, 400066001012, 400066001001, 12, FALSE), (400066001013, 400066001013, 400066001001, 13, FALSE), (400066001014, 400066001014, 400066001001, 14, FALSE), (400066001015, 400066001015, 400066001001, 15, FALSE), (400066001016, 400066001016, 400066001001, 16, FALSE), (400066001017, 400066001017, 400066001001, 17, FALSE), (400066001018, 400066001018, 400066001001, 18, FALSE), (400066001019, 400066001019, 400066001001, 19, FALSE), (400066001020, 400066001020, 400066001001, 20, FALSE), (400066001021, 400066001021, 400066001001, 21, FALSE), (400066001022, 400066001022, 400066001001, 22, FALSE), (400066001023, 400066001023, 400066001001, 23, FALSE), (400066001024, 400066001024, 400066001001, 24, FALSE), (400066001025, 400066001025, 400066001001, 25, FALSE), (400066001026, 400066001026, 400066001001, 26, FALSE), (400066001027, 400066001027, 400066001001, 27, FALSE), (400066001028, 400066001028, 400066001001, 28, FALSE), (400066001029, 400066001029, 400066001001, 29, FALSE), (400066001030, 400066001030, 400066001001, 30, FALSE), (400066001031, 400066001031, 400066001001, 31, FALSE), (400066001032, 400066001032, 400066001001, 32, FALSE), (400066001033, 400066001033, 400066001001, 33, FALSE), (400066001034, 400066001034, 400066001001, 34, FALSE), (400066001035, 400066001035, 400066001001, 35, FALSE), (400066001036, 400066001036, 400066001001, 36, FALSE), (400066001037, 400066001037, 400066001001, 37, FALSE), (400066001038, 400066001038, 400066001001, 38, FALSE), (400066001039, 400066001039, 400066001001, 39, FALSE), (400066001040, 400066001040, 400066001001, 40, FALSE), (400066001041, 400066001041, 400066001001, 41, FALSE), (400066001042, 400066001042, 400066001001, 42, FALSE), (400066001043, 400066001043, 400066001001, 43, FALSE), (400066001044, 400066001044, 400066001001, 44, FALSE), (400066001045, 400066001045, 400066001001, 45, FALSE), (400066001046, 400066001046, 400066001001, 46, FALSE), (400066001047, 400066001047, 400066001001, 47, FALSE), (400066001048, 400066001048, 400066001002, 48, FALSE), (400066001049, 400066001049, 400066001001, 49, FALSE), (400066001050, 400066001050, 400066001001, 50, FALSE), (400066001051, 400066001051, 400066001001, 51, FALSE), (400066001052, 400066001052, 400066001001, 52, FALSE), (400066001053, 400066001053, 400066001001, 53, FALSE), (400066001054, 400066001054, 400066001001, 54, FALSE), (400066001055, 400066001055, 400066001001, 55, FALSE), (400066001056, 400066001056, 400066001001, 56, FALSE), (400066001057, 400066001057, 400066001001, 57, FALSE), (400066001058, 400066001058, 400066001001, 58, FALSE), (400066001059, 400066001059, 400066001002, 59, FALSE), (400066001060, 400066001060, 400066001001, 60, FALSE), (400066001061, 400066001061, 400066001001, 61, FALSE), (400066001062, 400066001062, 400066001003, 62, FALSE), (400066001063, 400066001063, 400066001003, 63, FALSE), (400066001064, 400066001064, 400066001003, 64, FALSE), (400066001065, 400066001065, 400066001003, 65, FALSE), (400066001066, 400066001066, 400066001003, 66, FALSE), (400066001067, 400066001067, 400066001003, 67, FALSE), (400066001068, 400066001068, 400066001003, 68, FALSE), (400066001069, 400066001069, 400066001003, 69, FALSE), (400066001070, 400066001070, 400066001003, 70, FALSE), (400066001071, 400066001071, 400066001003, 71, FALSE), (400066001072, 400066001072, 400066001003, 72, FALSE), (400066001073, 400066001073, 400066001003, 73, FALSE), (400066001074, 400066001074, 400066001003, 74, FALSE), (400066001075, 400066001075, 400066001003, 75, FALSE), (400066001076, 400066001076, 400066001003, 76, FALSE), (400066001077, 400066001077, 400066001003, 77, FALSE), (400066001078, 400066001078, 400066001003, 78, FALSE), (400066001079, 400066001079, 400066001002, 79, FALSE), (400066001080, 400066001080, 400066001003, 80, FALSE), (400066001081, 400066001081, 400066001003, 81, FALSE), (400066001082, 400066001082, 400066001003, 82, FALSE), (400066001083, 400066001083, 400066001003, 83, FALSE), (400066001084, 400066001084, 400066001003, 84, FALSE), (400066001085, 400066001085, 400066001003, 85, FALSE), (400066001086, 400066001086, 400066001003, 86, FALSE), (400066001087, 400066001087, 400066001003, 87, FALSE), (400066001088, 400066001088, 400066001003, 88, FALSE), (400066001089, 400066001089, 400066001004, 89, FALSE), (400066001090, 400066001090, 400066001004, 90, FALSE), (400066001091, 400066001091, 400066001004, 91, FALSE), (400066001092, 400066001092, 400066001004, 92, FALSE), (400066001093, 400066001093, 400066001004, 93, FALSE), (400066001094, 400066001094, 400066001004, 94, FALSE), (400066001095, 400066001095, 400066001004, 95, FALSE), (400066001096, 400066001096, 400066001004, 96, FALSE), (400066001097, 400066001097, 400066001004, 97, FALSE), (400066001098, 400066001098, 400066001004, 98, FALSE), (400066001099, 400066001099, 400066001004, 99, FALSE), (400066001100, 400066001100, 400066001004, 100, FALSE), (400066001101, 400066001101, 400066001002, 101, FALSE), (400066001102, 400066001102, 400066001004, 102, FALSE), (400066001103, 400066001103, 400066001004, 103, FALSE), (400066001104, 400066001104, 400066001004, 104, FALSE), (400066001105, 400066001105, 400066001004, 105, FALSE), (400066001106, 400066001106, 400066001004, 106, FALSE), (400066001107, 400066001107, 400066001004, 107, FALSE), (400066001108, 400066001108, 400066001004, 108, FALSE), (400066001109, 400066001109, 400066001004, 109, FALSE), (400066001110, 400066001110, 400066001002, 110, FALSE), (400066001111, 400066001111, 400066001004, 111, FALSE), (400066001112, 400066001112, 400066001004, 112, FALSE), (400066001113, 400066001113, 400066001002, 113, FALSE), (400066001114, 400066001114, 400066001004, 114, FALSE), (400066001115, 400066001115, 400066001004, 115, FALSE), (400066001116, 400066001116, 400066001004, 116, FALSE), (400066001117, 400066001117, 400066001004, 117, FALSE), (400066001118, 400066001118, 400066001004, 118, FALSE), (400066001119, 400066001119, 400066001004, 119, FALSE), (400066001120, 400066001120, 400066001004, 120, FALSE), (400066001121, 400066001121, 400066001004, 121, FALSE), (400066001122, 400066001122, 400066001004, 122, FALSE), (400066001123, 400066001123, 400066001004, 123, FALSE), (400066001124, 400066001124, 400066001004, 124, FALSE), (400066001125, 400066001125, 400066001002, 125, FALSE), (400066001126, 400066001126, 400066001002, 126, FALSE), (400066001127, 400066001127, 400066001002, 127, FALSE), (400066001128, 400066001128, 400066001004, 128, FALSE), (400066001129, 400066001129, 400066001004, 129, FALSE), (400066001130, 400066001130, 400066001004, 130, FALSE), (400066001131, 400066001131, 400066001004, 131, FALSE), (400066001132, 400066001132, 400066001004, 132, FALSE), (400066001133, 400066001133, 400066001004, 133, FALSE), (400066001134, 400066001134, 400066001004, 134, FALSE), (400066001135, 400066001135, 400066001004, 135, FALSE), (400066001136, 400066001136, 400066001004, 136, FALSE), (400066001137, 400066001137, 400066001004, 137, FALSE), (400066001138, 400066001138, 400066001004, 138, FALSE), (400066001139, 400066001139, 400066001004, 139, FALSE), (400066001140, 400066001140, 400066001004, 140, FALSE), (400066001141, 400066001141, 400066001004, 141, FALSE), (400066001142, 400066001142, 400066001004, 142, FALSE), (400066001143, 400066001143, 400066001004, 143, FALSE), (400066001144, 400066001144, 400066001004, 144, FALSE), (400066001145, 400066001145, 400066001004, 145, FALSE), (400066001146, 400066001146, 400066001004, 146, FALSE), (400066001147, 400066001147, 400066001004, 147, FALSE), (400066001148, 400066001148, 400066001004, 148, FALSE), (400066001149, 400066001149, 400066001004, 149, FALSE), (400066001150, 400066001150, 400066001004, 150, FALSE), (400066001151, 400066001151, 400066001004, 151, FALSE), (400066001152, 400066001152, 400066001004, 152, FALSE), (400066001153, 400066001153, 400066001004, 153, FALSE), (400066001154, 400066001154, 400066001004, 154, FALSE), (400066001155, 400066001155, 400066001004, 155, FALSE), (400066001156, 400066001156, 400066001004, 156, FALSE), (400066001157, 400066001157, 400066001004, 157, FALSE), (400066001158, 400066001158, 400066001004, 158, FALSE), (400066001159, 400066001159, 400066001002, 159, FALSE), (400066001160, 400066001160, 400066001004, 160, FALSE), (400066001161, 400066001161, 400066001004, 161, FALSE), (400066001162, 400066001162, 400066001004, 162, FALSE), (400066001163, 400066001163, 400066001004, 163, FALSE), (400066001164, 400066001164, 400066001004, 164, FALSE), (400066001165, 400066001165, 400066001004, 165, FALSE), (400066001166, 400066001166, 400066001004, 166, FALSE), (400066001167, 400066001167, 400066001004, 167, FALSE), (400066001168, 400066001168, 400066001004, 168, FALSE), (400066001169, 400066001169, 400066001004, 169, FALSE), (400066001170, 400066001170, 400066001004, 170, FALSE), (400066001171, 400066001171, 400066001005, 171, FALSE), (400066001172, 400066001172, 400066001005, 172, FALSE), (400066001173, 400066001173, 400066001005, 173, FALSE), (400066001174, 400066001174, 400066001005, 174, FALSE), (400066001175, 400066001175, 400066001005, 175, FALSE), (400066001176, 400066001176, 400066001005, 176, FALSE), (400066001177, 400066001177, 400066001005, 177, FALSE), (400066001178, 400066001178, 400066001005, 178, FALSE), (400066001179, 400066001179, 400066001005, 179, FALSE), (400066001180, 400066001180, 400066001002, 180, FALSE), (400066001181, 400066001181, 400066001002, 181, FALSE), (400066001182, 400066001182, 400066001002, 182, FALSE), (400066001183, 400066001183, 400066001002, 183, FALSE), (400066001184, 400066001184, 400066001005, 184, FALSE), (400066001185, 400066001185, 400066001005, 185, FALSE), (400066001186, 400066001186, 400066001005, 186, FALSE), (400066001187, 400066001187, 400066001005, 187, FALSE), (400066001188, 400066001188, 400066001005, 188, FALSE), (400066001189, 400066001189, 400066001005, 189, FALSE), (400066001190, 400066001190, 400066001005, 190, FALSE), (400066001191, 400066001191, 400066001005, 191, FALSE), (400066001192, 400066001192, 400066001005, 192, FALSE), (400066001193, 400066001193, 400066001005, 193, FALSE), (400066001194, 400066001194, 400066001005, 194, FALSE), (400066001195, 400066001195, 400066001006, 195, FALSE), (400066001196, 400066001196, 400066001006, 196, FALSE), (400066001197, 400066001197, 400066001006, 197, FALSE), (400066001198, 400066001198, 400066001006, 198, FALSE), (400066001199, 400066001199, 400066001006, 199, FALSE), (400066001200, 400066001200, 400066001006, 200, FALSE), (400066001201, 400066001201, 400066001006, 201, FALSE), (400066001202, 400066001202, 400066001002, 202, FALSE), (400066001203, 400066001203, 400066001006, 203, FALSE), (400066001204, 400066001204, 400066001006, 204, FALSE), (400066001205, 400066001205, 400066001006, 205, FALSE), (400066001206, 400066001206, 400066001006, 206, FALSE), (400066001207, 400066001207, 400066001006, 207, FALSE), (400066001208, 400066001208, 400066001007, 208, FALSE), (400066001209, 400066001209, 400066001007, 209, FALSE), (400066001210, 400066001210, 400066001007, 210, FALSE), (400066001211, 400066001211, 400066001007, 211, FALSE), (400066001212, 400066001212, 400066001007, 212, FALSE), (400066001213, 400066001213, 400066001007, 213, FALSE), (400066001214, 400066001214, 400066001007, 214, FALSE), (400066001215, 400066001215, 400066001007, 215, FALSE), (400066001216, 400066001216, 400066001007, 216, FALSE), (400066001217, 400066001217, 400066001007, 217, FALSE), (400066001218, 400066001218, 400066001007, 218, FALSE), (400066001219, 400066001219, 400066001007, 219, FALSE), (400066001220, 400066001220, 400066001007, 220, FALSE), (400066001221, 400066001221, 400066001007, 221, FALSE), (400066001222, 400066001222, 400066001007, 222, FALSE), (400066001223, 400066001223, 400066001008, 223, FALSE), (400066001224, 400066001224, 400066001008, 224, FALSE), (400066001225, 400066001225, 400066001008, 225, FALSE), (400066001226, 400066001226, 400066001008, 226, FALSE), (400066001227, 400066001227, 400066001008, 227, FALSE), (400066001228, 400066001228, 400066001008, 228, FALSE), (400066001229, 400066001229, 400066001008, 229, FALSE), (400066001230, 400066001230, 400066001008, 230, FALSE), (400066001231, 400066001231, 400066001002, 231, FALSE), (400066001232, 400066001232, 400066001002, 232, FALSE), (400066001233, 400066001233, 400066001008, 233, FALSE), (400066001234, 400066001234, 400066001009, 234, FALSE), (400066001235, 400066001235, 400066001009, 235, FALSE), (400066001236, 400066001236, 400066001009, 236, FALSE), (400066001237, 400066001237, 400066001009, 237, FALSE), (400066001238, 400066001238, 400066001009, 238, FALSE), (400066001239, 400066001239, 400066001009, 239, FALSE), (400066001240, 400066001240, 400066001009, 240, FALSE), (400066001241, 400066001241, 400066001010, 241, FALSE), (400066001242, 400066001242, 400066001010, 242, FALSE), (400066001243, 400066001243, 400066001010, 243, FALSE), (400066001244, 400066001244, 400066001010, 244, FALSE), (400066001245, 400066001245, 400066001010, 245, FALSE), (400066001246, 400066001246, 400066001002, 246, FALSE), (400066001247, 400066001247, 400066001002, 247, FALSE), (400066001248, 400066001248, 400066001002, 248, FALSE), (400066001249, 400066001249, 400066001002, 249, FALSE), (400066001250, 400066001250, 400066001011, 250, FALSE), (400066001251, 400066001251, 400066001011, 251, FALSE), (400066001252, 400066001252, 400066001011, 252, FALSE), (400066001253, 400066001253, 400066001011, 253, FALSE), (400066001254, 400066001254, 400066001012, 254, FALSE), (400066001255, 400066001255, 400066001002, 255, FALSE), (400066001256, 400066001256, 400066001012, 256, FALSE), (400066001257, 400066001257, 400066001012, 257, FALSE), (400066001258, 400066001258, 400066001012, 258, FALSE), (400066001259, 400066001259, 400066001012, 259, FALSE), (400066001260, 400066001260, 400066001012, 260, FALSE), (400066001261, 400066001261, 400066001012, 261, FALSE), (400066001262, 400066001262, 400066001012, 262, FALSE), (400066001263, 400066001263, 400066001012, 263, FALSE), (400066001264, 400066001264, 400066001013, 264, FALSE), (400066001265, 400066001265, 400066001013, 265, FALSE), (400066001266, 400066001266, 400066001014, 266, FALSE), (400066001267, 400066001267, 400066001014, 267, FALSE), (400066001268, 400066001268, 400066001014, 268, FALSE), (400066001269, 400066001269, 400066001014, 269, FALSE), (400066001270, 400066001270, 400066001002, 270, FALSE), (400066001271, 400066001271, 400066001002, 271, FALSE), (400066001272, 400066001272, 400066001002, 272, FALSE), (400066001273, 400066001273, 400066001002, 273, FALSE), (400066001274, 400066001274, 400066001002, 274, FALSE), (400066001275, 400066001275, 400066001002, 275, FALSE), (400066001276, 400066001276, 400066001002, 276, FALSE), (400066001277, 400066001277, 400066001002, 277, FALSE), (400066001278, 400066001278, 400066001002, 278, FALSE), (400066001279, 400066001279, 400066001002, 279, FALSE), (400066001280, 400066001280, 400066001002, 280, FALSE), (400066001281, 400066001281, 400066001002, 281, FALSE), (400066001282, 400066001282, 400066001001, 282, FALSE), (400066001283, 400066001283, 400066001001, 283, FALSE), (400066001284, 400066001284, 400066001001, 284, FALSE), (400066001285, 400066001285, 400066001001, 285, FALSE), (400066001286, 400066001286, 400066001001, 286, FALSE), (400066001287, 400066001287, 400066001001, 287, FALSE), (400066001288, 400066001288, 400066001001, 288, FALSE), (400066001289, 400066001289, 400066001001, 289, FALSE), (400066001290, 400066001290, 400066001001, 290, FALSE), (400066001291, 400066001291, 400066001001, 291, FALSE), (400066001292, 400066001292, 400066001001, 292, FALSE), (400066001293, 400066001293, 400066001001, 293, FALSE), (400066001294, 400066001294, 400066001002, 294, FALSE), (400066001295, 400066001295, 400066001002, 295, FALSE), (400066001296, 400066001296, 400066001004, 296, FALSE), (400066001297, 400066001297, 400066001004, 297, FALSE), (400066001298, 400066001298, 400066001004, 298, FALSE), (400066001299, 400066001299, 400066001004, 299, FALSE), (400066001300, 400066001300, 400066001004, 300, FALSE), (400066001301, 400066001301, 400066001004, 301, FALSE), (400066001302, 400066001302, 400066001004, 302, FALSE), (400066001303, 400066001303, 400066001004, 303, FALSE), (400066001304, 400066001304, 400066001004, 304, FALSE), (400066001305, 400066001305, 400066001004, 305, FALSE), (400066001306, 400066001306, 400066001004, 306, FALSE), (400066001307, 400066001307, 400066001004, 307, FALSE), (400066001308, 400066001308, 400066001004, 308, FALSE), (400066001309, 400066001309, 400066001004, 309, FALSE), (400066001310, 400066001310, 400066001004, 310, FALSE), (400066001311, 400066001311, 400066001004, 311, FALSE), (400066001312, 400066001312, 400066001004, 312, FALSE), (400066001313, 400066001313, 400066001004, 313, FALSE), (400066001314, 400066001314, 400066001004, 314, FALSE), (400066001315, 400066001315, 400066001005, 315, FALSE), (400066001316, 400066001316, 400066001005, 316, FALSE), (400066001317, 400066001317, 400066001005, 317, FALSE), (400066001318, 400066001318, 400066001005, 318, FALSE), (400066001319, 400066001319, 400066001005, 319, FALSE), (400066001320, 400066001320, 400066001005, 320, FALSE), (400066001321, 400066001321, 400066001005, 321, FALSE), (400066001322, 400066001322, 400066001001, 322, FALSE), (400066001323, 400066001323, 400066001007, 323, FALSE), (400066001324, 400066001324, 400066001007, 324, FALSE), (400066001325, 400066001325, 400066001008, 325, FALSE), (400066001326, 400066001326, 400066001008, 326, FALSE), (400066001327, 400066001327, 400066001009, 327, FALSE), (400066001328, 400066001328, 400066001009, 328, FALSE), (400066001329, 400066001329, 400066001009, 329, FALSE), (400066001330, 400066001330, 400066001012, 330, FALSE), (400066001331, 400066001331, 400066001012, 331, FALSE), (400066001332, 400066001332, 400066001013, 332, FALSE), (400066001333, 400066001333, 400066001014, 333, FALSE), (400066001334, 400066001334, 400066001015, 334, FALSE), (400066001335, 400066001335, 400066001015, 335, FALSE), (400066001336, 400066001336, 400066001015, 336, FALSE), (400066001337, 400066001337, 400066001015, 337, FALSE), (400066001338, 400066001338, 400066001002, 338, FALSE), (400066001339, 400066001339, 400066001002, 339, FALSE)) AS x(menu_board_item_id, menu_item_id, menu_category_id, display_sequence, is_featured);

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row with
-- verification_status_code = 'needs_review', one line each.
-- =============================================================================
-- NEEDS_REVIEW [0.70] "Idli" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Idli Va" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mendu Vada" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Idli Butter" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Idli Dahi" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Idli Fry" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dahi Vada" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Sada Dosa" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Masala Dosa" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paper Sada" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Pa" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mysore Sa" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mysore Masa" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Uttappam" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Onion Uttapp:" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Spri" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chinese Dosa" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Puri Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Spring Dos:" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Finger Chips" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kachori" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Potato Toast" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Bread Butter" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chatni Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Toast Butter" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jam Bread" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jam Toast" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jam Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Toast Veg. Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Toast Chatni Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Toast Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Cheese Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Veg. Toast Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Grilled Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Club Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Russian Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Only Cheese Grilled Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Pineapple Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Baby Corn Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Masala Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Spl. Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Babycorn Pizza" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Paneer Pizza" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Nescafe" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Pav Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tomato Pav Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jain Pav Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Masala Pav ( 2 Pcs )" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Pav" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tawa Pulav" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Tawa Pulav" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Special Pav Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Pav Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jain Cheese Pav Bhaji" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Khada Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jain Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tomato Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Palak Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Vegetable Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Sweetcorn Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Hot & Sour Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Manchow Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Clear So" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Noodle" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Mushroo" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Royal Soup" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Hong Kong" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tumyum S" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mix Veg. Pal" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Hara Bara Kabab" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Lollypop" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Flower Lollypop" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Gold Coi" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Crispy" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Chilly" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Chilly" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Manchurian" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer 65" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Schezwan" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Baby Corn Manchurian" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Manchurian" (Soups): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kaju Makhanwala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green's Spl. Veg." (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Koya Kaju" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Masthi ( Your Choice )" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Hara Bara Kabab Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Seekh Kabab Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Patiyala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Cheese Butter Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Chilly Milly Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Hariyali" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Maharaja" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Jaipuri" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Rajsthani" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Jalfrezi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Tawa" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Kneema" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Hyderabadi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Malai Kofta" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Nawabi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kaju Curry" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kaju Handi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Deevani Handi" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kaju Kadai" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kaju Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Kaju Masala" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Mumtaj" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Peshwari" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Dilkhush" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Koliwada" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mix Vegetable" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Navaratan Kurma" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Methi Malai Mutter" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Nargis Kofta" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kashmiri Kofta" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Kofta" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Butter Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Lasuni" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Methi" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Hydrabadi" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Tikka Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Lajwab" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Kofta" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Kadai" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Butter Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Pasanda" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Handi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Bhurji" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Makha'" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Kurm;" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Mu" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Pal" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Kol" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Tawa" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Masal" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Koli" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Punjab" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "om Hand" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Peas Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Stuffed Tomato" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Gobi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Methi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Palak" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Palak" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Mutter" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Jeera" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Gobi Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Palak Mutter" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Capsicum" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Methi Mutter Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Channa Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dahi Pakoda Curry" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dal Tadka" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dal Fry" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dal Fry Butter" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Methi Dal Fry" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Palak Dal Fry" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kolhapuri Dal Fry" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dal Makhani" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Punjabi Dal Fry" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dal (Plain)" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chole Bathora" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Sambar Plate" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Roti he" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chapati" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Chapati" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Nan" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kulcha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Nan" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Kulcha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Garlic Nan" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kashmiri Nan" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Kulcha" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Garlic Kulcha" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Methi Roti" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Makai Roti" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Missi Roti" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Masala Kulcha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Methi Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Pudina Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Nan" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Garlic Nan" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Basket Roti" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Bathura (S)" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Steam Rice (I" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Steam Rice" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jeera Rice" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Pulav" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Peas P'" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kashmiri" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tawa Pula’" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Bi" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "se P" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Palak Rice" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Curd Rice ( Tadka" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Spl. Briyani" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dum Biriyani" (Rice, Biryani, Pulav): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Manchurian With Garlic Sauce" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Manchurian Veg" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Manchurian" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Manchurian" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Baby Corn Manchurian" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Flower Manchurian" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Hong Kong" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Chopsuey" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "American Chopsuey" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Chowmein" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Schezwan" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer 65" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Schezwan" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Chilli" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. 65" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Combination Fried Rice" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Ginger Garlic Fried Rice" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Tripple Schezwan Fried Rice" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Mushroom Fried Rice" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Hakka Noodles" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Hong Kong Noodles" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Singapore Noodles" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Mushroom Noodles" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Tripple Schezwan Noodles" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Schezwan Fried Rice" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Fried Rice With Manchurian" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Salad" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Raitha" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Bundi Raitha" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Pineapple Raitha" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Curd" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Masala Papad" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Roasted Papad" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Soft Drinks" (Cold Drinks): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Soda" (Cold Drinks): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Fresh Lime Soda" (Cold Drinks): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Fresh Lime Water" (Cold Drinks): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mineral Water (1000 Ml)" (Cold Drinks): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cold Drinks (200 Ml)" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cold Drinks (50" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Bisleri (500" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Red Bull" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kesar Lassi" (Lassi): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mango Lassi" (Lassi): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Sweet Lassi" (Lassi): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Salted Lassi" (Lassi): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chikku Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Banana Milk Shake" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Apple Milk Shai" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chocolate Milk Shal" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Rose Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kesar Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mango Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Vanilla Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Seetaphal Milk Shake (Seasonal)" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cold Coffee" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Fruit Salad" (Fruit Special): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Jelly Plain" (Fruit Special): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Special Falooda" (Falooda): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kulfi Falooda" (Falooda): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kesar Falooda" (Falooda): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Royal Falooda" (Falooda): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Vanilla (Small)" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Vanilla (Big)" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Strawberry" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Scotch" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Classic Casata" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kesar Pista" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chocolate Feast" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Chocolate Cone" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Scotch Cone" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Choco Bar" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mango Duet" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Raspberry Duet" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.60] "Omlet Sandwich" (South Indian Dishes): Printed as "Omlet" in a restaurant whose own name is "Greens Veg. Restaurant" and whose full recovered menu is otherwise entirely vegetarian -- may be a besan/gram-flour veg imitation dish rather than a true egg dish, same ambiguity as Hanuman Veg. Treat's Omlet items. Classified 'egg' (the literal reading) rather than assumed veg, since that is the safer default for anyone filtering on this field; confirm with the restaurant.
-- NEEDS_REVIEW [0.60] "Toast Omlet Sandwich" (South Indian Dishes): Printed as "Omlet" in a restaurant whose own name is "Greens Veg. Restaurant" and whose full recovered menu is otherwise entirely vegetarian -- may be a besan/gram-flour veg imitation dish rather than a true egg dish, same ambiguity as Hanuman Veg. Treat's Omlet items. Classified 'egg' (the literal reading) rather than assumed veg, since that is the safer default for anyone filtering on this field; confirm with the restaurant.
-- NEEDS_REVIEW [0.70] "Paper Masala" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Sabudana Wada" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Cheese Grilled Sandwich" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Chilli Toast" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tea" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tea (Without Sugar)" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Khada Pav Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Only Bhaji" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Tawa Pulav" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Mushroom Tawa Pulav" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tawa Idli" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Crispy" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Kadai" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Handi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Kofta" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Kolhapuri" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Makhanwala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Kashmiri" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Moglai" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Kurma" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Afghani" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Tomato Bartha" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Palak Methi" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Palak Lasooni" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Alu Sukka Bhaji" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cheese Patiyala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Amrutisari" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Angara" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Sev Tomato Masala" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg Khajana" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dal Fry (Gujarati)" (Punjabi Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Roti (Tandoori)" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Stuff Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Paneer Stuff Parotha" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Puri" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Butter Basket Roti" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Maida Roti" (Roti / Naan / Parotha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.60] "Butter Maida Roti" (Roti / Naan / Parotha): Printed as 'Butter Maida' -- 'Roti' inferred by analogy to the adjacent 'Maida Roti' line; verify against the printed menu.
-- NEEDS_REVIEW [0.70] "Veg. Masala Pulav" (South Indian Dishes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Chow Chow" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Veg. Chilli" (Chinese Dishes -- Vegetable): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.60] "Veg. Fried Rice" (Chinese Rice & Noodles): A second number (225.00) appeared immediately after this line with no clear owner -- not used, since it may belong to the following item instead. Verify against the printed menu.
-- NEEDS_REVIEW [0.70] "Paneer Fried Rice" (Chinese Rice & Noodles): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Fried Papad" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Khichiya Masala Papad" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Khichiya Roasted Papad" (Salad / Raitha): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Cocktail Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Dry Fruit Milk Shake" (Milk Shakes): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Fruit Salad Jelly" (Fruit Special): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Gadbad Special" (Falooda): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Fruit Punch" (Mocktails): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Yadeen" (Mocktails): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Green Cooler" (Mocktails): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Exotica" (Mocktails): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Malai Kulfi" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.
-- NEEDS_REVIEW [0.70] "Kesar Kulfi" (Ice Cream): Recovered from a significantly OCR-garbled source document (scanned PDF menu); individual line was clean, but the source's overall reliability is lower than the other restaurants in this batch -- recommend spot-checking against the original PDF before publishing.

-- =============================================================================
-- EXCLUDED: 92 fragments from the source that could not be
-- confidently recovered into a usable dish name + price were left out entirely
-- rather than guessed at. Raw fragment quoted for manual follow-up against the
-- original source document.
-- =============================================================================
-- EXCLUDED #12: 'Cheese Pa' -- name truncated beyond confident recovery
-- EXCLUDED #16: 'Rava Dosa' price shown as '5.00'; 'Rava Ma:' name+price both corrupted -- kept 'Rava Dosa' out too since its price token is almost certainly missing a leading digit and no correct value can be confirmed
-- EXCLUDED #22: 'if' / 'ttappal' -- pure fragment, no recoverable name
-- EXCLUDED #379: 'Batata Wada' priced '00.00' -- price token is literally zero -- not usable
-- EXCLUDED #99: 'Paneer Ma' + 'Soup' at 470.00 -- fragments likely belong to two different, unrelated menu lines
-- EXCLUDED #104: 'Paneer Resh...' / 'Pahadi' both priced '40.00' -- price implausibly low for a Paneer main course elsewhere priced 200+; likely missing a leading digit
-- EXCLUDED #184: 'Paneer' / 'Tawa' priced '0.00' -- price token is literally zero; possibly a corrupted duplicate of #182 Paneer Tawa (290.00)
-- EXCLUDED #212: stray extra '360.00' near 'Methi Dry' -- cannot confidently attach to any specific dish
-- EXCLUDED #266: 'Veg' / 'hap' -- pure fragment, no recoverable name
-- EXCLUDED #1: ['Tea', '35.00', 'Tea (Without Sugar)', '40.00'] -- not confidently resolved
-- EXCLUDED #298: ['Veg. Hong Kong Fried Rice', '245.00', '245.00'] -- not confidently resolved
-- EXCLUDED #302: ['Veg. Chinese Pulav', '210.00', '240.00'] -- not confidently resolved
-- EXCLUDED #306: ['Veg. Schezwan Noodles', '230.00', '225.00'] -- not confidently resolved
-- EXCLUDED #394: ['Veg. Mix Noodles', '265.00', '280.00'] -- not confidently resolved
-- EXCLUDED #398: ['Veg. Mix Fried Rice', '260.00', '270.00'] -- not confidently resolved
-- EXCLUDED #330: ['bi (Sweet Lim', '110.00', '110.00'] -- not confidently resolved
-- EXCLUDED #1: ['230.00'] -- no recoverable name or price
-- EXCLUDED #18: ['Onion'] -- no recoverable name or price
-- EXCLUDED #19: ['Onion Ra', 'al'] -- no recoverable name or price
-- EXCLUDED #24: ['40.00'] -- no recoverable name or price
-- EXCLUDED #25: ['0.00'] -- no recoverable name or price
-- EXCLUDED #26: ['To', 'Omle'] -- no recoverable name or price
-- EXCLUDED #28: ['Pala’'] -- no recoverable name or price
-- EXCLUDED #29: ['Palak'] -- no recoverable name or price
-- EXCLUDED #30: ['Schezwan'] -- no recoverable name or price
-- EXCLUDED #31: ['Schezwan Mas'] -- no recoverable name or price
-- EXCLUDED #32: ['Millennium Dos:'] -- no recoverable name or price
-- EXCLUDED #102: ['Paneer'] -- no recoverable name or price
-- EXCLUDED #103: ['Paneer Ac', 'itl'] -- no recoverable name or price
-- EXCLUDED #340: [] -- no recoverable name or price
-- EXCLUDED #10: ['40.00'] -- no recoverable name or price
-- EXCLUDED #114: ['00'] -- no recoverable name or price
-- EXCLUDED #528: ['|', '00'] -- no recoverable name or price
-- EXCLUDED #108: ['li', 'Veg'] -- no recoverable name or price
-- EXCLUDED #109: ['Corn', '30)'] -- no recoverable name or price
-- EXCLUDED #110: ['Alu Tiki'] -- no recoverable name or price
-- EXCLUDED #111: ['Veg. Spring'] -- no recoverable name or price
-- EXCLUDED #392: ['Veg. Cheese Spri'] -- no recoverable name or price
-- EXCLUDED #393: ['Veg. Paneer Spring R'] -- no recoverable name or price
-- EXCLUDED #115: ['Idli Chilly'] -- no recoverable name or price
-- EXCLUDED #116: ['Schezwan Fing'] -- no recoverable name or price
-- EXCLUDED #117: ['Chinese Bhel'] -- no recoverable name or price
-- EXCLUDED #142: ['Veg'] -- no recoverable name or price
-- EXCLUDED #386: ['Veg. Chop. Masala'] -- no recoverable name or price
-- EXCLUDED #185: ['Paneer'] -- no recoverable name or price
-- EXCLUDED #186: ['Paneer'] -- no recoverable name or price
-- EXCLUDED #18: ['Lp', '60.00'] -- no recoverable name or price
-- EXCLUDED #190: ['5.00'] -- no recoverable name or price
-- EXCLUDED #191: ['0.00'] -- no recoverable name or price
-- EXCLUDED #192: ['5.00'] -- no recoverable name or price
-- EXCLUDED #194: ['Sarso'] -- no recoverable name or price
-- EXCLUDED #195: ['Mushroo', 'rn Masala'] -- no recoverable name or price
-- EXCLUDED #390: ['Mushroom'] -- no recoverable name or price
-- EXCLUDED #196: ['Dum Alu Kashi'] -- no recoverable name or price
-- EXCLUDED #197: ['Dum Alu Punjabi'] -- no recoverable name or price
-- EXCLUDED #200: ['Baingan Bartha'] -- no recoverable name or price
-- EXCLUDED #202: ['Stuffed Capsicut'] -- no recoverable name or price
-- EXCLUDED #203: ['Bhendi Masala.'] -- no recoverable name or price
-- EXCLUDED #240: [] -- no recoverable name or price
-- EXCLUDED #204: ['Bhendi Fry'] -- no recoverable name or price
-- EXCLUDED #213: ['Veg. Tiranga'] -- no recoverable name or price
-- EXCLUDED #260: ['Veg. Bi'] -- no recoverable name or price
-- EXCLUDED #261: ['Paneer'] -- no recoverable name or price
-- EXCLUDED #26: ['40.00'] -- no recoverable name or price
-- EXCLUDED #264: ['00'] -- no recoverable name or price
-- EXCLUDED #265: ['li', '00'] -- no recoverable name or price
-- EXCLUDED #268: ['Chee:'] -- no recoverable name or price
-- EXCLUDED #269: ['Cheese'] -- no recoverable name or price
-- EXCLUDED #270: ['Veg. Chees'] -- no recoverable name or price
-- EXCLUDED #271: ['Dal Khichdi'] -- no recoverable name or price
-- EXCLUDED #511: ['Dal Khichdi Tadka'] -- no recoverable name or price
-- EXCLUDED #515: ['Paneer Tikka'] -- no recoverable name or price
-- EXCLUDED #283: ['Veg. Sweet & Sour.'] -- no recoverable name or price
-- EXCLUDED #295: ['Veg. Schezwan Fried Rice'] -- no recoverable name or price
-- EXCLUDED #299: ['Veg. Singapore Fried Rice'] -- no recoverable name or price
-- EXCLUDED #303: ['Veg. Fried Rice With Noodles'] -- no recoverable name or price
-- EXCLUDED #307: ['Veg. Manchow Noodles'] -- no recoverable name or price
-- EXCLUDED #395: ['Veg. Mix Schezwan Noodles'] -- no recoverable name or price
-- EXCLUDED #399: ['Veg. Mix Schezwan Fried Rice'] -- no recoverable name or price
-- EXCLUDED #383: ['Frooti'] -- no recoverable name or price
-- EXCLUDED #329: ['Butter'] -- no recoverable name or price
-- EXCLUDED #523: ['Gulab J', 'es'] -- no recoverable name or price
-- EXCLUDED #332: ['110.00'] -- no recoverable name or price
-- EXCLUDED #333: ['Ap', '0.00'] -- no recoverable name or price
-- EXCLUDED #334: ['Gr.', '135.00'] -- no recoverable name or price
-- EXCLUDED #335: ['Gang', 'AN'] -- no recoverable name or price
-- EXCLUDED #336: ['Maral'] -- no recoverable name or price
-- EXCLUDED #337: ['Cocktail', 'Ol'] -- no recoverable name or price
-- EXCLUDED #338: ['Water Melon'] -- no recoverable name or price
-- EXCLUDED #339: ['Mango (Seasonal', 'Mitk Sha'] -- no recoverable name or price
-- EXCLUDED #386: ['Pineapple Mil'] -- no recoverable name or price
-- EXCLUDED #349: ['Strawberry Milk Shake (Seasonal) 165.00'] -- no recoverable name or price

-- =============================================================================
-- UNMAPPED: restaurant-level facts with no clean schema home, or deliberately
-- left for a human decision.
-- =============================================================================
-- UNMAPPED: This source is a significantly OCR-garbled scan (source_file: "NON AC GREEN.pdf"), unlike the other three restaurants in this batch. Every item above was individually recoverable (a confirmed name + confirmed price), but the source's overall reliability is lower -- recommend a full spot-check against the original PDF before publishing this restaurant, not just reviewing the flagged rows.
-- UNMAPPED: Category boundaries are approximate: section headers are scattered and sometimes truncated in the corrupted token stream, so raw_category_text above groups items under the nearest confirmed header rather than a precisely re-derived section structure.
-- UNMAPPED: No phone number, delivery, or takeaway claim survived anywhere in the recoverable text for this restaurant -- none were asserted rather than guessed.
-- UNMAPPED: 92 numbered line fragments could not be confidently recovered into a usable dish name + price at all and were excluded outright rather than guessed at -- see the EXCLUDED block below for every one, quoted with its raw fragment, for manual follow-up against the original PDF.
