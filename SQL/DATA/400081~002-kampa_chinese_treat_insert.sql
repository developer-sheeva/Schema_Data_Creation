-- =============================================================================
-- Khaustan onboarding script: Kampa Chinese Treat
-- Source: Kampa_Chinese_Treat_Menu_Transcribed.docx (docx, tab/run-separated paragraphs)
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
-- SOURCE-SPECIFIC NOTE: this docx's paragraphs concatenate multiple runs 
-- (item name + each price column) with NO delimiter once read via python-docx's
-- standard .text property -- e.g. "Manchow Soup" + "220" + "250" + "260" read back as
-- "Manchow Soup220250260". Every item below was reconstructed from the raw run
-- text with this in mind.
--
-- BUG FIX this round: the Veg./Chicken/Seafood matrix items (SOUPS and RICE &
-- NOODLES sections) had food_classification_code wrongly set to 'chicken' or
-- 'seafood' instead of 'non_veg' -- that column only accepts veg/egg/non_veg, so
-- this would have been a real CHECK constraint violation, not a cosmetic issue.
-- Fixed, along with protein_type codes now matching your real UPPERCASE data.
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
  WHERE normalized_name = lower(trim('Kampa Chinese Treat')) AND postal_code = '400081';

  IF NOT FOUND THEN
    v_establishment_id := 400081002;
    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, city, state, country_code, latitude, longitude)
    VALUES (v_establishment_id, 'Kampa Chinese Treat', lower(trim('Kampa Chinese Treat')), 'Shop No. 2 & 3, Vidhata Apartment, Navghar Road', 'Mulund (E.)', '400081', 'Mumbai', 'Maharashtra', 'IN', 19.168121116807693, 72.96145287805959);
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant
  WHERE establishment_id = v_establishment_id AND display_name = 'Kampa Chinese Treat';

  IF NOT FOUND THEN
    v_restaurant_id := 400081002;
    INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, has_bar, bar_license_type)
    VALUES (v_restaurant_id, v_establishment_id, 'Kampa Chinese Treat', lower(trim('Kampa Chinese Treat')), FALSE, 'none');
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
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Kampa_Chinese_Treat_Menu_Transcribed.docx')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant. Aborting.', 'Kampa_Chinese_Treat_Menu_Transcribed.docx';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400081002001, 'ai_menu_extraction', 'Kampa_Chinese_Treat_Menu_Transcribed.docx');
UPDATE khaustan_onboarding_ctx SET source_id = 400081002001;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400081002001, ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx SET extraction_batch_id = 400081002001;

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT x.phone_id, ctx.restaurant_id, x.phone_number, x.is_primary
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081002001, '9324262872', TRUE), (400081002002, '8655002872', FALSE), (400081002003, '9136132872', FALSE)) AS x(phone_id, phone_number, is_primary);

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT ctx.restaurant_id, sm.service_mode_id, TRUE, x.notes
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES ('delivery', 'Docx footer states "Free Home Delivery".')) AS x(code, notes)
JOIN service_mode sm ON sm.code = x.code;

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount)
SELECT ctx.restaurant_id, TRUE, TRUE, NULL FROM khaustan_onboarding_ctx ctx;

DO $do$
DECLARE
  v_provider_id BIGINT;
BEGIN
  SELECT delivery_provider_id INTO v_provider_id FROM delivery_provider WHERE provider_code = 'SELF';
  IF NOT FOUND THEN
    v_provider_id := 400081002001;
    INSERT INTO delivery_provider (delivery_provider_id, provider_code, provider_name, provider_type_code)
    VALUES (v_provider_id, 'SELF', 'Self Delivery', 'self');
  END IF;

  INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, base_delivery_charge, effective_from)
  SELECT 400081002001, ctx.restaurant_id, v_provider_id, 'fixed', 0.00, (clock_timestamp() AT TIME ZONE 'UTC')
  FROM khaustan_onboarding_ctx ctx;
END $do$;

DO $do$
DECLARE
  v_tag_id BIGINT;
BEGIN
  SELECT tag_id INTO v_tag_id FROM platform_tag WHERE tag_code = 'JAIN_AVAILABLE';
  INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
  SELECT 400081002001, ctx.restaurant_id, v_tag_id, FALSE FROM khaustan_onboarding_ctx ctx;
END $do$;

DO $do$
DECLARE
  v_tag_id BIGINT;
BEGIN
  SELECT tag_id INTO v_tag_id FROM platform_tag WHERE tag_code = 'SPICY';
  INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
  SELECT 400081002002, ctx.restaurant_id, v_tag_id, FALSE FROM khaustan_onboarding_ctx ctx;
END $do$;

DO $do$
DECLARE
  v_tag_id BIGINT;
BEGIN
  SELECT tag_id INTO v_tag_id FROM platform_tag WHERE tag_code = 'cuisine_chinese';
  INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
  SELECT 400081002003, ctx.restaurant_id, v_tag_id, FALSE FROM khaustan_onboarding_ctx ctx;
END $do$;

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name, batched
-- into one set-based statement (safe: normalized_name is the identity
-- key and the candidate list is de-duplicated before generation).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_dish_id, canonical_dish_name_id, canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    (400081002001, 400081002001, 'Manchow Soup', 'manchow soup', 'veg', NULL),
    (400081002002, 400081002002, 'Chicken Manchow Soup', 'chicken manchow soup', 'non_veg', 'CHICKEN'),
    (400081002003, 400081002003, 'Seafood Manchow Soup', 'seafood manchow soup', 'non_veg', 'SEAFOOD'),
    (400081002004, 400081002004, 'Sweet Corn Soup', 'sweet corn soup', 'veg', NULL),
    (400081002005, 400081002005, 'Chicken Sweet Corn Soup', 'chicken sweet corn soup', 'non_veg', 'CHICKEN'),
    (400081002006, 400081002006, 'Seafood Sweet Corn Soup', 'seafood sweet corn soup', 'non_veg', 'SEAFOOD'),
    (400081002007, 400081002007, 'Hot ''n'' Sour Soup', 'hot ''n'' sour soup', 'veg', NULL),
    (400081002008, 400081002008, 'Chicken Hot ''n'' Sour Soup', 'chicken hot ''n'' sour soup', 'non_veg', 'CHICKEN'),
    (400081002009, 400081002009, 'Seafood Hot ''n'' Sour Soup', 'seafood hot ''n'' sour soup', 'non_veg', 'SEAFOOD'),
    (400081002010, 400081002010, 'Burnt Garlic Soup', 'burnt garlic soup', 'veg', NULL),
    (400081002011, 400081002011, 'Chicken Burnt Garlic Soup', 'chicken burnt garlic soup', 'non_veg', 'CHICKEN'),
    (400081002012, 400081002012, 'Seafood Burnt Garlic Soup', 'seafood burnt garlic soup', 'non_veg', 'SEAFOOD'),
    (400081002013, 400081002013, 'Oriental Soup', 'oriental soup', 'veg', NULL),
    (400081002014, 400081002014, 'Chicken Oriental Soup', 'chicken oriental soup', 'non_veg', 'CHICKEN'),
    (400081002015, 400081002015, 'Seafood Oriental Soup', 'seafood oriental soup', 'non_veg', 'SEAFOOD'),
    (400081002016, 400081002016, 'Laksa', 'laksa', 'veg', NULL),
    (400081002017, 400081002017, 'Chicken Laksa', 'chicken laksa', 'non_veg', 'CHICKEN'),
    (400081002018, 400081002018, 'Seafood Laksa', 'seafood laksa', 'non_veg', 'SEAFOOD'),
    (400081002019, 400081002019, 'Peppery Lemon Soup', 'peppery lemon soup', 'veg', NULL),
    (400081002020, 400081002020, 'Chicken Peppery Lemon Soup', 'chicken peppery lemon soup', 'non_veg', 'CHICKEN'),
    (400081002021, 400081002021, 'Seafood Peppery Lemon Soup', 'seafood peppery lemon soup', 'non_veg', 'SEAFOOD'),
    (400081002022, 400081002022, 'Lemon Coriander Soup', 'lemon coriander soup', 'veg', NULL),
    (400081002023, 400081002023, 'Chicken Lemon Coriander Soup', 'chicken lemon coriander soup', 'non_veg', 'CHICKEN'),
    (400081002024, 400081002024, 'Seafood Lemon Coriander Soup', 'seafood lemon coriander soup', 'non_veg', 'SEAFOOD'),
    (400081002025, 400081002025, 'Wonton Soup', 'wonton soup', 'veg', NULL),
    (400081002026, 400081002026, 'Chicken Wonton Soup', 'chicken wonton soup', 'non_veg', 'CHICKEN'),
    (400081002027, 400081002027, 'Seafood Wonton Soup', 'seafood wonton soup', 'non_veg', 'SEAFOOD'),
    (400081002028, 400081002028, 'Chicken Lung Fung Soup', 'chicken lung fung soup', 'non_veg', 'CHICKEN'),
    (400081002029, 400081002029, 'Seafood Lung Fung Soup', 'seafood lung fung soup', 'non_veg', 'SEAFOOD'),
    (400081002030, 400081002030, 'Tom Yum', 'tom yum', 'veg', NULL),
    (400081002031, 400081002031, 'Chicken Tom Yum', 'chicken tom yum', 'non_veg', 'CHICKEN'),
    (400081002032, 400081002032, 'Seafood Tom Yum', 'seafood tom yum', 'non_veg', 'SEAFOOD'),
    (400081002033, 400081002033, 'Chicken Tom Kha Gaa', 'chicken tom kha gaa', 'non_veg', 'CHICKEN'),
    (400081002034, 400081002034, 'Seafood Tom Kha Koong', 'seafood tom kha koong', 'non_veg', 'SEAFOOD'),
    (400081002035, 400081002035, 'Talumein Soup', 'talumein soup', 'veg', NULL),
    (400081002036, 400081002036, 'Chicken Talumein Soup', 'chicken talumein soup', 'non_veg', 'CHICKEN'),
    (400081002037, 400081002037, 'Seafood Talumein Soup', 'seafood talumein soup', 'non_veg', 'SEAFOOD'),
    (400081002038, 400081002038, 'Crispy Rice Soup', 'crispy rice soup', 'veg', NULL),
    (400081002039, 400081002039, 'Chicken Crispy Rice Soup', 'chicken crispy rice soup', 'non_veg', 'CHICKEN'),
    (400081002040, 400081002040, 'Seafood Crispy Rice Soup', 'seafood crispy rice soup', 'non_veg', 'SEAFOOD'),
    (400081002041, 400081002041, 'Chicken Spicy Tomato Soup', 'chicken spicy tomato soup', 'non_veg', 'CHICKEN'),
    (400081002042, 400081002042, 'Seafood Spicy Tomato Soup', 'seafood spicy tomato soup', 'non_veg', 'SEAFOOD'),
    (400081002043, 400081002043, 'Chicken Meat Ball Soup with Silky Noodles', 'chicken meat ball soup with silky noodles', 'non_veg', 'CHICKEN'),
    (400081002044, 400081002044, 'Paneer Chilly', 'paneer chilly', 'veg', NULL),
    (400081002045, 400081002045, 'Paneer Manchurian Dry', 'paneer manchurian dry', 'veg', NULL),
    (400081002046, 400081002046, 'Paneer Hot Garlic', 'paneer hot garlic', 'veg', NULL),
    (400081002047, 400081002047, 'Paneer Schezwan', 'paneer schezwan', 'veg', NULL),
    (400081002048, 400081002048, 'Paneer Satay', 'paneer satay', 'veg', NULL),
    (400081002049, 400081002049, 'Paneer Oyster', 'paneer oyster', 'veg', NULL),
    (400081002050, 400081002050, 'Paneer Salt ''n'' Pepper', 'paneer salt ''n'' pepper', 'veg', NULL),
    (400081002051, 400081002051, 'Paneer Hunan', 'paneer hunan', 'veg', NULL),
    (400081002052, 400081002052, 'Paneer Taichin', 'paneer taichin', 'veg', NULL),
    (400081002053, 400081002053, 'Paneer Black Bean', 'paneer black bean', 'veg', NULL),
    (400081002054, 400081002054, 'Paneer Chilly Bean', 'paneer chilly bean', 'veg', NULL),
    (400081002055, 400081002055, 'Paneer Butter Garlic', 'paneer butter garlic', 'veg', NULL),
    (400081002056, 400081002056, 'Paneer Kungpao', 'paneer kungpao', 'veg', NULL),
    (400081002057, 400081002057, 'Crispy Threaded Paneer', 'crispy threaded paneer', 'veg', NULL),
    (400081002058, 400081002058, 'Silken Tofu Black Bean', 'silken tofu black bean', 'veg', NULL),
    (400081002059, 400081002059, 'Silken Tofu Chilly Bean', 'silken tofu chilly bean', 'veg', NULL),
    (400081002060, 400081002060, 'Silken Tofu Hunan', 'silken tofu hunan', 'veg', NULL),
    (400081002061, 400081002061, 'Silken Tofu Taichin', 'silken tofu taichin', 'veg', NULL),
    (400081002062, 400081002062, 'Veg. Manchurian', 'veg. manchurian', 'veg', NULL),
    (400081002063, 400081002063, 'Veg. Spring Roll', 'veg. spring roll', 'veg', NULL),
    (400081002064, 400081002064, 'Veg. Wonton', 'veg. wonton', 'veg', NULL),
    (400081002065, 400081002065, 'Veg. Crispy', 'veg. crispy', 'veg', NULL),
    (400081002066, 400081002066, 'Veg. Oyster', 'veg. oyster', 'veg', NULL),
    (400081002067, 400081002067, 'Veg. Stir Fry Chinese Greens', 'veg. stir fry chinese greens', 'veg', NULL),
    (400081002068, 400081002068, 'Baby Corn Chilly', 'baby corn chilly', 'veg', NULL),
    (400081002069, 400081002069, 'Mushroom Chilly', 'mushroom chilly', 'veg', NULL),
    (400081002070, 400081002070, 'Chilly Potatoes', 'chilly potatoes', 'veg', NULL),
    (400081002071, 400081002071, 'Golden Fried Baby Corn', 'golden fried baby corn', 'veg', NULL),
    (400081002072, 400081002072, 'Veg. Green Sauce', 'veg. green sauce', 'veg', NULL),
    (400081002073, 400081002073, 'Veg. Butter Garlic', 'veg. butter garlic', 'veg', NULL),
    (400081002074, 400081002074, 'Baby Corn Mushroom Salt ''n'' Pepper', 'baby corn mushroom salt ''n'' pepper', 'veg', NULL),
    (400081002075, 400081002075, 'Veg. Dim Sum', 'veg. dim sum', 'veg', NULL),
    (400081002076, 400081002076, 'Chicken Wonton', 'chicken wonton', 'non_veg', 'CHICKEN'),
    (400081002077, 400081002077, 'Chicken Lollypop', 'chicken lollypop', 'non_veg', 'CHICKEN'),
    (400081002078, 400081002078, 'Chicken Spring Roll', 'chicken spring roll', 'non_veg', 'CHICKEN'),
    (400081002079, 400081002079, 'Chicken Dim Sum', 'chicken dim sum', 'non_veg', 'CHICKEN'),
    (400081002080, 400081002080, 'Chicken Hot Garlic', 'chicken hot garlic', 'non_veg', 'CHICKEN'),
    (400081002081, 400081002081, 'Chicken Lemon Garlic', 'chicken lemon garlic', 'non_veg', 'CHICKEN'),
    (400081002082, 400081002082, 'Chicken Schezwan', 'chicken schezwan', 'non_veg', 'CHICKEN'),
    (400081002083, 400081002083, 'Chicken Manchurian', 'chicken manchurian', 'non_veg', 'CHICKEN'),
    (400081002084, 400081002084, 'Chicken Crispy', 'chicken crispy', 'non_veg', 'CHICKEN'),
    (400081002085, 400081002085, 'Chicken Chilly', 'chicken chilly', 'non_veg', 'CHICKEN'),
    (400081002086, 400081002086, 'Chicken Mongolian', 'chicken mongolian', 'non_veg', 'CHICKEN'),
    (400081002087, 400081002087, 'Chicken Satay', 'chicken satay', 'non_veg', 'CHICKEN'),
    (400081002088, 400081002088, 'Chicken Malaysian', 'chicken malaysian', 'non_veg', 'CHICKEN'),
    (400081002089, 400081002089, 'Chicken Kampa Special', 'chicken kampa special', 'non_veg', 'CHICKEN'),
    (400081002090, 400081002090, 'Chicken Taronest', 'chicken taronest', 'non_veg', 'CHICKEN'),
    (400081002091, 400081002091, 'Chicken Oyster', 'chicken oyster', 'non_veg', 'CHICKEN'),
    (400081002092, 400081002092, 'Chicken Cilantro', 'chicken cilantro', 'non_veg', 'CHICKEN'),
    (400081002093, 400081002093, 'Chicken Taichin', 'chicken taichin', 'non_veg', 'CHICKEN'),
    (400081002094, 400081002094, 'Chicken Kungpao', 'chicken kungpao', 'non_veg', 'CHICKEN'),
    (400081002095, 400081002095, 'Chicken Shanghai', 'chicken shanghai', 'non_veg', 'CHICKEN'),
    (400081002096, 400081002096, 'Chicken Mustard', 'chicken mustard', 'non_veg', 'CHICKEN'),
    (400081002097, 400081002097, 'Chicken Black Bean', 'chicken black bean', 'non_veg', 'CHICKEN'),
    (400081002098, 400081002098, 'Chicken Chilly Bean', 'chicken chilly bean', 'non_veg', 'CHICKEN'),
    (400081002099, 400081002099, 'Chicken Red Cooked', 'chicken red cooked', 'non_veg', 'CHICKEN'),
    (400081002100, 400081002100, 'Chicken Hunan', 'chicken hunan', 'non_veg', 'CHICKEN'),
    (400081002101, 400081002101, 'Chicken Butter Garlic', 'chicken butter garlic', 'non_veg', 'CHICKEN'),
    (400081002102, 400081002102, 'Roast Chicken Wings in Bbq Sauce', 'roast chicken wings in bbq sauce', 'non_veg', 'CHICKEN'),
    (400081002103, 400081002103, 'Fire Cracker Prawns (6 Pcs.)', 'fire cracker prawns (6 pcs.)', 'non_veg', 'SEAFOOD'),
    (400081002104, 400081002104, 'Golden Fried Prawns (Medn Prawns 8 Pcs.)', 'golden fried prawns (medn prawns 8 pcs.)', 'non_veg', 'SEAFOOD'),
    (400081002105, 400081002105, 'Squids Salt ''n'' Pepper', 'squids salt ''n'' pepper', 'non_veg', 'SEAFOOD'),
    (400081002106, 400081002106, 'Medium Prawns', 'medium prawns', 'non_veg', 'SEAFOOD'),
    (400081002107, 400081002107, 'Jumbo Prawns (4 Pcs.)', 'jumbo prawns (4 pcs.)', 'non_veg', 'SEAFOOD'),
    (400081002108, 400081002108, 'Rawas', 'rawas', 'non_veg', 'SEAFOOD'),
    (400081002109, 400081002109, 'Squids', 'squids', 'non_veg', 'SEAFOOD'),
    (400081002110, 400081002110, 'Pomfret', 'pomfret', 'non_veg', 'SEAFOOD'),
    (400081002111, 400081002111, 'Veg. Chinese Platter (Crispy Veg., Paneer Butter Garlic, Veg. Spring Roll, Potato Chilly, Veg. Manchurian)', 'veg. chinese platter (crispy veg., paneer butter garlic, veg. spring roll, potato chilly, veg. manchurian)', 'veg', NULL),
    (400081002112, 400081002112, 'Chicken Platter (Lollypop, Spring Roll, Crispy Chicken, Chicken Chilly, Chicken Hunan)', 'chicken platter (lollypop, spring roll, crispy chicken, chicken chilly, chicken hunan)', 'non_veg', 'CHICKEN'),
    (400081002113, 400081002113, 'Mixed Platter (Prawns in Butter Pepper Garlic sauce, Chilli Basa, Chicken in Hot Garlic sauce, Chicken lollipops & Spring rolls served together)', 'mixed platter (prawns in butter pepper garlic sauce, chilli basa, chicken in hot garlic sauce, chicken lollipops & spring rolls served together)', 'non_veg', NULL),
    (400081002114, 400081002114, 'Seafood Platter (Whole Lobster in Green Sauce, Squids Salt n'' Pepper, Basa Chilli Dry, Prawns Rolls & Prawn in Butter Pepper Garlic sauce)', 'seafood platter (whole lobster in green sauce, squids salt n'' pepper, basa chilli dry, prawns rolls & prawn in butter pepper garlic sauce)', 'non_veg', 'SEAFOOD'),
    (400081002115, 400081002115, 'Paneer Sizzler', 'paneer sizzler', 'veg', NULL),
    (400081002116, 400081002116, 'Mix Veg. Sizzler', 'mix veg. sizzler', 'veg', NULL),
    (400081002117, 400081002117, 'Chicken Sizzler', 'chicken sizzler', 'non_veg', 'CHICKEN'),
    (400081002118, 400081002118, 'Prawns Sizzler', 'prawns sizzler', 'non_veg', 'SEAFOOD'),
    (400081002119, 400081002119, 'Mix Seafood Sizzler', 'mix seafood sizzler', 'non_veg', 'SEAFOOD'),
    (400081002120, 400081002120, 'Veg. Fried Rice', 'veg. fried rice', 'veg', NULL),
    (400081002121, 400081002121, 'Chicken Fried Rice', 'chicken fried rice', 'non_veg', 'CHICKEN'),
    (400081002122, 400081002122, 'Seafood Fried Rice', 'seafood fried rice', 'non_veg', 'SEAFOOD'),
    (400081002123, 400081002123, 'Veg. Schezwan Rice', 'veg. schezwan rice', 'veg', NULL),
    (400081002124, 400081002124, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'non_veg', 'CHICKEN'),
    (400081002125, 400081002125, 'Seafood Schezwan Rice', 'seafood schezwan rice', 'non_veg', 'SEAFOOD'),
    (400081002126, 400081002126, 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice', 'veg', NULL),
    (400081002127, 400081002127, 'Chicken Burnt Garlic Rice', 'chicken burnt garlic rice', 'non_veg', 'CHICKEN'),
    (400081002128, 400081002128, 'Seafood Burnt Garlic Rice', 'seafood burnt garlic rice', 'non_veg', 'SEAFOOD'),
    (400081002129, 400081002129, 'Veg. Combination Rice', 'veg. combination rice', 'veg', NULL),
    (400081002130, 400081002130, 'Chicken Combination Rice', 'chicken combination rice', 'non_veg', 'CHICKEN'),
    (400081002131, 400081002131, 'Seafood Combination Rice', 'seafood combination rice', 'non_veg', 'SEAFOOD'),
    (400081002132, 400081002132, 'Veg. Green Fried Rice', 'veg. green fried rice', 'veg', NULL),
    (400081002133, 400081002133, 'Chicken Green Fried Rice', 'chicken green fried rice', 'non_veg', 'CHICKEN'),
    (400081002134, 400081002134, 'Seafood Green Fried Rice', 'seafood green fried rice', 'non_veg', 'SEAFOOD'),
    (400081002135, 400081002135, 'Veg. Thai Fried Rice', 'veg. thai fried rice', 'veg', NULL),
    (400081002136, 400081002136, 'Chicken Thai Fried Rice', 'chicken thai fried rice', 'non_veg', 'CHICKEN'),
    (400081002137, 400081002137, 'Seafood Thai Fried Rice', 'seafood thai fried rice', 'non_veg', 'SEAFOOD'),
    (400081002138, 400081002138, 'Veg. Fortune Bamboo Rice', 'veg. fortune bamboo rice', 'veg', NULL),
    (400081002139, 400081002139, 'Chicken Fortune Bamboo Rice', 'chicken fortune bamboo rice', 'non_veg', 'CHICKEN'),
    (400081002140, 400081002140, 'Seafood Fortune Bamboo Rice', 'seafood fortune bamboo rice', 'non_veg', 'SEAFOOD'),
    (400081002141, 400081002141, 'Veg. Pot Rice', 'veg. pot rice', 'veg', NULL),
    (400081002142, 400081002142, 'Chicken Pot Rice', 'chicken pot rice', 'non_veg', 'CHICKEN'),
    (400081002143, 400081002143, 'Seafood Pot Rice', 'seafood pot rice', 'non_veg', 'SEAFOOD'),
    (400081002144, 400081002144, 'Veg. Triple Rice', 'veg. triple rice', 'veg', NULL),
    (400081002145, 400081002145, 'Chicken Triple Rice', 'chicken triple rice', 'non_veg', 'CHICKEN'),
    (400081002146, 400081002146, 'Seafood Triple Rice', 'seafood triple rice', 'non_veg', 'SEAFOOD'),
    (400081002147, 400081002147, 'Veg. Jewel Rice', 'veg. jewel rice', 'veg', NULL),
    (400081002148, 400081002148, 'Chicken Jewel Rice', 'chicken jewel rice', 'non_veg', 'CHICKEN'),
    (400081002149, 400081002149, 'Seafood Jewel Rice', 'seafood jewel rice', 'non_veg', 'SEAFOOD'),
    (400081002150, 400081002150, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'veg', NULL),
    (400081002151, 400081002151, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'non_veg', 'CHICKEN'),
    (400081002152, 400081002152, 'Seafood Hakka Noodles', 'seafood hakka noodles', 'non_veg', 'SEAFOOD'),
    (400081002153, 400081002153, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'veg', NULL),
    (400081002154, 400081002154, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'non_veg', 'CHICKEN'),
    (400081002155, 400081002155, 'Seafood Schezwan Noodles', 'seafood schezwan noodles', 'non_veg', 'SEAFOOD'),
    (400081002156, 400081002156, 'Veg. Burnt Garlic Noodles', 'veg. burnt garlic noodles', 'veg', NULL),
    (400081002157, 400081002157, 'Chicken Burnt Garlic Noodles', 'chicken burnt garlic noodles', 'non_veg', 'CHICKEN'),
    (400081002158, 400081002158, 'Seafood Burnt Garlic Noodles', 'seafood burnt garlic noodles', 'non_veg', 'SEAFOOD'),
    (400081002159, 400081002159, 'Veg. Pad Thai Noodles', 'veg. pad thai noodles', 'veg', NULL),
    (400081002160, 400081002160, 'Chicken Pad Thai Noodles', 'chicken pad thai noodles', 'non_veg', 'CHICKEN'),
    (400081002161, 400081002161, 'Seafood Pad Thai Noodles', 'seafood pad thai noodles', 'non_veg', 'SEAFOOD'),
    (400081002162, 400081002162, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'veg', NULL),
    (400081002163, 400081002163, 'Chicken Singapore Noodles', 'chicken singapore noodles', 'non_veg', 'CHICKEN'),
    (400081002164, 400081002164, 'Seafood Singapore Noodles', 'seafood singapore noodles', 'non_veg', 'SEAFOOD'),
    (400081002165, 400081002165, 'Veg. American Chop suey', 'veg. american chop suey', 'veg', NULL),
    (400081002166, 400081002166, 'Chicken American Chop suey', 'chicken american chop suey', 'non_veg', 'CHICKEN'),
    (400081002167, 400081002167, 'Seafood American Chop suey', 'seafood american chop suey', 'non_veg', 'SEAFOOD'),
    (400081002168, 400081002168, 'Veg. Chinese Chop suey', 'veg. chinese chop suey', 'veg', NULL),
    (400081002169, 400081002169, 'Chicken Chinese Chop suey', 'chicken chinese chop suey', 'non_veg', 'CHICKEN'),
    (400081002170, 400081002170, 'Seafood Chinese Chop suey', 'seafood chinese chop suey', 'non_veg', 'SEAFOOD'),
    (400081002171, 400081002171, 'Veg. Pan Fried Noodles', 'veg. pan fried noodles', 'veg', NULL),
    (400081002172, 400081002172, 'Chicken Pan Fried Noodles', 'chicken pan fried noodles', 'non_veg', 'CHICKEN'),
    (400081002173, 400081002173, 'Seafood Pan Fried Noodles', 'seafood pan fried noodles', 'non_veg', 'SEAFOOD'),
    (400081002174, 400081002174, 'Mix Fried Rice', 'mix fried rice', 'veg', NULL),
    (400081002175, 400081002175, 'Egg. Fried Rice', 'egg. fried rice', 'egg', 'EGG'),
    (400081002176, 400081002176, 'Steamed Rice', 'steamed rice', 'veg', NULL),
    (400081002177, 400081002177, 'Paneer Chilly Gravy', 'paneer chilly gravy', 'veg', NULL),
    (400081002178, 400081002178, 'Veg. Chilly Gravy', 'veg. chilly gravy', 'veg', NULL),
    (400081002179, 400081002179, 'Chicken Chilly Gravy', 'chicken chilly gravy', 'non_veg', 'CHICKEN'),
    (400081002180, 400081002180, 'Seafood Chilly Gravy', 'seafood chilly gravy', 'non_veg', 'SEAFOOD'),
    (400081002181, 400081002181, 'Paneer Manchurian Gravy', 'paneer manchurian gravy', 'veg', NULL),
    (400081002182, 400081002182, 'Veg. Manchurian Gravy', 'veg. manchurian gravy', 'veg', NULL),
    (400081002183, 400081002183, 'Chicken Manchurian Gravy', 'chicken manchurian gravy', 'non_veg', 'CHICKEN'),
    (400081002184, 400081002184, 'Seafood Manchurian Gravy', 'seafood manchurian gravy', 'non_veg', 'SEAFOOD'),
    (400081002185, 400081002185, 'Veg. Hot Garlic', 'veg. hot garlic', 'veg', NULL),
    (400081002186, 400081002186, 'Seafood Hot Garlic', 'seafood hot garlic', 'non_veg', 'SEAFOOD'),
    (400081002187, 400081002187, 'Seafood Butter Garlic', 'seafood butter garlic', 'non_veg', 'SEAFOOD'),
    (400081002188, 400081002188, 'Veg. Schezwan', 'veg. schezwan', 'veg', NULL),
    (400081002189, 400081002189, 'Seafood Schezwan', 'seafood schezwan', 'non_veg', 'SEAFOOD'),
    (400081002190, 400081002190, 'Veg. Hunan', 'veg. hunan', 'veg', NULL),
    (400081002191, 400081002191, 'Seafood Hunan', 'seafood hunan', 'non_veg', 'SEAFOOD'),
    (400081002192, 400081002192, 'Paneer Hoisin', 'paneer hoisin', 'veg', NULL),
    (400081002193, 400081002193, 'Veg. Hoisin', 'veg. hoisin', 'veg', NULL),
    (400081002194, 400081002194, 'Chicken Hoisin', 'chicken hoisin', 'non_veg', 'CHICKEN'),
    (400081002195, 400081002195, 'Seafood Hoisin', 'seafood hoisin', 'non_veg', 'SEAFOOD'),
    (400081002196, 400081002196, 'Seafood Oyster', 'seafood oyster', 'non_veg', 'SEAFOOD'),
    (400081002197, 400081002197, 'Paneer Shanghai', 'paneer shanghai', 'veg', NULL),
    (400081002198, 400081002198, 'Veg. Shanghai', 'veg. shanghai', 'veg', NULL),
    (400081002199, 400081002199, 'Seafood Shanghai', 'seafood shanghai', 'non_veg', 'SEAFOOD'),
    (400081002200, 400081002200, 'Paneer Red Pepper', 'paneer red pepper', 'veg', NULL),
    (400081002201, 400081002201, 'Veg. Red Pepper', 'veg. red pepper', 'veg', NULL),
    (400081002202, 400081002202, 'Chicken Red Pepper', 'chicken red pepper', 'non_veg', 'CHICKEN'),
    (400081002203, 400081002203, 'Seafood Red Pepper', 'seafood red pepper', 'non_veg', 'SEAFOOD'),
    (400081002204, 400081002204, 'Paneer Kampa Special', 'paneer kampa special', 'veg', NULL),
    (400081002205, 400081002205, 'Veg. Kampa Special', 'veg. kampa special', 'veg', NULL),
    (400081002206, 400081002206, 'Seafood Kampa Special', 'seafood kampa special', 'non_veg', 'SEAFOOD'),
    (400081002207, 400081002207, 'Paneer Chilly Bean / Black Bean Sauce', 'paneer chilly bean / black bean sauce', 'veg', NULL),
    (400081002208, 400081002208, 'Veg. Chilly Bean / Black Bean Sauce', 'veg. chilly bean / black bean sauce', 'veg', NULL),
    (400081002209, 400081002209, 'Chicken Chilly Bean / Black Bean Sauce', 'chicken chilly bean / black bean sauce', 'non_veg', 'CHICKEN'),
    (400081002210, 400081002210, 'Seafood Chilly Bean / Black Bean Sauce', 'seafood chilly bean / black bean sauce', 'non_veg', 'SEAFOOD'),
    (400081002211, 400081002211, 'Veg. Thai Green Curry', 'veg. thai green curry', 'veg', NULL),
    (400081002212, 400081002212, 'Chicken Thai Green Curry', 'chicken thai green curry', 'non_veg', 'CHICKEN'),
    (400081002213, 400081002213, 'Seafood Thai Green Curry', 'seafood thai green curry', 'non_veg', 'SEAFOOD'),
    (400081002214, 400081002214, 'Veg. Thai Red Curry', 'veg. thai red curry', 'veg', NULL),
    (400081002215, 400081002215, 'Chicken Thai Red Curry', 'chicken thai red curry', 'non_veg', 'CHICKEN'),
    (400081002216, 400081002216, 'Seafood Thai Red Curry', 'seafood thai red curry', 'non_veg', 'SEAFOOD'),
    (400081002217, 400081002217, 'Veg. Thai Massaman Curry', 'veg. thai massaman curry', 'veg', NULL),
    (400081002218, 400081002218, 'Chicken Thai Massaman Curry', 'chicken thai massaman curry', 'non_veg', 'CHICKEN'),
    (400081002219, 400081002219, 'Seafood Thai Massaman Curry', 'seafood thai massaman curry', 'non_veg', 'SEAFOOD'),
    (400081002220, 400081002220, 'Veg. Thai Penang Curry', 'veg. thai penang curry', 'veg', NULL),
    (400081002221, 400081002221, 'Chicken Thai Penang Curry', 'chicken thai penang curry', 'non_veg', 'CHICKEN'),
    (400081002222, 400081002222, 'Seafood Thai Penang Curry', 'seafood thai penang curry', 'non_veg', 'SEAFOOD'),
    (400081002223, 400081002223, 'Fresh Lime Juice', 'fresh lime juice', 'veg', NULL),
    (400081002224, 400081002224, 'Soda', 'soda', 'veg', NULL),
    (400081002225, 400081002225, 'Mineral Water', 'mineral water', 'veg', NULL),
    (400081002226, 400081002226, 'Aerated Waters', 'aerated waters', 'veg', NULL),
    (400081002227, 400081002227, 'Fried Ice Cream', 'fried ice cream', 'veg', NULL),
    (400081002228, 400081002228, 'Caramel Custard', 'caramel custard', 'veg', NULL),
    (400081002229, 400081002229, 'Honey Tossed Noodles with Ice Cream', 'honey tossed noodles with ice cream', 'veg', NULL),
    (400081002230, 400081002230, 'Schezwan Sauce', 'schezwan sauce', 'veg', NULL),
    (400081002231, 400081002231, 'Peanut Sauce', 'peanut sauce', 'veg', NULL),
    (400081002232, 400081002232, 'Any Gravy', 'any gravy', 'veg', NULL)
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
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081002001, 'SOUPS', 1), (400081002002, 'PANEER', 2), (400081002003, 'SILKEN TOFU', 3), (400081002004, 'MIX VEG.', 4), (400081002005, 'POULTRY', 5), (400081002006, 'SEAFOOD', 6), (400081002007, 'PLATTERS', 7), (400081002008, 'SIZZLERS', 8), (400081002009, 'RICE & NOODLES', 9), (400081002010, 'MAIN COURSE', 10), (400081002011, 'COOLERS', 11), (400081002012, 'DESSERTS', 12), (400081002013, 'EXTRAS', 13)) AS x(menu_category_id, name, display_sequence);

-- =============================================================================
-- Menu items (246 priced)
-- =============================================================================

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002001, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Manchow Soup', 'manchow soup', 'SOUPS', 'veg', 'split-manchow-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'manchow soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002001, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002002, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Manchow Soup', 'chicken manchow soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-manchow-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchow soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002002, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002003, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Manchow Soup', 'seafood manchow soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-manchow-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood manchow soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002003, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002004, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Sweet Corn Soup', 'sweet corn soup', 'SOUPS', 'veg', 'split-sweet-corn-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet corn soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002004, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002005, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Sweet Corn Soup', 'chicken sweet corn soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-sweet-corn-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sweet corn soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002005, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002006, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Sweet Corn Soup', 'seafood sweet corn soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-sweet-corn-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood sweet corn soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002006, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002007, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Hot ''n'' Sour Soup', 'hot ''n'' sour soup', 'SOUPS', 'veg', 'split-hot-n-sour-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot ''n'' sour soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002007, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002008, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Hot ''n'' Sour Soup', 'chicken hot ''n'' sour soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-hot-n-sour-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hot ''n'' sour soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002008, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002009, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Hot ''n'' Sour Soup', 'seafood hot ''n'' sour soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-hot-n-sour-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood hot ''n'' sour soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002009, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002010, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Burnt Garlic Soup', 'burnt garlic soup', 'SOUPS', 'veg', 'split-burnt-garlic-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'burnt garlic soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002010, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002011, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Burnt Garlic Soup', 'chicken burnt garlic soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-burnt-garlic-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken burnt garlic soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002011, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002012, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Burnt Garlic Soup', 'seafood burnt garlic soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-burnt-garlic-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood burnt garlic soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002012, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002013, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Oriental Soup', 'oriental soup', 'SOUPS', 'veg', 'split-oriental-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'oriental soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002013, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002014, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Oriental Soup', 'chicken oriental soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-oriental-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken oriental soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002014, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002015, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Oriental Soup', 'seafood oriental soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-oriental-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood oriental soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002015, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002016, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Laksa', 'laksa', 'SOUPS', 'veg', 'split-laksa', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'laksa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002016, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002017, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Laksa', 'chicken laksa', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-laksa', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken laksa' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002017, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002018, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Laksa', 'seafood laksa', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-laksa', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood laksa' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002018, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002019, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Peppery Lemon Soup', 'peppery lemon soup', 'SOUPS', 'veg', 'split-peppery-lemon-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peppery lemon soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002019, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002020, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Peppery Lemon Soup', 'chicken peppery lemon soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-peppery-lemon-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken peppery lemon soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002020, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002021, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Peppery Lemon Soup', 'seafood peppery lemon soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-peppery-lemon-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood peppery lemon soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002021, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002022, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Lemon Coriander Soup', 'lemon coriander soup', 'SOUPS', 'veg', 'split-lemon-coriander-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lemon coriander soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002022, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002023, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Lemon Coriander Soup', 'chicken lemon coriander soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-lemon-coriander-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lemon coriander soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002023, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002024, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Lemon Coriander Soup', 'seafood lemon coriander soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-lemon-coriander-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood lemon coriander soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002024, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002025, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Wonton Soup', 'wonton soup', 'SOUPS', 'veg', 'split-wonton-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'wonton soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002025, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002026, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Wonton Soup', 'chicken wonton soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-wonton-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken wonton soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002026, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002027, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Wonton Soup', 'seafood wonton soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-wonton-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood wonton soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002027, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002028, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Lung Fung Soup', 'chicken lung fung soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-lung-fung-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lung fung soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002028, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002029, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Lung Fung Soup', 'seafood lung fung soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-lung-fung-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood lung fung soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002029, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002030, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Tom Yum', 'tom yum', 'SOUPS', 'veg', 'split-tom-yum', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tom yum'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002030, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002031, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Tom Yum', 'chicken tom yum', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-tom-yum', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tom yum' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002031, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002032, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Tom Yum', 'seafood tom yum', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-tom-yum', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood tom yum' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002032, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002033, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Tom Kha Gaa', 'chicken tom kha gaa', 'SOUPS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tom kha gaa' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002033, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002034, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Tom Kha Koong', 'seafood tom kha koong', 'SOUPS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood tom kha koong' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002034, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002035, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Talumein Soup', 'talumein soup', 'SOUPS', 'veg', 'split-talumein-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'talumein soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002035, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002036, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Talumein Soup', 'chicken talumein soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-talumein-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken talumein soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002036, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002037, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Talumein Soup', 'seafood talumein soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-talumein-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood talumein soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002037, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002038, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Crispy Rice Soup', 'crispy rice soup', 'SOUPS', 'veg', 'split-crispy-rice-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'crispy rice soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002038, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002039, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Crispy Rice Soup', 'chicken crispy rice soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-crispy-rice-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken crispy rice soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002039, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002040, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Crispy Rice Soup', 'seafood crispy rice soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-crispy-rice-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood crispy rice soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002040, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002041, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Spicy Tomato Soup', 'chicken spicy tomato soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-spicy-tomato-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken spicy tomato soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002041, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002042, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Seafood Spicy Tomato Soup', 'seafood spicy tomato soup', 'SOUPS', 'non_veg', pt.protein_type_id, 'split-spicy-tomato-soup', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood spicy tomato soup' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002042, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002043, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002001, 'Chicken Meat Ball Soup with Silky Noodles', 'chicken meat ball soup with silky noodles', 'SOUPS', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken meat ball soup with silky noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002043, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.65, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.60 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002044, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Chilly', 'paneer chilly', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002044, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002045, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Manchurian Dry', 'paneer manchurian dry', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian dry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002045, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002046, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Hot Garlic', 'paneer hot garlic', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002046, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002047, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Schezwan', 'paneer schezwan', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002047, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002048, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Satay', 'paneer satay', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer satay'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002048, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002049, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Oyster', 'paneer oyster', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer oyster'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002049, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002050, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Salt ''n'' Pepper', 'paneer salt ''n'' pepper', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer salt ''n'' pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002050, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002051, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Hunan', 'paneer hunan', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002051, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002052, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Taichin', 'paneer taichin', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer taichin'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002052, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002053, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Black Bean', 'paneer black bean', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer black bean'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002053, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002054, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Chilly Bean', 'paneer chilly bean', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly bean'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002054, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002055, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Butter Garlic', 'paneer butter garlic', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002055, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002056, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Paneer Kungpao', 'paneer kungpao', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kungpao'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002056, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PANEER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002057, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002002, 'Crispy Threaded Paneer', 'crispy threaded paneer', 'PANEER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'crispy threaded paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002057, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SILKEN TOFU" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002058, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002003, 'Silken Tofu Black Bean', 'silken tofu black bean', 'SILKEN TOFU', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'silken tofu black bean'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002058, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SILKEN TOFU" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002059, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002003, 'Silken Tofu Chilly Bean', 'silken tofu chilly bean', 'SILKEN TOFU', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'silken tofu chilly bean'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002059, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SILKEN TOFU" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002060, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002003, 'Silken Tofu Hunan', 'silken tofu hunan', 'SILKEN TOFU', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'silken tofu hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002060, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SILKEN TOFU" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002061, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002003, 'Silken Tofu Taichin', 'silken tofu taichin', 'SILKEN TOFU', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'silken tofu taichin'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002061, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002062, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Manchurian', 'veg. manchurian', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002062, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002063, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Spring Roll', 'veg. spring roll', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002063, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002064, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Wonton', 'veg. wonton', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. wonton'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002064, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002065, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Crispy', 'veg. crispy', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002065, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002066, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Oyster', 'veg. oyster', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. oyster'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002066, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002067, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Stir Fry Chinese Greens', 'veg. stir fry chinese greens', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. stir fry chinese greens'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002067, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002068, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Baby Corn Chilly', 'baby corn chilly', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002068, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002069, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Mushroom Chilly', 'mushroom chilly', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002069, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002070, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Chilly Potatoes', 'chilly potatoes', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chilly potatoes'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002070, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002071, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Golden Fried Baby Corn', 'golden fried baby corn', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'golden fried baby corn'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002071, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002072, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Green Sauce', 'veg. green sauce', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. green sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002072, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002073, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Butter Garlic', 'veg. butter garlic', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002073, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002074, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Baby Corn Mushroom Salt ''n'' Pepper', 'baby corn mushroom salt ''n'' pepper', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn mushroom salt ''n'' pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002074, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MIX VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002075, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002004, 'Veg. Dim Sum', 'veg. dim sum', 'MIX VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. dim sum'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002075, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002076, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Wonton', 'chicken wonton', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken wonton' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002076, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002077, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Lollypop', 'chicken lollypop', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lollypop' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002077, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002078, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Spring Roll', 'chicken spring roll', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken spring roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002078, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002079, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Dim Sum', 'chicken dim sum', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken dim sum' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002079, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002080, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Hot Garlic', 'chicken hot garlic', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hot garlic' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002080, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002081, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Lemon Garlic', 'chicken lemon garlic', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lemon garlic' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002081, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002082, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Schezwan', 'chicken schezwan', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002082, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002083, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Manchurian', 'chicken manchurian', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002083, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002084, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Crispy', 'chicken crispy', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken crispy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002084, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002085, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Chilly', 'chicken chilly', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilly' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002085, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002086, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Mongolian', 'chicken mongolian', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken mongolian' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002086, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002087, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Satay', 'chicken satay', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken satay' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002087, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002088, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Malaysian', 'chicken malaysian', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken malaysian' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002088, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002089, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Kampa Special', 'chicken kampa special', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kampa special' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002089, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002090, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Taronest', 'chicken taronest', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken taronest' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002090, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002091, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Oyster', 'chicken oyster', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken oyster' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002091, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002092, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Cilantro', 'chicken cilantro', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cilantro' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002092, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002093, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Taichin', 'chicken taichin', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken taichin' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002093, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002094, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Kungpao', 'chicken kungpao', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kungpao' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002094, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002095, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Shanghai', 'chicken shanghai', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken shanghai' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002095, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002096, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Mustard', 'chicken mustard', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken mustard' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002096, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002097, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Black Bean', 'chicken black bean', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken black bean' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002097, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002098, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Chilly Bean', 'chicken chilly bean', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilly bean' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002098, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002099, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Red Cooked', 'chicken red cooked', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken red cooked' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002099, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002100, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Hunan', 'chicken hunan', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hunan' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002100, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002101, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Chicken Butter Garlic', 'chicken butter garlic', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken butter garlic' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002101, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "POULTRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002102, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002005, 'Roast Chicken Wings in Bbq Sauce', 'roast chicken wings in bbq sauce', 'POULTRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'roast chicken wings in bbq sauce' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002102, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002103, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Fire Cracker Prawns (6 Pcs.)', 'fire cracker prawns (6 pcs.)', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fire cracker prawns (6 pcs.)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002103, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002104, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Golden Fried Prawns (Medn Prawns 8 Pcs.)', 'golden fried prawns (medn prawns 8 pcs.)', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'golden fried prawns (medn prawns 8 pcs.)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002104, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002105, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Squids Salt ''n'' Pepper', 'squids salt ''n'' pepper', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'squids salt ''n'' pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002105, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002106, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Medium Prawns', 'medium prawns', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'medium prawns' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002106, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002107, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Jumbo Prawns (4 Pcs.)', 'jumbo prawns (4 pcs.)', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'jumbo prawns (4 pcs.)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002107, new_variant.variant_id, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002108, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Rawas', 'rawas', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'rawas' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002108, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002109, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Squids', 'squids', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'squids' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002109, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002110, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002006, 'Pomfret', 'pomfret', 'SEAFOOD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pomfret' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002110, new_variant.variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PLATTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002111, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002007, 'Veg. Chinese Platter (Crispy Veg., Paneer Butter Garlic, Veg. Spring Roll, Potato Chilly, Veg. Manchurian)', 'veg. chinese platter (crispy veg., paneer butter garlic, veg. spring roll, potato chilly, veg. manchurian)', 'PLATTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chinese platter (crispy veg., paneer butter garlic, veg. spring roll, potato chilly, veg. manchurian)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002111, new_variant.variant_id, 850.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PLATTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002112, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002007, 'Chicken Platter (Lollypop, Spring Roll, Crispy Chicken, Chicken Chilly, Chicken Hunan)', 'chicken platter (lollypop, spring roll, crispy chicken, chicken chilly, chicken hunan)', 'PLATTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken platter (lollypop, spring roll, crispy chicken, chicken chilly, chicken hunan)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002112, new_variant.variant_id, 1050.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "PLATTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002113, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002007, 'Mixed Platter (Prawns in Butter Pepper Garlic sauce, Chilli Basa, Chicken in Hot Garlic sauce, Chicken lollipops & Spring rolls served together)', 'mixed platter (prawns in butter pepper garlic sauce, chilli basa, chicken in hot garlic sauce, chicken lollipops & spring rolls served together)', 'PLATTERS', 'non_veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mixed platter (prawns in butter pepper garlic sauce, chilli basa, chicken in hot garlic sauce, chicken lollipops & spring rolls served together)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002113, new_variant.variant_id, 1600.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "PLATTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002114, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002007, 'Seafood Platter (Whole Lobster in Green Sauce, Squids Salt n'' Pepper, Basa Chilli Dry, Prawns Rolls & Prawn in Butter Pepper Garlic sauce)', 'seafood platter (whole lobster in green sauce, squids salt n'' pepper, basa chilli dry, prawns rolls & prawn in butter pepper garlic sauce)', 'PLATTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood platter (whole lobster in green sauce, squids salt n'' pepper, basa chilli dry, prawns rolls & prawn in butter pepper garlic sauce)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002114, new_variant.variant_id, 2400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002115, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002008, 'Paneer Sizzler', 'paneer sizzler', 'SIZZLERS', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer sizzler'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002115, new_variant.variant_id, 675.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002116, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002008, 'Mix Veg. Sizzler', 'mix veg. sizzler', 'SIZZLERS', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix veg. sizzler'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002116, new_variant.variant_id, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002117, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002008, 'Chicken Sizzler', 'chicken sizzler', 'SIZZLERS', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sizzler' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002117, new_variant.variant_id, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002118, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002008, 'Prawns Sizzler', 'prawns sizzler', 'SIZZLERS', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns sizzler' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002118, new_variant.variant_id, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002119, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002008, 'Mix Seafood Sizzler', 'mix seafood sizzler', 'SIZZLERS', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mix seafood sizzler' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002119, new_variant.variant_id, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002120, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Fried Rice', 'veg. fried rice', 'RICE & NOODLES', 'veg', 'split-fried-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002120, new_variant.variant_id, 315.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002121, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Fried Rice', 'chicken fried rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-fried-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken fried rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002121, new_variant.variant_id, 335.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002122, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Fried Rice', 'seafood fried rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-fried-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood fried rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002122, new_variant.variant_id, 355.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002123, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Schezwan Rice', 'veg. schezwan rice', 'RICE & NOODLES', 'veg', 'split-schezwan-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002123, new_variant.variant_id, 315.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002124, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-schezwan-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002124, new_variant.variant_id, 335.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002125, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Schezwan Rice', 'seafood schezwan rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-schezwan-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood schezwan rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002125, new_variant.variant_id, 355.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002126, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice', 'RICE & NOODLES', 'veg', 'split-burnt-garlic-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. burnt garlic rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002126, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002127, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Burnt Garlic Rice', 'chicken burnt garlic rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-burnt-garlic-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken burnt garlic rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002127, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002128, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Burnt Garlic Rice', 'seafood burnt garlic rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-burnt-garlic-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood burnt garlic rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002128, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002129, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Combination Rice', 'veg. combination rice', 'RICE & NOODLES', 'veg', 'split-combination-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. combination rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002129, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002130, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Combination Rice', 'chicken combination rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-combination-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken combination rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002130, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002131, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Combination Rice', 'seafood combination rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-combination-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood combination rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002131, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002132, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Green Fried Rice', 'veg. green fried rice', 'RICE & NOODLES', 'veg', 'split-green-fried-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. green fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002132, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002133, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Green Fried Rice', 'chicken green fried rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-green-fried-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken green fried rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002133, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002134, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Green Fried Rice', 'seafood green fried rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-green-fried-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood green fried rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002134, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002135, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Thai Fried Rice', 'veg. thai fried rice', 'RICE & NOODLES', 'veg', 'split-thai-fried-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. thai fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002135, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002136, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Thai Fried Rice', 'chicken thai fried rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-thai-fried-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken thai fried rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002136, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002137, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Thai Fried Rice', 'seafood thai fried rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-thai-fried-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood thai fried rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002137, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002138, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Fortune Bamboo Rice', 'veg. fortune bamboo rice', 'RICE & NOODLES', 'veg', 'split-fortune-bamboo-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fortune bamboo rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002138, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002139, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Fortune Bamboo Rice', 'chicken fortune bamboo rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-fortune-bamboo-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken fortune bamboo rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002139, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002140, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Fortune Bamboo Rice', 'seafood fortune bamboo rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-fortune-bamboo-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood fortune bamboo rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002140, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002141, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Pot Rice', 'veg. pot rice', 'RICE & NOODLES', 'veg', 'split-pot-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pot rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002141, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002142, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Pot Rice', 'chicken pot rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-pot-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pot rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002142, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002143, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Pot Rice', 'seafood pot rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-pot-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood pot rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002143, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002144, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Triple Rice', 'veg. triple rice', 'RICE & NOODLES', 'veg', 'split-triple-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. triple rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002144, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002145, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Triple Rice', 'chicken triple rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-triple-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken triple rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002145, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002146, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Triple Rice', 'seafood triple rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-triple-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood triple rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002146, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002147, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Jewel Rice', 'veg. jewel rice', 'RICE & NOODLES', 'veg', 'split-jewel-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. jewel rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002147, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002148, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Jewel Rice', 'chicken jewel rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-jewel-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken jewel rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002148, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002149, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Jewel Rice', 'seafood jewel rice', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-jewel-rice', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood jewel rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002149, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002149, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002150, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'RICE & NOODLES', 'veg', 'split-hakka-noodles', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hakka noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002150, new_variant.variant_id, 315.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002151, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-hakka-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hakka noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002151, new_variant.variant_id, 335.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002152, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Hakka Noodles', 'seafood hakka noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-hakka-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood hakka noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002152, new_variant.variant_id, 355.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002153, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'RICE & NOODLES', 'veg', 'split-schezwan-noodles', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002153, new_variant.variant_id, 315.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002154, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-schezwan-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002154, new_variant.variant_id, 335.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002155, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Schezwan Noodles', 'seafood schezwan noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-schezwan-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood schezwan noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002155, new_variant.variant_id, 355.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002156, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Burnt Garlic Noodles', 'veg. burnt garlic noodles', 'RICE & NOODLES', 'veg', 'split-burnt-garlic-noodles', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. burnt garlic noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002156, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002157, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Burnt Garlic Noodles', 'chicken burnt garlic noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-burnt-garlic-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken burnt garlic noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002157, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002158, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Burnt Garlic Noodles', 'seafood burnt garlic noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-burnt-garlic-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood burnt garlic noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002158, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002159, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Pad Thai Noodles', 'veg. pad thai noodles', 'RICE & NOODLES', 'veg', 'split-pad-thai-noodles', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pad thai noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002159, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002160, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Pad Thai Noodles', 'chicken pad thai noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-pad-thai-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pad thai noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002160, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002161, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Pad Thai Noodles', 'seafood pad thai noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-pad-thai-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood pad thai noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002161, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002162, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'RICE & NOODLES', 'veg', 'split-singapore-noodles', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. singapore noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002162, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002163, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Singapore Noodles', 'chicken singapore noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-singapore-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken singapore noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002163, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002164, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Singapore Noodles', 'seafood singapore noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-singapore-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood singapore noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002164, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002165, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. American Chop suey', 'veg. american chop suey', 'RICE & NOODLES', 'veg', 'split-american-chop-suey', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. american chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002165, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002166, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken American Chop suey', 'chicken american chop suey', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-american-chop-suey', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken american chop suey' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002166, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002167, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood American Chop suey', 'seafood american chop suey', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-american-chop-suey', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood american chop suey' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002167, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002168, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Chinese Chop suey', 'veg. chinese chop suey', 'RICE & NOODLES', 'veg', 'split-chinese-chop-suey', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chinese chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002168, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002169, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Chinese Chop suey', 'chicken chinese chop suey', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-chinese-chop-suey', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chinese chop suey' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002169, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002170, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Chinese Chop suey', 'seafood chinese chop suey', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-chinese-chop-suey', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood chinese chop suey' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002170, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002171, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Veg. Pan Fried Noodles', 'veg. pan fried noodles', 'RICE & NOODLES', 'veg', 'split-pan-fried-noodles', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pan fried noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002171, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002172, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Chicken Pan Fried Noodles', 'chicken pan fried noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-pan-fried-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pan fried noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002172, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002173, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Seafood Pan Fried Noodles', 'seafood pan fried noodles', 'RICE & NOODLES', 'non_veg', pt.protein_type_id, 'split-pan-fried-noodles', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood pan fried noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002173, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002174, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Mix Fried Rice', 'mix fried rice', 'RICE & NOODLES', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002174, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081002175, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Egg. Fried Rice', 'egg. fried rice', 'RICE & NOODLES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg. fried rice' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002175, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE & NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081002176, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002009, 'Steamed Rice', 'steamed rice', 'RICE & NOODLES', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steamed rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081002176, 'Half', FALSE), (400081002177, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081002176, 'Half', 180.00, FALSE), (400081002177, 'Full', 315.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.65, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.65 FROM new_prices, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002177, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Chilly Gravy', 'paneer chilly gravy', 'MAIN COURSE', 'veg', 'split-mc-chilly-gravy', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002178, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002178, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Chilly Gravy', 'veg. chilly gravy', 'MAIN COURSE', 'veg', 'split-mc-chilly-gravy', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilly gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002179, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002179, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002179, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Chilly Gravy', 'chicken chilly gravy', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-chilly-gravy', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilly gravy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002180, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002180, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Chilly Gravy', 'seafood chilly gravy', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-chilly-gravy', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood chilly gravy' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002181, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002181, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Manchurian Gravy', 'paneer manchurian gravy', 'MAIN COURSE', 'veg', 'split-mc-manchurian-gravy', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002182, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002182, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Manchurian Gravy', 'veg. manchurian gravy', 'MAIN COURSE', 'veg', 'split-mc-manchurian-gravy', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchurian gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002183, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002183, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Manchurian Gravy', 'chicken manchurian gravy', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-manchurian-gravy', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian gravy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002184, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002184, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Manchurian Gravy', 'seafood manchurian gravy', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-manchurian-gravy', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood manchurian gravy' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002185, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002185, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Hot Garlic', 'paneer hot garlic', 'MAIN COURSE', 'veg', 'split-mc-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002186, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002186, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Hot Garlic', 'veg. hot garlic', 'MAIN COURSE', 'veg', 'split-mc-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002187, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002187, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Hot Garlic', 'chicken hot garlic', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hot garlic' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002188, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002188, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Hot Garlic', 'seafood hot garlic', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood hot garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002189, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002189, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Butter Garlic', 'paneer butter garlic', 'MAIN COURSE', 'veg', 'split-mc-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002190, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002190, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Butter Garlic', 'veg. butter garlic', 'MAIN COURSE', 'veg', 'split-mc-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002191, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002191, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Butter Garlic', 'chicken butter garlic', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken butter garlic' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002192, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002192, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Butter Garlic', 'seafood butter garlic', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood butter garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002193, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002193, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Schezwan', 'paneer schezwan', 'MAIN COURSE', 'veg', 'split-mc-schezwan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002194, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002194, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Schezwan', 'veg. schezwan', 'MAIN COURSE', 'veg', 'split-mc-schezwan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002195, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002195, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Schezwan', 'chicken schezwan', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-schezwan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002196, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002196, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Schezwan', 'seafood schezwan', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-schezwan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood schezwan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002197, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002197, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Hunan', 'paneer hunan', 'MAIN COURSE', 'veg', 'split-mc-hunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002198, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002198, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Hunan', 'veg. hunan', 'MAIN COURSE', 'veg', 'split-mc-hunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002199, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002199, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Hunan', 'chicken hunan', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-hunan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hunan' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002200, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002200, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Hunan', 'seafood hunan', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-hunan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood hunan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002201, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002201, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Hoisin', 'paneer hoisin', 'MAIN COURSE', 'veg', 'split-mc-hoisin', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hoisin'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002202, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002202, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Hoisin', 'veg. hoisin', 'MAIN COURSE', 'veg', 'split-mc-hoisin', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hoisin'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002203, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002203, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Hoisin', 'chicken hoisin', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-hoisin', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hoisin' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002204, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002204, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Hoisin', 'seafood hoisin', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-hoisin', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood hoisin' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002205, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002205, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Oyster', 'paneer oyster', 'MAIN COURSE', 'veg', 'split-mc-oyster', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer oyster'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002206, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002206, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Oyster', 'veg. oyster', 'MAIN COURSE', 'veg', 'split-mc-oyster', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. oyster'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002207, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002207, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Oyster', 'chicken oyster', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-oyster', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken oyster' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002208, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002208, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Oyster', 'seafood oyster', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-oyster', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood oyster' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002209, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002209, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Shanghai', 'paneer shanghai', 'MAIN COURSE', 'veg', 'split-mc-shanghai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer shanghai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002210, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002210, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Shanghai', 'veg. shanghai', 'MAIN COURSE', 'veg', 'split-mc-shanghai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. shanghai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002211, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002211, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Shanghai', 'chicken shanghai', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-shanghai', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken shanghai' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002212, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002212, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Shanghai', 'seafood shanghai', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-shanghai', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood shanghai' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002213, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002213, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Red Pepper', 'paneer red pepper', 'MAIN COURSE', 'veg', 'split-mc-red-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer red pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002214, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002214, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Red Pepper', 'veg. red pepper', 'MAIN COURSE', 'veg', 'split-mc-red-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. red pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002215, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002215, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Red Pepper', 'chicken red pepper', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-red-pepper', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken red pepper' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002216, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002216, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Red Pepper', 'seafood red pepper', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-red-pepper', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood red pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002217, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002217, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Kampa Special', 'paneer kampa special', 'MAIN COURSE', 'veg', 'split-mc-kampa-special', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kampa special'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002218, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002218, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Kampa Special', 'veg. kampa special', 'MAIN COURSE', 'veg', 'split-mc-kampa-special', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kampa special'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002219, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002219, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Kampa Special', 'chicken kampa special', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-kampa-special', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kampa special' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002220, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002220, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Kampa Special', 'seafood kampa special', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-kampa-special', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood kampa special' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002221, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002221, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Paneer Chilly Bean / Black Bean Sauce', 'paneer chilly bean / black bean sauce', 'MAIN COURSE', 'veg', 'split-mc-chilly-bean---black-bean-sauce', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly bean / black bean sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002222, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002222, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Chilly Bean / Black Bean Sauce', 'veg. chilly bean / black bean sauce', 'MAIN COURSE', 'veg', 'split-mc-chilly-bean---black-bean-sauce', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilly bean / black bean sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002223, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002223, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Chilly Bean / Black Bean Sauce', 'chicken chilly bean / black bean sauce', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-chilly-bean---black-bean-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilly bean / black bean sauce' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002224, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002224, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Chilly Bean / Black Bean Sauce', 'seafood chilly bean / black bean sauce', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-chilly-bean---black-bean-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood chilly bean / black bean sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002225, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002225, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Thai Green Curry', 'veg. thai green curry', 'MAIN COURSE', 'veg', 'split-mc-thai-green-curry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. thai green curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002226, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002226, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Thai Green Curry', 'chicken thai green curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-green-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken thai green curry' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002227, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002227, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Thai Green Curry', 'seafood thai green curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-green-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood thai green curry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002228, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002228, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Thai Red Curry', 'veg. thai red curry', 'MAIN COURSE', 'veg', 'split-mc-thai-red-curry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. thai red curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002229, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002229, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Thai Red Curry', 'chicken thai red curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-red-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken thai red curry' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002230, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002230, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Thai Red Curry', 'seafood thai red curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-red-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood thai red curry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002231, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002231, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Thai Massaman Curry', 'veg. thai massaman curry', 'MAIN COURSE', 'veg', 'split-mc-thai-massaman-curry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. thai massaman curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002232, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002232, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Thai Massaman Curry', 'chicken thai massaman curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-massaman-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken thai massaman curry' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002233, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002233, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Thai Massaman Curry', 'seafood thai massaman curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-massaman-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood thai massaman curry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002234, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081002234, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Veg. Thai Penang Curry', 'veg. thai penang curry', 'MAIN COURSE', 'veg', 'split-mc-thai-penang-curry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. thai penang curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002235, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002235, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Chicken Thai Penang Curry', 'chicken thai penang curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-penang-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken thai penang curry' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002236, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400081002236, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002010, 'Seafood Thai Penang Curry', 'seafood thai penang curry', 'MAIN COURSE', 'non_veg', pt.protein_type_id, 'split-mc-thai-penang-curry', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'seafood thai penang curry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002237, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002237, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002011, 'Fresh Lime Juice', 'fresh lime juice', 'COOLERS', 'veg', 'split-fresh-lime-juice-soda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fresh lime juice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002238, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002238, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002011, 'Soda', 'soda', 'COOLERS', 'veg', 'split-fresh-lime-juice-soda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002239, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002239, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002011, 'Mineral Water', 'mineral water', 'COOLERS', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mineral water'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081002240, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
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
  SELECT 400081002240, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002011, 'Aerated Waters', 'aerated waters', 'COOLERS', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aerated waters'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081002241, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
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
  SELECT 400081002241, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002012, 'Fried Ice Cream', 'fried ice cream', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fried ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002242, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002242, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002012, 'Caramel Custard', 'caramel custard', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'caramel custard'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002243, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002243, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002012, 'Honey Tossed Noodles with Ice Cream', 'honey tossed noodles with ice cream', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'honey tossed noodles with ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002244, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002244, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002013, 'Schezwan Sauce', 'schezwan sauce', 'EXTRAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002245, new_variant.variant_id, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002245, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002013, 'Peanut Sauce', 'peanut sauce', 'EXTRAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peanut sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002246, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081002246, ctx.restaurant_id, item_cd.canonical_dish_id, 400081002013, 'Any Gravy', 'any gravy', 'EXTRAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'any gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081002247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081002247, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- -----------------------------------------------------------------------
-- One menu board per restaurant, linked to every category and every item.
-- board_type_code = 'a_la_carte': none of this batch's sources describe a
-- buffet/thali/combo-style board, just a standard printed menu.
-- -----------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 400081002001, ctx.restaurant_id, 'Main Menu', 'a_la_carte' FROM khaustan_onboarding_ctx ctx;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT ctx.restaurant_id, 400081002001, x.menu_category_id, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081002001, 1), (400081002002, 2), (400081002003, 3), (400081002004, 4), (400081002005, 5), (400081002006, 6), (400081002007, 7), (400081002008, 8), (400081002009, 9), (400081002010, 10), (400081002011, 11), (400081002012, 12), (400081002013, 13)) AS x(menu_category_id, display_sequence);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence, is_featured)
SELECT x.menu_board_item_id, ctx.restaurant_id, 400081002001, x.menu_item_id, x.menu_category_id, x.display_sequence, x.is_featured
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081002001, 400081002001, 400081002001, 1, FALSE), (400081002002, 400081002002, 400081002001, 2, FALSE), (400081002003, 400081002003, 400081002001, 3, FALSE), (400081002004, 400081002004, 400081002001, 4, FALSE), (400081002005, 400081002005, 400081002001, 5, FALSE), (400081002006, 400081002006, 400081002001, 6, FALSE), (400081002007, 400081002007, 400081002001, 7, FALSE), (400081002008, 400081002008, 400081002001, 8, FALSE), (400081002009, 400081002009, 400081002001, 9, FALSE), (400081002010, 400081002010, 400081002001, 10, FALSE), (400081002011, 400081002011, 400081002001, 11, FALSE), (400081002012, 400081002012, 400081002001, 12, FALSE), (400081002013, 400081002013, 400081002001, 13, FALSE), (400081002014, 400081002014, 400081002001, 14, FALSE), (400081002015, 400081002015, 400081002001, 15, FALSE), (400081002016, 400081002016, 400081002001, 16, FALSE), (400081002017, 400081002017, 400081002001, 17, FALSE), (400081002018, 400081002018, 400081002001, 18, FALSE), (400081002019, 400081002019, 400081002001, 19, FALSE), (400081002020, 400081002020, 400081002001, 20, FALSE), (400081002021, 400081002021, 400081002001, 21, FALSE), (400081002022, 400081002022, 400081002001, 22, FALSE), (400081002023, 400081002023, 400081002001, 23, FALSE), (400081002024, 400081002024, 400081002001, 24, FALSE), (400081002025, 400081002025, 400081002001, 25, FALSE), (400081002026, 400081002026, 400081002001, 26, FALSE), (400081002027, 400081002027, 400081002001, 27, FALSE), (400081002028, 400081002028, 400081002001, 28, FALSE), (400081002029, 400081002029, 400081002001, 29, FALSE), (400081002030, 400081002030, 400081002001, 30, FALSE), (400081002031, 400081002031, 400081002001, 31, FALSE), (400081002032, 400081002032, 400081002001, 32, FALSE), (400081002033, 400081002033, 400081002001, 33, FALSE), (400081002034, 400081002034, 400081002001, 34, FALSE), (400081002035, 400081002035, 400081002001, 35, FALSE), (400081002036, 400081002036, 400081002001, 36, FALSE), (400081002037, 400081002037, 400081002001, 37, FALSE), (400081002038, 400081002038, 400081002001, 38, FALSE), (400081002039, 400081002039, 400081002001, 39, FALSE), (400081002040, 400081002040, 400081002001, 40, FALSE), (400081002041, 400081002041, 400081002001, 41, FALSE), (400081002042, 400081002042, 400081002001, 42, FALSE), (400081002043, 400081002043, 400081002001, 43, FALSE), (400081002044, 400081002044, 400081002002, 44, FALSE), (400081002045, 400081002045, 400081002002, 45, FALSE), (400081002046, 400081002046, 400081002002, 46, FALSE), (400081002047, 400081002047, 400081002002, 47, FALSE), (400081002048, 400081002048, 400081002002, 48, FALSE), (400081002049, 400081002049, 400081002002, 49, FALSE), (400081002050, 400081002050, 400081002002, 50, FALSE), (400081002051, 400081002051, 400081002002, 51, FALSE), (400081002052, 400081002052, 400081002002, 52, FALSE), (400081002053, 400081002053, 400081002002, 53, FALSE), (400081002054, 400081002054, 400081002002, 54, FALSE), (400081002055, 400081002055, 400081002002, 55, FALSE), (400081002056, 400081002056, 400081002002, 56, FALSE), (400081002057, 400081002057, 400081002002, 57, FALSE), (400081002058, 400081002058, 400081002003, 58, FALSE), (400081002059, 400081002059, 400081002003, 59, FALSE), (400081002060, 400081002060, 400081002003, 60, FALSE), (400081002061, 400081002061, 400081002003, 61, FALSE), (400081002062, 400081002062, 400081002004, 62, FALSE), (400081002063, 400081002063, 400081002004, 63, FALSE), (400081002064, 400081002064, 400081002004, 64, FALSE), (400081002065, 400081002065, 400081002004, 65, FALSE), (400081002066, 400081002066, 400081002004, 66, FALSE), (400081002067, 400081002067, 400081002004, 67, FALSE), (400081002068, 400081002068, 400081002004, 68, FALSE), (400081002069, 400081002069, 400081002004, 69, FALSE), (400081002070, 400081002070, 400081002004, 70, FALSE), (400081002071, 400081002071, 400081002004, 71, FALSE), (400081002072, 400081002072, 400081002004, 72, FALSE), (400081002073, 400081002073, 400081002004, 73, FALSE), (400081002074, 400081002074, 400081002004, 74, FALSE), (400081002075, 400081002075, 400081002004, 75, FALSE), (400081002076, 400081002076, 400081002005, 76, FALSE), (400081002077, 400081002077, 400081002005, 77, FALSE), (400081002078, 400081002078, 400081002005, 78, FALSE), (400081002079, 400081002079, 400081002005, 79, FALSE), (400081002080, 400081002080, 400081002005, 80, FALSE), (400081002081, 400081002081, 400081002005, 81, FALSE), (400081002082, 400081002082, 400081002005, 82, FALSE), (400081002083, 400081002083, 400081002005, 83, FALSE), (400081002084, 400081002084, 400081002005, 84, FALSE), (400081002085, 400081002085, 400081002005, 85, FALSE), (400081002086, 400081002086, 400081002005, 86, FALSE), (400081002087, 400081002087, 400081002005, 87, FALSE), (400081002088, 400081002088, 400081002005, 88, FALSE), (400081002089, 400081002089, 400081002005, 89, FALSE), (400081002090, 400081002090, 400081002005, 90, FALSE), (400081002091, 400081002091, 400081002005, 91, FALSE), (400081002092, 400081002092, 400081002005, 92, FALSE), (400081002093, 400081002093, 400081002005, 93, FALSE), (400081002094, 400081002094, 400081002005, 94, FALSE), (400081002095, 400081002095, 400081002005, 95, FALSE), (400081002096, 400081002096, 400081002005, 96, FALSE), (400081002097, 400081002097, 400081002005, 97, FALSE), (400081002098, 400081002098, 400081002005, 98, FALSE), (400081002099, 400081002099, 400081002005, 99, FALSE), (400081002100, 400081002100, 400081002005, 100, FALSE), (400081002101, 400081002101, 400081002005, 101, FALSE), (400081002102, 400081002102, 400081002005, 102, FALSE), (400081002103, 400081002103, 400081002006, 103, FALSE), (400081002104, 400081002104, 400081002006, 104, FALSE), (400081002105, 400081002105, 400081002006, 105, FALSE), (400081002106, 400081002106, 400081002006, 106, FALSE), (400081002107, 400081002107, 400081002006, 107, FALSE), (400081002108, 400081002108, 400081002006, 108, FALSE), (400081002109, 400081002109, 400081002006, 109, FALSE), (400081002110, 400081002110, 400081002006, 110, FALSE), (400081002111, 400081002111, 400081002007, 111, FALSE), (400081002112, 400081002112, 400081002007, 112, FALSE), (400081002113, 400081002113, 400081002007, 113, FALSE), (400081002114, 400081002114, 400081002007, 114, FALSE), (400081002115, 400081002115, 400081002008, 115, FALSE), (400081002116, 400081002116, 400081002008, 116, FALSE), (400081002117, 400081002117, 400081002008, 117, FALSE), (400081002118, 400081002118, 400081002008, 118, FALSE), (400081002119, 400081002119, 400081002008, 119, FALSE), (400081002120, 400081002120, 400081002009, 120, FALSE), (400081002121, 400081002121, 400081002009, 121, FALSE), (400081002122, 400081002122, 400081002009, 122, FALSE), (400081002123, 400081002123, 400081002009, 123, FALSE), (400081002124, 400081002124, 400081002009, 124, FALSE), (400081002125, 400081002125, 400081002009, 125, FALSE), (400081002126, 400081002126, 400081002009, 126, FALSE), (400081002127, 400081002127, 400081002009, 127, FALSE), (400081002128, 400081002128, 400081002009, 128, FALSE), (400081002129, 400081002129, 400081002009, 129, FALSE), (400081002130, 400081002130, 400081002009, 130, FALSE), (400081002131, 400081002131, 400081002009, 131, FALSE), (400081002132, 400081002132, 400081002009, 132, FALSE), (400081002133, 400081002133, 400081002009, 133, FALSE), (400081002134, 400081002134, 400081002009, 134, FALSE), (400081002135, 400081002135, 400081002009, 135, FALSE), (400081002136, 400081002136, 400081002009, 136, FALSE), (400081002137, 400081002137, 400081002009, 137, FALSE), (400081002138, 400081002138, 400081002009, 138, FALSE), (400081002139, 400081002139, 400081002009, 139, FALSE), (400081002140, 400081002140, 400081002009, 140, FALSE), (400081002141, 400081002141, 400081002009, 141, FALSE), (400081002142, 400081002142, 400081002009, 142, FALSE), (400081002143, 400081002143, 400081002009, 143, FALSE), (400081002144, 400081002144, 400081002009, 144, FALSE), (400081002145, 400081002145, 400081002009, 145, FALSE), (400081002146, 400081002146, 400081002009, 146, FALSE), (400081002147, 400081002147, 400081002009, 147, FALSE), (400081002148, 400081002148, 400081002009, 148, FALSE), (400081002149, 400081002149, 400081002009, 149, FALSE), (400081002150, 400081002150, 400081002009, 150, FALSE), (400081002151, 400081002151, 400081002009, 151, FALSE), (400081002152, 400081002152, 400081002009, 152, FALSE), (400081002153, 400081002153, 400081002009, 153, FALSE), (400081002154, 400081002154, 400081002009, 154, FALSE), (400081002155, 400081002155, 400081002009, 155, FALSE), (400081002156, 400081002156, 400081002009, 156, FALSE), (400081002157, 400081002157, 400081002009, 157, FALSE), (400081002158, 400081002158, 400081002009, 158, FALSE), (400081002159, 400081002159, 400081002009, 159, FALSE), (400081002160, 400081002160, 400081002009, 160, FALSE), (400081002161, 400081002161, 400081002009, 161, FALSE), (400081002162, 400081002162, 400081002009, 162, FALSE), (400081002163, 400081002163, 400081002009, 163, FALSE), (400081002164, 400081002164, 400081002009, 164, FALSE), (400081002165, 400081002165, 400081002009, 165, FALSE), (400081002166, 400081002166, 400081002009, 166, FALSE), (400081002167, 400081002167, 400081002009, 167, FALSE), (400081002168, 400081002168, 400081002009, 168, FALSE), (400081002169, 400081002169, 400081002009, 169, FALSE), (400081002170, 400081002170, 400081002009, 170, FALSE), (400081002171, 400081002171, 400081002009, 171, FALSE), (400081002172, 400081002172, 400081002009, 172, FALSE), (400081002173, 400081002173, 400081002009, 173, FALSE), (400081002174, 400081002174, 400081002009, 174, FALSE), (400081002175, 400081002175, 400081002009, 175, FALSE), (400081002176, 400081002176, 400081002009, 176, FALSE), (400081002177, 400081002177, 400081002010, 177, FALSE), (400081002178, 400081002178, 400081002010, 178, FALSE), (400081002179, 400081002179, 400081002010, 179, FALSE), (400081002180, 400081002180, 400081002010, 180, FALSE), (400081002181, 400081002181, 400081002010, 181, FALSE), (400081002182, 400081002182, 400081002010, 182, FALSE), (400081002183, 400081002183, 400081002010, 183, FALSE), (400081002184, 400081002184, 400081002010, 184, FALSE), (400081002185, 400081002185, 400081002010, 185, FALSE), (400081002186, 400081002186, 400081002010, 186, FALSE), (400081002187, 400081002187, 400081002010, 187, FALSE), (400081002188, 400081002188, 400081002010, 188, FALSE), (400081002189, 400081002189, 400081002010, 189, FALSE), (400081002190, 400081002190, 400081002010, 190, FALSE), (400081002191, 400081002191, 400081002010, 191, FALSE), (400081002192, 400081002192, 400081002010, 192, FALSE), (400081002193, 400081002193, 400081002010, 193, FALSE), (400081002194, 400081002194, 400081002010, 194, FALSE), (400081002195, 400081002195, 400081002010, 195, FALSE), (400081002196, 400081002196, 400081002010, 196, FALSE), (400081002197, 400081002197, 400081002010, 197, FALSE), (400081002198, 400081002198, 400081002010, 198, FALSE), (400081002199, 400081002199, 400081002010, 199, FALSE), (400081002200, 400081002200, 400081002010, 200, FALSE), (400081002201, 400081002201, 400081002010, 201, FALSE), (400081002202, 400081002202, 400081002010, 202, FALSE), (400081002203, 400081002203, 400081002010, 203, FALSE), (400081002204, 400081002204, 400081002010, 204, FALSE), (400081002205, 400081002205, 400081002010, 205, FALSE), (400081002206, 400081002206, 400081002010, 206, FALSE), (400081002207, 400081002207, 400081002010, 207, FALSE), (400081002208, 400081002208, 400081002010, 208, FALSE), (400081002209, 400081002209, 400081002010, 209, FALSE), (400081002210, 400081002210, 400081002010, 210, FALSE), (400081002211, 400081002211, 400081002010, 211, FALSE), (400081002212, 400081002212, 400081002010, 212, FALSE), (400081002213, 400081002213, 400081002010, 213, FALSE), (400081002214, 400081002214, 400081002010, 214, FALSE), (400081002215, 400081002215, 400081002010, 215, FALSE), (400081002216, 400081002216, 400081002010, 216, FALSE), (400081002217, 400081002217, 400081002010, 217, FALSE), (400081002218, 400081002218, 400081002010, 218, FALSE), (400081002219, 400081002219, 400081002010, 219, FALSE), (400081002220, 400081002220, 400081002010, 220, FALSE), (400081002221, 400081002221, 400081002010, 221, FALSE), (400081002222, 400081002222, 400081002010, 222, FALSE), (400081002223, 400081002223, 400081002010, 223, FALSE), (400081002224, 400081002224, 400081002010, 224, FALSE), (400081002225, 400081002225, 400081002010, 225, FALSE), (400081002226, 400081002226, 400081002010, 226, FALSE), (400081002227, 400081002227, 400081002010, 227, FALSE), (400081002228, 400081002228, 400081002010, 228, FALSE), (400081002229, 400081002229, 400081002010, 229, FALSE), (400081002230, 400081002230, 400081002010, 230, FALSE), (400081002231, 400081002231, 400081002010, 231, FALSE), (400081002232, 400081002232, 400081002010, 232, FALSE), (400081002233, 400081002233, 400081002010, 233, FALSE), (400081002234, 400081002234, 400081002010, 234, FALSE), (400081002235, 400081002235, 400081002010, 235, FALSE), (400081002236, 400081002236, 400081002010, 236, FALSE), (400081002237, 400081002237, 400081002011, 237, FALSE), (400081002238, 400081002238, 400081002011, 238, FALSE), (400081002239, 400081002239, 400081002011, 239, FALSE), (400081002240, 400081002240, 400081002011, 240, FALSE), (400081002241, 400081002241, 400081002012, 241, FALSE), (400081002242, 400081002242, 400081002012, 242, FALSE), (400081002243, 400081002243, 400081002012, 243, FALSE), (400081002244, 400081002244, 400081002013, 244, FALSE), (400081002245, 400081002245, 400081002013, 245, FALSE), (400081002246, 400081002246, 400081002013, 246, FALSE)) AS x(menu_board_item_id, menu_item_id, menu_category_id, display_sequence, is_featured);

INSERT INTO menu_item_tag (menu_item_id, tag_id)
SELECT mi.menu_item_id, pt.tag_id
FROM menu_item mi, platform_tag pt, khaustan_onboarding_ctx ctx
WHERE mi.restaurant_id = ctx.restaurant_id
  AND pt.tag_code = 'SPICY'
  AND mi.normalized_name IN ('paneer chilly', 'paneer taichin', 'paneer chilly bean', 'silken tofu chilly bean', 'silken tofu taichin', 'baby corn chilly', 'mushroom chilly', 'chilly potatoes', 'veg. green sauce', 'veg. butter garlic', 'chicken chilly', 'chicken taronest', 'chicken taichin', 'chicken chilly bean', 'veg. schezwan rice', 'chicken schezwan rice', 'seafood schezwan rice', 'veg. thai fried rice', 'chicken thai fried rice', 'seafood thai fried rice', 'veg. schezwan noodles', 'chicken schezwan noodles', 'seafood schezwan noodles', 'veg. pad thai noodles', 'chicken pad thai noodles', 'seafood pad thai noodles', 'paneer chilly gravy', 'veg. chilly gravy', 'chicken chilly gravy', 'seafood chilly gravy', 'paneer schezwan', 'veg. schezwan', 'chicken schezwan', 'seafood schezwan', 'paneer red pepper', 'veg. red pepper', 'chicken red pepper', 'seafood red pepper', 'paneer chilly bean / black bean sauce', 'veg. chilly bean / black bean sauce', 'chicken chilly bean / black bean sauce', 'seafood chilly bean / black bean sauce', 'paneer hot garlic', 'chicken hot garlic', 'chicken red cooked', 'fire cracker prawns (6 pcs.)', 'paneer hot garlic', 'veg. hot garlic', 'chicken hot garlic', 'seafood hot garlic')
ON CONFLICT DO NOTHING;

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row with
-- verification_status_code = 'needs_review', one line each.
-- =============================================================================
-- NEEDS_REVIEW [0.65] "Chicken Meat Ball Soup with Silky Noodles" (SOUPS): Raw text gives two numbers after this name (250, 260) with no leading '-' and no second dish name, unlike every other SOUPS row. Used 250 (consistent with the dish being explicitly 'Chicken'); the extra '260' is not attached to anything and is called out in UNMAPPED notes rather than invented into a second dish.
-- NEEDS_REVIEW [0.85] "Mixed Platter (Prawns in Butter Pepper Garlic sauce, Chilli Basa, Chicken in Hot Garlic sauce, Chicken lollipops & Spring rolls served together)" (PLATTERS): Combines chicken and seafood -- no single protein_type_id fits, so left unset (food_classification_code='non_veg' only).
-- NEEDS_REVIEW [0.75] "Paneer Sizzler" (SIZZLERS): 'Sizzler' suffix supplied from the section header (SIZZLERS); the printed line names only the protein.
-- NEEDS_REVIEW [0.75] "Mix Veg. Sizzler" (SIZZLERS): 'Sizzler' suffix supplied from the section header (SIZZLERS); the printed line names only the protein.
-- NEEDS_REVIEW [0.75] "Chicken Sizzler" (SIZZLERS): 'Sizzler' suffix supplied from the section header (SIZZLERS); the printed line names only the protein.
-- NEEDS_REVIEW [0.75] "Prawns Sizzler" (SIZZLERS): 'Sizzler' suffix supplied from the section header (SIZZLERS); the printed line names only the protein.
-- NEEDS_REVIEW [0.75] "Mix Seafood Sizzler" (SIZZLERS): 'Sizzler' suffix supplied from the section header (SIZZLERS); the printed line names only the protein.
-- NEEDS_REVIEW [0.75] "Mix Fried Rice" (RICE & NOODLES): Single price given with no Veg./Chicken/Seafood breakdown, unlike its neighbors; read as a mixed-vegetable fried rice (conventional meaning of 'Mix' in this cuisine), not asserted as containing meat.
-- NEEDS_REVIEW [0.65] "Steamed Rice" (RICE & NOODLES): Two prices (180, 315) given with no Veg./Chicken/Seafood context (plain rice has no protein variant) and no explicit 'Half'/'Full' label on this line -- read as a portion-size split by analogy to how other restaurants in this batch label ascending pairs, at lower confidence since it isn't stated here.
-- NEEDS_REVIEW [0.90] "Mineral Water" (COOLERS): Priced 'M.R.P.' (maximum retail price) -- varies by bottle brand/size actually stocked, so is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Aerated Waters" (COOLERS): Priced 'M.R.P.' -- same treatment as Mineral Water above.

-- =============================================================================
-- UNMAPPED: restaurant-level facts with no clean schema home, or deliberately
-- left for a human decision.
-- =============================================================================
-- UNMAPPED: "Choice of Sauces" note (Butter Garlic, Chilly, Hunan Style, Taichin, Kungpao, Shanghai, Chilly Bean, Black Bean & Hot Garlic) doesn't exactly match the 12 sauce-style headers actually found under MAIN COURSE -- likely applies to a different part of the menu not clearly delineated in this docx; not used to constrain what was extracted.
-- UNMAPPED: "No Separate Kitchen for Vegetarian & Non Vegetarian Delicacies" -- an important disclosure for strict vegetarians, with no clean schema home; preserved here verbatim rather than dropped.
-- UNMAPPED: "We accept party orders." -- ambiguous between dine-in group bookings and off-site catering, so not mapped to service_mode = 'bulk_catering'.
-- UNMAPPED: "(M. l. 19-10-2025)" in the footer looks like a menu-revision date (19 Oct 2025); no schema column for the source menu's own revision date exists (menu_extraction_batch.started_at records when THIS script ran, not when the restaurant last updated its printed menu).
-- UNMAPPED: Rates are subject to change without prior notice / Govt. taxes extra as applicable / Order once placed cannot be cancelled / All special dishes take time for preparation -- general policy notes with no structured schema home, preserved here rather than dropped.
-- UNMAPPED: '[Chef recommends]' is defined in the menu's own legend but never actually applied to a specific item in the recovered text, so no 'chef_recommends' tag was created (and no such tag exists in your real platform_tag data anyway -- the closest is 'CHEFS_SPECIAL', tag_id 56, not applied to anything here since nothing in the source specifically marks it).
-- UNMAPPED: Your original real 'SPICY' tag (tag_id 54) has no distinct 'extra spicy' counterpart -- this script's two source markers (single ')' vs double '))') both map onto that one tag; if you want the 'more spicy' distinction preserved, that needs a new platform_tag added to your real lookup data first, since this script does not invent lookup rows beyond what you've defined.
