-- =============================================================================
-- Khaustan onboarding script: Janata Fast Food
-- Source: Janata_Fast_Food_Menu_Transcribed.json (JSON)
-- Schema: khaustan-full-platform-postgresql.sql, database "KhaustanRestaurantMenu"
-- Built against the attached JSON-input resolved prompt, with the explicit
-- overrides supplied for this restaurant pair.
--
-- SHARED CONTEXT: Janata Tawa & Grill and Janata Fast Food are two
-- restaurant listings under ONE establishment (establishment_id
-- 400070008) and ONE brand. This script is safe to run in either
-- order relative to its sibling -- the establishment and brand are both
-- identify-or-create, so whichever of the two scripts runs first creates
-- them, and the second finds them already there.
--
-- ID NAMESPACE (per the attached prompt, with one necessary deviation):
--   establishment_id = 400070008 (shared, hardcoded, per your instruction)
--   restaurant_id     = 400070009 (hardcoded, per your instruction)
--   source_id         = 400070009
-- DEVIATION: the attached prompt specifies source_id = establishment_id
-- always. With two restaurants sharing one establishment_id, that would
-- mean both source_record rows collide on the same primary key. source_id
-- is set to this restaurant's own restaurant_id instead, which keeps the
-- same "meaningful, deterministic, no nextval()" spirit without a PK clash.
-- Every other 12-digit child ID (menu_item_id, variant_id, price_id, etc.)
-- is <restaurant_id><counter:03d>, its own independent per-table counter,
-- exactly as specified.
--
-- CLIENT COMPATIBILITY: the attached prompt's Step 7 opens with
-- \connect "KhaustanRestaurantMenu". Every prior script in this whole
-- project has hit real, reported syntax errors from psql-only meta-commands
-- when run in pgAdmin4's Query Tool, which is this account's actual client
-- -- so \connect is omitted here too, replaced by a plain instruction to
-- connect via the client's own UI first. No CREATE SEQUENCE / nextval()
-- either, consistent with the rest of this project -- every ID is a Python-
-- computed literal.
--
-- LOOKUP TABLES ARE READ-ONLY (per the attached prompt): no platform_tag,
-- delivery_provider, protein_type, or service_mode row is ever created or
-- modified by this script. Every reference to one is a plain subquery
-- against the existing row; if a needed value doesn't exist, the dependent
-- INSERT simply matches zero rows rather than failing or inventing one --
-- called out explicitly in the UNMAPPED block if that happens here.
--
-- TESTING PERFORMED: no live Postgres server is available in this build
-- environment. Every INSERT column list was checked against a parsed model
-- of the real DDL; every CTE chain's comma-vs-final-statement placement was
-- traced by hand (the specific class of bug found and fixed in this
-- project's immediately preceding round); parentheses/quotes confirmed
-- balanced; zero psql-only syntax anywhere. Please still run this against
-- a staging database first.
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
  v_brand_id BIGINT;
BEGIN
  SELECT brand_id INTO v_brand_id FROM brand WHERE normalized_name = lower(trim('Janata'));
  IF NOT FOUND THEN
    v_brand_id := 000100001;
    INSERT INTO brand (brand_id, name, normalized_name, website_url, youtube_channel)
    VALUES (v_brand_id, 'Janata', lower(trim('Janata')), 'https://janatatawaandgrill.in/', 'None');
  END IF;
END $do$;

DO $do$
DECLARE
  v_establishment_id BIGINT;
  v_restaurant_id    BIGINT;
  v_brand_id         BIGINT;
BEGIN
  SELECT brand_id INTO v_brand_id FROM brand WHERE normalized_name = lower(trim('Janata'));

  SELECT establishment_id INTO v_establishment_id FROM establishment
  WHERE establishment_id = 400070008;

  IF NOT FOUND THEN
    v_establishment_id := 400070008;
    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, city, state, country_code, latitude, longitude, website_url, instagram_handle, facebook_handle)
    VALUES (v_establishment_id, 'Janata Restaurant Kurla', lower(trim('Janata Restaurant Kurla')), 'Shop No. 6/7, 168, Rassi Wala Chawl, Near New Noor Hospital, L.B.S. Marg', 'Kurla (W)', '400070', 'Mumbai', 'Maharashtra', 'IN', 19.076392976036896, 72.87790469341015, 'www.janatarestaurantkurla.com', 'None', 'None');
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant WHERE restaurant_id = 400070009;

  IF NOT FOUND THEN
    v_restaurant_id := 400070009;
    INSERT INTO restaurant (restaurant_id, establishment_id, brand_id, display_name, normalized_name, has_bar, bar_license_type)
    VALUES (v_restaurant_id, 400070008, v_brand_id, 'Janata Fast Food', lower(trim('Janata Fast Food')), FALSE, 'none');
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
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Janata_Fast_Food_Menu_Transcribed.json')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant. Aborting.', 'Janata_Fast_Food_Menu_Transcribed.json';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
SELECT 400070009, 'ai_menu_extraction', 'Janata_Fast_Food_Menu_Transcribed.json'
WHERE NOT EXISTS (SELECT 1 FROM source_record WHERE source_id = 400070009);
UPDATE khaustan_onboarding_ctx SET source_id = 400070009;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400070009001, ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx SET extraction_batch_id = 400070009001;

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT x.phone_id, ctx.restaurant_id, x.phone_number, x.is_primary
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070009001, '7506170354', TRUE), (400070009002, '9326529579', FALSE)) AS x(phone_id, phone_number, is_primary);

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available)
SELECT ctx.restaurant_id, TRUE, FALSE FROM khaustan_onboarding_ctx ctx;

INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from)
SELECT 400070009001, ctx.restaurant_id, dp.delivery_provider_id, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM khaustan_onboarding_ctx ctx, delivery_provider dp
WHERE dp.provider_code = 'SWIGGY';

INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
SELECT 400070009001, ctx.restaurant_id, pt.tag_id, TRUE
FROM khaustan_onboarding_ctx ctx, platform_tag pt
WHERE pt.tag_code = 'halal';

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name, batched
-- into one set-based statement (safe: normalized_name is the identity
-- key and the candidate list is de-duplicated before generation).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_dish_id, canonical_dish_name_id, canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    (400070009001, 400070009001, 'Veg Sandwich', 'veg sandwich', 'veg', NULL),
    (400070009002, 400070009002, 'Veg Cheese Grilled Sandwich', 'veg cheese grilled sandwich', 'veg', NULL),
    (400070009003, 400070009003, 'Paneer Tikka Grill Sandwich', 'paneer tikka grill sandwich', 'veg', NULL),
    (400070009004, 400070009004, 'Paneer Cheese Melting Sandwich', 'paneer cheese melting sandwich', 'veg', NULL),
    (400070009005, 400070009005, 'Veg Melting Sandwich', 'veg melting sandwich', 'veg', NULL),
    (400070009006, 400070009006, 'Salted Fries', 'salted fries', 'veg', NULL),
    (400070009007, 400070009007, 'Peri Peri Fries', 'peri peri fries', 'veg', NULL),
    (400070009008, 400070009008, 'Cheese Fries', 'cheese fries', 'veg', NULL),
    (400070009009, 400070009009, 'Barbeque Fries', 'barbeque fries', 'veg', NULL),
    (400070009010, 400070009010, 'Loaded Fries', 'loaded fries', 'veg', NULL),
    (400070009011, 400070009011, 'Mayo Fries', 'mayo fries', 'veg', NULL),
    (400070009012, 400070009012, 'Chicken Nuggets (6 Pcs)', 'chicken nuggets (6 pcs)', 'non_veg', 'CHICKEN'),
    (400070009013, 400070009013, 'Chicken Popcorn', 'chicken popcorn', 'non_veg', 'CHICKEN'),
    (400070009014, 400070009014, 'Chicken Wings', 'chicken wings', 'non_veg', 'CHICKEN'),
    (400070009015, 400070009015, 'Chicken Strips', 'chicken strips', 'non_veg', 'CHICKEN'),
    (400070009016, 400070009016, 'Dynamite Wings', 'dynamite wings', 'veg', NULL),
    (400070009017, 400070009017, 'Hot Honey Tenders', 'hot honey tenders', 'veg', NULL),
    (400070009018, 400070009018, 'Dynamite Tenders', 'dynamite tenders', 'veg', NULL),
    (400070009019, 400070009019, 'Chicken Chizza', 'chicken chizza', 'non_veg', 'CHICKEN'),
    (400070009020, 400070009020, 'Cheese Garlic Bread', 'cheese garlic bread', 'veg', NULL),
    (400070009021, 400070009021, 'Veg Garlic Bread', 'veg garlic bread', 'veg', NULL),
    (400070009022, 400070009022, 'Paneer Cheese Bread', 'paneer cheese bread', 'veg', NULL),
    (400070009023, 400070009023, 'Chicken Cheese Bread', 'chicken cheese bread', 'non_veg', 'CHICKEN'),
    (400070009024, 400070009024, 'Chicken Shawarma Sandwich', 'chicken shawarma sandwich', 'non_veg', 'CHICKEN'),
    (400070009025, 400070009025, 'Chicken Tandoori Sandwich', 'chicken tandoori sandwich', 'non_veg', 'CHICKEN'),
    (400070009026, 400070009026, 'Chicken Tikka Sandwich', 'chicken tikka sandwich', 'non_veg', 'CHICKEN'),
    (400070009027, 400070009027, 'Cheese Grill Sandwich', 'cheese grill sandwich', 'veg', NULL),
    (400070009028, 400070009028, 'Club Sandwich', 'club sandwich', 'veg', NULL),
    (400070009029, 400070009029, 'Chicken Cheese Melting Sandwich', 'chicken cheese melting sandwich', 'non_veg', 'CHICKEN'),
    (400070009030, 400070009030, 'Chicken Bbq Sandwich', 'chicken bbq sandwich', 'non_veg', 'CHICKEN'),
    (400070009031, 400070009031, 'Chicken Mayo Grill Sandwich', 'chicken mayo grill sandwich', 'non_veg', 'CHICKEN'),
    (400070009032, 400070009032, 'Chicken Peri Peri Grill Sandwich', 'chicken peri peri grill sandwich', 'non_veg', 'CHICKEN'),
    (400070009033, 400070009033, 'Aloo Tikki Burger', 'aloo tikki burger', 'veg', NULL),
    (400070009034, 400070009034, 'Janata Spl. Burger', 'janata spl. burger', 'veg', NULL),
    (400070009035, 400070009035, 'Crispy Paneer Burger', 'crispy paneer burger', 'veg', NULL),
    (400070009036, 400070009036, 'Zinger Burger', 'zinger burger', 'veg', NULL),
    (400070009037, 400070009037, 'Zinger Burger With Cheese', 'zinger burger with cheese', 'veg', NULL),
    (400070009038, 400070009038, 'Grilled Chicken Burger', 'grilled chicken burger', 'non_veg', 'CHICKEN'),
    (400070009039, 400070009039, 'Hot Honey Burger', 'hot honey burger', 'veg', NULL),
    (400070009040, 400070009040, 'Dynamite Burger', 'dynamite burger', 'veg', NULL),
    (400070009041, 400070009041, 'Jalapeno Burger', 'jalapeno burger', 'veg', NULL),
    (400070009042, 400070009042, 'Jalapeno Burger With Cheese', 'jalapeno burger with cheese', 'veg', NULL),
    (400070009043, 400070009043, 'Nugget Burger', 'nugget burger', 'veg', NULL),
    (400070009044, 400070009044, 'Bbq Burger', 'bbq burger', 'veg', NULL),
    (400070009045, 400070009045, 'Peri Peri Burger', 'peri peri burger', 'veg', NULL),
    (400070009046, 400070009046, 'Mexican Burger', 'mexican burger', 'veg', NULL),
    (400070009047, 400070009047, 'Schezwan Burger', 'schezwan burger', 'veg', NULL),
    (400070009048, 400070009048, 'Veg Cheese Pizza', 'veg cheese pizza', 'veg', NULL),
    (400070009049, 400070009049, 'Margherita Pizza', 'margherita pizza', 'veg', NULL),
    (400070009050, 400070009050, 'Hawaiian Pizza', 'hawaiian pizza', 'veg', NULL),
    (400070009051, 400070009051, 'Mexican Pizza', 'mexican pizza', 'veg', NULL),
    (400070009052, 400070009052, 'Paneer Makhani Pizza', 'paneer makhani pizza', 'veg', NULL),
    (400070009053, 400070009053, 'Sweet Corn Pizza', 'sweet corn pizza', 'veg', NULL),
    (400070009054, 400070009054, 'Baby Corn Pizza', 'baby corn pizza', 'veg', NULL),
    (400070009055, 400070009055, 'Mashroom Pizza', 'mashroom pizza', 'veg', NULL),
    (400070009056, 400070009056, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'veg', NULL),
    (400070009057, 400070009057, 'Veg Italian Pizza', 'veg italian pizza', 'veg', NULL),
    (400070009058, 400070009058, 'Veg Melting Pizza', 'veg melting pizza', 'veg', NULL),
    (400070009059, 400070009059, 'Chicken Cheese Pizza', 'chicken cheese pizza', 'non_veg', 'CHICKEN'),
    (400070009060, 400070009060, 'Chicken Tandoori Pizza', 'chicken tandoori pizza', 'non_veg', 'CHICKEN'),
    (400070009061, 400070009061, 'Chicken Shawarma Pizza', 'chicken shawarma pizza', 'non_veg', 'CHICKEN'),
    (400070009062, 400070009062, 'Chicken Makrani Pizza', 'chicken makrani pizza', 'non_veg', 'CHICKEN'),
    (400070009063, 400070009063, 'Chicken Tikka Pizza', 'chicken tikka pizza', 'non_veg', 'CHICKEN'),
    (400070009064, 400070009064, 'Janata Spl. Pizza', 'janata spl. pizza', 'veg', NULL),
    (400070009065, 400070009065, 'Chicken Melting Pizza', 'chicken melting pizza', 'non_veg', 'CHICKEN'),
    (400070009066, 400070009066, 'Chicken Cassic Pizza', 'chicken cassic pizza', 'non_veg', 'CHICKEN'),
    (400070009067, 400070009067, 'Chicken Bbq Pizza', 'chicken bbq pizza', 'non_veg', 'CHICKEN'),
    (400070009068, 400070009068, 'Chicken Nawabi Pizza', 'chicken nawabi pizza', 'non_veg', 'CHICKEN'),
    (400070009069, 400070009069, 'Chicken Popcorn Pizza', 'chicken popcorn pizza', 'non_veg', 'CHICKEN'),
    (400070009070, 400070009070, 'Extra Cheese', 'extra cheese', 'veg', NULL),
    (400070009071, 400070009071, 'Classic Shawarma', 'classic shawarma', 'veg', NULL),
    (400070009072, 400070009072, 'Cheese Shawarma', 'cheese shawarma', 'veg', NULL),
    (400070009073, 400070009073, 'Peri-peri Shawarma', 'peri-peri shawarma', 'veg', NULL),
    (400070009074, 400070009074, 'Peri-peri Cheese Shawarma', 'peri-peri cheese shawarma', 'veg', NULL),
    (400070009075, 400070009075, 'Rumali Shawarma', 'rumali shawarma', 'veg', NULL),
    (400070009076, 400070009076, 'Rumali Cheese Shawarma', 'rumali cheese shawarma', 'veg', NULL),
    (400070009077, 400070009077, 'Open Shawarma', 'open shawarma', 'veg', NULL),
    (400070009078, 400070009078, 'Chicken Platter Salad', 'chicken platter salad', 'non_veg', 'CHICKEN'),
    (400070009079, 400070009079, 'Bbq Shawarma', 'bbq shawarma', 'veg', NULL),
    (400070009080, 400070009080, 'Zinger Shawarma', 'zinger shawarma', 'veg', NULL),
    (400070009081, 400070009081, 'Zinger Shawarma With Cheese', 'zinger shawarma with cheese', 'veg', NULL),
    (400070009082, 400070009082, 'Chicken Mayo Roll', 'chicken mayo roll', 'non_veg', 'CHICKEN'),
    (400070009083, 400070009083, 'Chicken Tikka Roll', 'chicken tikka roll', 'non_veg', 'CHICKEN'),
    (400070009084, 400070009084, 'Chicken Barbeque Roll', 'chicken barbeque roll', 'non_veg', 'CHICKEN'),
    (400070009085, 400070009085, 'Mexican Wrap', 'mexican wrap', 'veg', NULL),
    (400070009086, 400070009086, 'Popcorn Cheese Wrap', 'popcorn cheese wrap', 'veg', NULL),
    (400070009087, 400070009087, 'Tikka Wrap', 'tikka wrap', 'veg', NULL),
    (400070009088, 400070009088, 'Nuggets Wrap', 'nuggets wrap', 'veg', NULL),
    (400070009089, 400070009089, 'Cold Coffee', 'cold coffee', 'veg', NULL),
    (400070009090, 400070009090, 'Coffee On The Rocks', 'coffee on the rocks', 'veg', NULL),
    (400070009091, 400070009091, 'Sweet House Mafia', 'sweet house mafia', 'veg', NULL),
    (400070009092, 400070009092, 'Mud Coffee', 'mud coffee', 'veg', NULL),
    (400070009093, 400070009093, 'Falooda', 'falooda', 'veg', NULL),
    (400070009094, 400070009094, 'Kesar Falooda', 'kesar falooda', 'veg', NULL),
    (400070009095, 400070009095, 'Kulfi Falooda', 'kulfi falooda', 'veg', NULL),
    (400070009096, 400070009096, 'Delhi Style Falooda', 'delhi style falooda', 'veg', NULL),
    (400070009097, 400070009097, 'Janata Falooda', 'janata falooda', 'veg', NULL),
    (400070009098, 400070009098, 'Royal Falooda', 'royal falooda', 'veg', NULL),
    (400070009099, 400070009099, 'Fruit Falooda', 'fruit falooda', 'veg', NULL),
    (400070009100, 400070009100, 'Rabdi Dry Falooda', 'rabdi dry falooda', 'veg', NULL),
    (400070009101, 400070009101, 'Dry Fruit Falooda', 'dry fruit falooda', 'veg', NULL),
    (400070009102, 400070009102, 'Vanilla Falooda', 'vanilla falooda', 'veg', NULL),
    (400070009103, 400070009103, 'Malai Falooda', 'malai falooda', 'veg', NULL),
    (400070009104, 400070009104, 'Sweet & Salty', 'sweet & salty', 'veg', NULL),
    (400070009105, 400070009105, 'Sweet Soda', 'sweet soda', 'veg', NULL),
    (400070009106, 400070009106, 'Salty', 'salty', 'veg', NULL),
    (400070009107, 400070009107, 'Chocolate Mud', 'chocolate mud', 'veg', NULL),
    (400070009108, 400070009108, 'Mango Mud', 'mango mud', 'veg', NULL),
    (400070009109, 400070009109, 'Strawberry Mud', 'strawberry mud', 'veg', NULL),
    (400070009110, 400070009110, 'Kit Kat Mud', 'kit kat mud', 'veg', NULL),
    (400070009111, 400070009111, 'Oreo Mud', 'oreo mud', 'veg', NULL),
    (400070009112, 400070009112, 'Janata Spl. Mud', 'janata spl. mud', 'veg', NULL),
    (400070009113, 400070009113, 'Arabic Pudding', 'arabic pudding', 'veg', NULL),
    (400070009114, 400070009114, 'Caramel Custard', 'caramel custard', 'veg', NULL),
    (400070009115, 400070009115, 'Gulab Jamun', 'gulab jamun', 'veg', NULL),
    (400070009116, 400070009116, 'Matka Rabdi', 'matka rabdi', 'veg', NULL),
    (400070009117, 400070009117, 'Apricot Delight', 'apricot delight', 'veg', NULL),
    (400070009118, 400070009118, 'Lava Cake', 'lava cake', 'veg', NULL),
    (400070009119, 400070009119, 'Browni With Ice Cream', 'browni with ice cream', 'veg', NULL),
    (400070009120, 400070009120, 'Sitafal (seasonal)', 'sitafal (seasonal)', 'veg', NULL),
    (400070009121, 400070009121, 'Strawberry (seasonal)', 'strawberry (seasonal)', 'veg', NULL),
    (400070009122, 400070009122, 'Mix Fruit Cream', 'mix fruit cream', 'veg', NULL),
    (400070009123, 400070009123, 'Mulberry Cream', 'mulberry cream', 'veg', NULL),
    (400070009124, 400070009124, 'Mango (seasonal)', 'mango (seasonal)', 'veg', NULL),
    (400070009125, 400070009125, 'Pineapple', 'pineapple', 'veg', NULL),
    (400070009126, 400070009126, 'Watermelon', 'watermelon', 'veg', NULL),
    (400070009127, 400070009127, 'Musk Melon', 'musk melon', 'veg', NULL),
    (400070009128, 400070009128, 'Orange', 'orange', 'veg', NULL),
    (400070009129, 400070009129, 'Chikoo', 'chikoo', 'veg', NULL),
    (400070009130, 400070009130, 'Papaya', 'papaya', 'veg', NULL),
    (400070009131, 400070009131, 'Mosambi (sweet Lime)', 'mosambi (sweet lime)', 'veg', NULL),
    (400070009132, 400070009132, 'Fresh Lemon', 'fresh lemon', 'veg', NULL),
    (400070009133, 400070009133, 'Moroccan Mint Lime', 'moroccan mint lime', 'veg', NULL),
    (400070009134, 400070009134, 'Pomegranate (anar)', 'pomegranate (anar)', 'veg', NULL),
    (400070009135, 400070009135, 'Carrot', 'carrot', 'veg', NULL),
    (400070009136, 400070009136, 'Dragon', 'dragon', 'veg', NULL),
    (400070009137, 400070009137, 'Kiwi', 'kiwi', 'veg', NULL),
    (400070009138, 400070009138, 'Mix', 'mix', 'veg', NULL),
    (400070009139, 400070009139, 'Beetroot', 'beetroot', 'veg', NULL),
    (400070009140, 400070009140, 'Tender Coconut', 'tender coconut', 'veg', NULL),
    (400070009141, 400070009141, 'Sitafal (custard Apple) (seasonal)', 'sitafal (custard apple) (seasonal)', 'veg', NULL),
    (400070009142, 400070009142, 'Ganga Jamuna (sweet Lime Orange + Pineapple)', 'ganga jamuna (sweet lime orange + pineapple)', 'veg', NULL),
    (400070009143, 400070009143, 'Cap- Carrot Apple Pineapple', 'cap- carrot apple pineapple', 'veg', NULL),
    (400070009144, 400070009144, 'Abc Apple Beetroot Carrot', 'abc apple beetroot carrot', 'veg', NULL),
    (400070009145, 400070009145, 'Sweet Lassi', 'sweet lassi', 'veg', NULL),
    (400070009146, 400070009146, 'Fruit Lassi', 'fruit lassi', 'veg', NULL),
    (400070009147, 400070009147, 'Mango Lassi', 'mango lassi', 'veg', NULL),
    (400070009148, 400070009148, 'Banana Lassi', 'banana lassi', 'veg', NULL),
    (400070009149, 400070009149, 'Strawberry Lassi', 'strawberry lassi', 'veg', NULL),
    (400070009150, 400070009150, 'Dry Fruit Lassi', 'dry fruit lassi', 'veg', NULL),
    (400070009151, 400070009151, 'Saffron Lassi', 'saffron lassi', 'veg', NULL),
    (400070009152, 400070009152, 'Buttermilk (chas)', 'buttermilk (chas)', 'veg', NULL),
    (400070009153, 400070009153, 'Virgin Mojito', 'virgin mojito', 'veg', NULL),
    (400070009154, 400070009154, 'Blue Lagoon', 'blue lagoon', 'veg', NULL),
    (400070009155, 400070009155, 'Water Melon', 'water melon', 'veg', NULL),
    (400070009156, 400070009156, 'Green Apple', 'green apple', 'veg', NULL),
    (400070009157, 400070009157, 'Blue Berry', 'blue berry', 'veg', NULL),
    (400070009158, 400070009158, 'Berry Paper Shot', 'berry paper shot', 'veg', NULL),
    (400070009159, 400070009159, 'Passion Fruit', 'passion fruit', 'veg', NULL),
    (400070009160, 400070009160, 'Mango Mojito', 'mango mojito', 'veg', NULL),
    (400070009161, 400070009161, 'Strawberry Mojito', 'strawberry mojito', 'veg', NULL),
    (400070009162, 400070009162, 'Belgian Chocolate', 'belgian chocolate', 'veg', NULL),
    (400070009163, 400070009163, 'Oreo Shake', 'oreo shake', 'veg', NULL),
    (400070009164, 400070009164, 'Ferrero Automatic', 'ferrero automatic', 'veg', NULL),
    (400070009165, 400070009165, 'Butter Scotch Shake', 'butter scotch shake', 'veg', NULL),
    (400070009166, 400070009166, 'Pista Banana Milkshake', 'pista banana milkshake', 'veg', NULL),
    (400070009167, 400070009167, 'Banana Milk Shake', 'banana milk shake', 'veg', NULL),
    (400070009168, 400070009168, 'Mango Banana Milkshake', 'mango banana milkshake', 'veg', NULL),
    (400070009169, 400070009169, 'Nutella Shake', 'nutella shake', 'veg', NULL),
    (400070009170, 400070009170, 'Mango Strawberry', 'mango strawberry', 'veg', NULL),
    (400070009171, 400070009171, 'Very Berry Strawberry', 'very berry strawberry', 'veg', NULL),
    (400070009172, 400070009172, 'Mango Milk Shake', 'mango milk shake', 'veg', NULL),
    (400070009173, 400070009173, 'Tropical Mix Fruit', 'tropical mix fruit', 'veg', NULL),
    (400070009174, 400070009174, 'Musk Melon Milkshake', 'musk melon milkshake', 'veg', NULL),
    (400070009175, 400070009175, 'Anjeer Milkshake', 'anjeer milkshake', 'veg', NULL),
    (400070009176, 400070009176, 'Kaju Anjeer Milkshake', 'kaju anjeer milkshake', 'veg', NULL),
    (400070009177, 400070009177, 'Avocado Milkshake', 'avocado milkshake', 'veg', NULL),
    (400070009178, 400070009178, 'Dragon Milkshake', 'dragon milkshake', 'veg', NULL),
    (400070009179, 400070009179, 'Mix Dry Fruit Milkshake', 'mix dry fruit milkshake', 'veg', NULL),
    (400070009180, 400070009180, 'Kitkat Milkshake', 'kitkat milkshake', 'veg', NULL),
    (400070009181, 400070009181, 'Mississippi Mud', 'mississippi mud', 'veg', NULL),
    (400070009182, 400070009182, 'Khajoor Milkshake', 'khajoor milkshake', 'veg', NULL),
    (400070009183, 400070009183, 'Banana Khajoor Milkshake', 'banana khajoor milkshake', 'veg', NULL),
    (400070009184, 400070009184, 'Sitafal Milkshake (seasonal)', 'sitafal milkshake (seasonal)', 'veg', NULL),
    (400070009185, 400070009185, 'Iku Milkshake', 'iku milkshake', 'veg', NULL),
    (400070009186, 400070009186, 'Rose Milk', 'rose milk', 'veg', NULL),
    (400070009187, 400070009187, 'Mango Smoothie', 'mango smoothie', 'veg', NULL),
    (400070009188, 400070009188, 'Blueberrie Smoothie', 'blueberrie smoothie', 'veg', NULL),
    (400070009189, 400070009189, 'Banana Smoothie', 'banana smoothie', 'veg', NULL),
    (400070009190, 400070009190, 'Strawberry Smoothie', 'strawberry smoothie', 'veg', NULL),
    (400070009191, 400070009191, 'Janata Delight', 'janata delight', 'veg', NULL),
    (400070009192, 400070009192, 'Caramel Moca Fudge', 'caramel moca fudge', 'veg', NULL),
    (400070009193, 400070009193, 'Debit By Chocolate', 'debit by chocolate', 'veg', NULL),
    (400070009194, 400070009194, 'Nutella Fudges', 'nutella fudges', 'veg', NULL),
    (400070009195, 400070009195, 'Nutella Lychees', 'nutella lychees', 'veg', NULL),
    (400070009196, 400070009196, 'Nutella Brownies', 'nutella brownies', 'veg', NULL),
    (400070009197, 400070009197, 'Chocolate Fudges', 'chocolate fudges', 'veg', NULL),
    (400070009198, 400070009198, 'Mexican Brownie', 'mexican brownie', 'veg', NULL),
    (400070009199, 400070009199, 'Fruit Salad Icecream', 'fruit salad icecream', 'veg', NULL),
    (400070009200, 400070009200, 'Fruit And Cream', 'fruit and cream', 'veg', NULL),
    (400070009201, 400070009201, 'Fruit Overload', 'fruit overload', 'veg', NULL)
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
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070009001, 'VEG SANDWICHES', 1), (400070009002, 'FRENCH FRIES', 2), (400070009003, 'FRIED CHICKEN QUICK BITES', 3), (400070009004, 'CHEESY GARLIC BREAD', 4), (400070009005, 'CHICKEN SANDWICHES', 5), (400070009006, 'VEG BURGER', 6), (400070009007, 'CHICKEN BURGER', 7), (400070009008, 'VEG PIZZA', 8), (400070009009, 'CHICKEN PIZZA', 9), (400070009010, 'SHAWARMA', 10), (400070009011, 'ROLL', 11), (400070009012, 'FRIED CHICKEN WRAP', 12), (400070009013, 'COLD COFFEE', 13), (400070009014, 'FALOODA', 14), (400070009015, 'SODA', 15), (400070009016, 'MUD MILKSHAKE WITH ICECREAM', 16), (400070009017, 'DESSERT', 17), (400070009018, 'FRESH CREAM', 18), (400070009019, 'FRESH JUICE', 19), (400070009020, 'NO ICE NO SUGAR NO WATER', 20), (400070009021, 'LASSI WASSI', 21), (400070009022, 'MOCKTAILS', 22), (400070009023, 'MILKSHAKE', 23), (400070009024, 'SMOOTHIES', 24), (400070009025, 'ICECREAM SUNDAE', 25)) AS x(menu_category_id, name, display_sequence);

-- =============================================================================
-- Menu items (204)
-- =============================================================================

-- Source: docx/json, "VEG SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009001, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009001, 'Veg Sandwich', 'veg sandwich', 'VEG SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009001, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009002, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009001, 'Veg Cheese Grilled Sandwich', 'veg cheese grilled sandwich', 'VEG SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg cheese grilled sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009002, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009003, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009001, 'Paneer Tikka Grill Sandwich', 'paneer tikka grill sandwich', 'VEG SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka grill sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009003, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009004, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009001, 'Paneer Cheese Melting Sandwich', 'paneer cheese melting sandwich', 'VEG SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer cheese melting sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009004, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009005, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009001, 'Veg Melting Sandwich', 'veg melting sandwich', 'VEG SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg melting sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009005, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009006, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Salted Fries', 'salted fries', 'FRENCH FRIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'salted fries'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009006, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009007, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Peri Peri Fries', 'peri peri fries', 'FRENCH FRIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peri peri fries'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009007, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009008, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Cheese Fries', 'cheese fries', 'FRENCH FRIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese fries'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009008, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009009, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Barbeque Fries', 'barbeque fries', 'FRENCH FRIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'barbeque fries'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009009, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009010, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Loaded Fries', 'loaded fries', 'FRENCH FRIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'loaded fries'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009010, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009011, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Mayo Fries', 'mayo fries', 'FRENCH FRIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mayo fries'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009011, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRENCH FRIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009012, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009002, 'Chicken Nuggets (6 Pcs)', 'chicken nuggets (6 pcs)', 'FRENCH FRIES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken nuggets (6 pcs)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009012, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009013, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Chicken Popcorn', 'chicken popcorn', 'FRIED CHICKEN QUICK BITES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken popcorn' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009013, '6-10 pcs', FALSE), (400070009014, '15-20 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009013, '6-10 pcs', 120.00, FALSE), (400070009014, '15-20 pcs', 220.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009014, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Chicken Wings', 'chicken wings', 'FRIED CHICKEN QUICK BITES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken wings' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009015, '8-4 pcs', FALSE), (400070009016, '5-20 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009015, '8-4 pcs', 130.00, FALSE), (400070009016, '5-20 pcs', 250.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009015, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Chicken Strips', 'chicken strips', 'FRIED CHICKEN QUICK BITES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken strips' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009017, '3-4 pcs', FALSE), (400070009018, '6 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009017, '3-4 pcs', 140.00, FALSE), (400070009018, '6 pcs', 260.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009016, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Dynamite Wings', 'dynamite wings', 'FRIED CHICKEN QUICK BITES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dynamite wings'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009019, '3-4 pcs', FALSE), (400070009020, '5 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009019, '3-4 pcs', 150.00, FALSE), (400070009020, '5 pcs', 280.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009017, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Hot Honey Tenders', 'hot honey tenders', 'FRIED CHICKEN QUICK BITES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot honey tenders'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009021, '3-4 pcs', FALSE), (400070009022, '6 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009021, '3-4 pcs', 170.00, FALSE), (400070009022, '6 pcs', 320.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009018, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Dynamite Tenders', 'dynamite tenders', 'FRIED CHICKEN QUICK BITES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dynamite tenders'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009023, '3-4 pcs', FALSE), (400070009024, '5 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009023, '3-4 pcs', 180.00, FALSE), (400070009024, '5 pcs', 350.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "FRIED CHICKEN QUICK BITES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009019, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009003, 'Chicken Chizza', 'chicken chizza', 'FRIED CHICKEN QUICK BITES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009025, '3-4 pcs', FALSE), (400070009026, '5-6 pcs', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009025, '3-4 pcs', 190.00, FALSE), (400070009026, '5-6 pcs', 360.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "CHEESY GARLIC BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009020, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009004, 'Cheese Garlic Bread', 'cheese garlic bread', 'CHEESY GARLIC BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese garlic bread'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009027, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHEESY GARLIC BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009021, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009004, 'Veg Garlic Bread', 'veg garlic bread', 'CHEESY GARLIC BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg garlic bread'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009028, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHEESY GARLIC BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009022, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009004, 'Paneer Cheese Bread', 'paneer cheese bread', 'CHEESY GARLIC BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer cheese bread'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009029, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHEESY GARLIC BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009023, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009004, 'Chicken Cheese Bread', 'chicken cheese bread', 'CHEESY GARLIC BREAD', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cheese bread' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009030, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009024, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Shawarma Sandwich', 'chicken shawarma sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken shawarma sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009031, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009025, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Tandoori Sandwich', 'chicken tandoori sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tandoori sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009032, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009026, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Tikka Sandwich', 'chicken tikka sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009033, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009027, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Cheese Grill Sandwich', 'cheese grill sandwich', 'CHICKEN SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese grill sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009034, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009028, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Club Sandwich', 'club sandwich', 'CHICKEN SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'club sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009035, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009029, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Cheese Melting Sandwich', 'chicken cheese melting sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cheese melting sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009036, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009030, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Bbq Sandwich', 'chicken bbq sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken bbq sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009037, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009031, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Mayo Grill Sandwich', 'chicken mayo grill sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken mayo grill sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009038, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009032, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009005, 'Chicken Peri Peri Grill Sandwich', 'chicken peri peri grill sandwich', 'CHICKEN SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken peri peri grill sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009039, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009033, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009006, 'Aloo Tikki Burger', 'aloo tikki burger', 'VEG BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo tikki burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009040, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009034, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009006, 'Janata Spl. Burger', 'janata spl. burger', 'VEG BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata spl. burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009041, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009035, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009006, 'Crispy Paneer Burger', 'crispy paneer burger', 'VEG BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'crispy paneer burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009042, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009036, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Zinger Burger', 'zinger burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'zinger burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009043, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009037, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Zinger Burger With Cheese', 'zinger burger with cheese', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'zinger burger with cheese'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009044, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009038, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Grilled Chicken Burger', 'grilled chicken burger', 'CHICKEN BURGER', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'grilled chicken burger' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009045, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009039, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Hot Honey Burger', 'hot honey burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot honey burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009046, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009040, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Dynamite Burger', 'dynamite burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dynamite burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009047, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009041, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Jalapeno Burger', 'jalapeno burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jalapeno burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009048, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009042, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Jalapeno Burger With Cheese', 'jalapeno burger with cheese', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jalapeno burger with cheese'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009049, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009043, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Janata Spl. Burger', 'janata spl. burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata spl. burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009050, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009044, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Nugget Burger', 'nugget burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nugget burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009051, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009045, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Bbq Burger', 'bbq burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bbq burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009052, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009046, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Peri Peri Burger', 'peri peri burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peri peri burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009053, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009047, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Mexican Burger', 'mexican burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mexican burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009054, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN BURGER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009048, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009007, 'Schezwan Burger', 'schezwan burger', 'CHICKEN BURGER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009055, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009049, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Veg Cheese Pizza', 'veg cheese pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg cheese pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009056, 'Small', FALSE), (400070009057, 'Medium', FALSE), (400070009058, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009056, 'Small', 120.00, FALSE), (400070009057, 'Medium', 180.00, FALSE), (400070009058, 'Large', 280.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009050, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Margherita Pizza', 'margherita pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'margherita pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009059, 'Small', FALSE), (400070009060, 'Medium', FALSE), (400070009061, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009059, 'Small', 120.00, FALSE), (400070009060, 'Medium', 180.00, FALSE), (400070009061, 'Large', 280.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009051, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Hawaiian Pizza', 'hawaiian pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hawaiian pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009062, 'Small', FALSE), (400070009063, 'Medium', FALSE), (400070009064, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009062, 'Small', 150.00, FALSE), (400070009063, 'Medium', 200.00, FALSE), (400070009064, 'Large', 300.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009052, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Mexican Pizza', 'mexican pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mexican pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009065, 'Small', FALSE), (400070009066, 'Medium', FALSE), (400070009067, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009065, 'Small', 180.00, FALSE), (400070009066, 'Medium', 260.00, FALSE), (400070009067, 'Large', 370.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009053, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Paneer Makhani Pizza', 'paneer makhani pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer makhani pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009068, 'Small', FALSE), (400070009069, 'Medium', FALSE), (400070009070, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009068, 'Small', 170.00, FALSE), (400070009069, 'Medium', 240.00, FALSE), (400070009070, 'Large', 360.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009054, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Sweet Corn Pizza', 'sweet corn pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet corn pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009071, 'Small', FALSE), (400070009072, 'Medium', FALSE), (400070009073, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009071, 'Small', 150.00, FALSE), (400070009072, 'Medium', 250.00, FALSE), (400070009073, 'Large', 350.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070009055, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Baby Corn Pizza', 'baby corn pizza', 'VEG PIZZA', 'veg', 'split-veg-pizza-baby-corn-/-mashroom-pizza', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009074, 'Small', FALSE), (400070009075, 'Medium', FALSE), (400070009076, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009074, 'Small', 180.00, FALSE), (400070009075, 'Medium', 280.00, FALSE), (400070009076, 'Large', 380.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070009056, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Mashroom Pizza', 'mashroom pizza', 'VEG PIZZA', 'veg', 'split-veg-pizza-baby-corn-/-mashroom-pizza', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mashroom pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009077, 'Small', FALSE), (400070009078, 'Medium', FALSE), (400070009079, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009077, 'Small', 180.00, FALSE), (400070009078, 'Medium', 280.00, FALSE), (400070009079, 'Large', 380.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009057, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009080, 'Small', FALSE), (400070009081, 'Medium', FALSE), (400070009082, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009080, 'Small', 170.00, FALSE), (400070009081, 'Medium', 240.00, FALSE), (400070009082, 'Large', 360.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009058, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Veg Italian Pizza', 'veg italian pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg italian pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009083, 'Small', FALSE), (400070009084, 'Medium', FALSE), (400070009085, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009083, 'Small', 150.00, FALSE), (400070009084, 'Medium', 200.00, FALSE), (400070009085, 'Large', 300.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "VEG PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009059, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009008, 'Veg Melting Pizza', 'veg melting pizza', 'VEG PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg melting pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009086, 'Small', FALSE), (400070009087, 'Medium', FALSE), (400070009088, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009086, 'Small', 180.00, FALSE), (400070009087, 'Medium', 260.00, FALSE), (400070009088, 'Large', 370.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009060, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Cheese Pizza', 'chicken cheese pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cheese pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009089, 'Small', FALSE), (400070009090, 'Medium', FALSE), (400070009091, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009089, 'Small', 150.00, FALSE), (400070009090, 'Medium', 230.00, FALSE), (400070009091, 'Large', 320.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009061, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Tandoori Pizza', 'chicken tandoori pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tandoori pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009092, 'Small', FALSE), (400070009093, 'Medium', FALSE), (400070009094, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009092, 'Small', 160.00, FALSE), (400070009093, 'Medium', 230.00, FALSE), (400070009094, 'Large', 340.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009062, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Shawarma Pizza', 'chicken shawarma pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken shawarma pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009095, 'Small', FALSE), (400070009096, 'Medium', FALSE), (400070009097, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009095, 'Small', 180.00, FALSE), (400070009096, 'Medium', 260.00, FALSE), (400070009097, 'Large', 370.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009063, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Makrani Pizza', 'chicken makrani pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken makrani pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009098, 'Small', FALSE), (400070009099, 'Medium', FALSE), (400070009100, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009098, 'Small', 160.00, FALSE), (400070009099, 'Medium', 240.00, FALSE), (400070009100, 'Large', 360.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009064, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Tikka Pizza', 'chicken tikka pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009101, 'Small', FALSE), (400070009102, 'Medium', FALSE), (400070009103, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009101, 'Small', 170.00, FALSE), (400070009102, 'Medium', 260.00, FALSE), (400070009103, 'Large', 380.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009065, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Janata Spl. Pizza', 'janata spl. pizza', 'CHICKEN PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata spl. pizza'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009104, 'Small', FALSE), (400070009105, 'Medium', FALSE), (400070009106, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009104, 'Small', 190.00, FALSE), (400070009105, 'Medium', 290.00, FALSE), (400070009106, 'Large', 390.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009066, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Melting Pizza', 'chicken melting pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken melting pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009107, 'Small', FALSE), (400070009108, 'Medium', FALSE), (400070009109, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009107, 'Small', 180.00, FALSE), (400070009108, 'Medium', 260.00, FALSE), (400070009109, 'Large', 370.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009067, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Cassic Pizza', 'chicken cassic pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cassic pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009110, 'Small', FALSE), (400070009111, 'Medium', FALSE), (400070009112, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009110, 'Small', 170.00, FALSE), (400070009111, 'Medium', 260.00, FALSE), (400070009112, 'Large', 380.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009068, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Bbq Pizza', 'chicken bbq pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken bbq pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009113, 'Small', FALSE), (400070009114, 'Medium', FALSE), (400070009115, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009113, 'Small', 160.00, FALSE), (400070009114, 'Medium', 240.00, FALSE), (400070009115, 'Large', 360.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009069, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Nawabi Pizza', 'chicken nawabi pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken nawabi pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009116, 'Small', FALSE), (400070009117, 'Medium', FALSE), (400070009118, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009116, 'Small', 160.00, FALSE), (400070009117, 'Medium', 240.00, FALSE), (400070009118, 'Large', 360.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009070, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Chicken Popcorn Pizza', 'chicken popcorn pizza', 'CHICKEN PIZZA', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken popcorn pizza' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009119, 'Small', FALSE), (400070009120, 'Medium', FALSE), (400070009121, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009119, 'Small', 170.00, FALSE), (400070009120, 'Medium', 260.00, FALSE), (400070009121, 'Large', 380.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009071, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009009, 'Extra Cheese', 'extra cheese', 'CHICKEN PIZZA', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'extra cheese'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070009122, 'Small', FALSE), (400070009123, 'Medium', FALSE), (400070009124, 'Large', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070009122, 'Small', 60.00, FALSE), (400070009123, 'Medium', 100.00, FALSE), (400070009124, 'Large', 150.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009072, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Classic Shawarma', 'classic shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'classic shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009125, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009073, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Cheese Shawarma', 'cheese shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009126, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009074, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Peri-peri Shawarma', 'peri-peri shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peri-peri shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009127, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009075, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Peri-peri Cheese Shawarma', 'peri-peri cheese shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peri-peri cheese shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009128, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009076, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Rumali Shawarma', 'rumali shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rumali shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009129, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009077, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Rumali Cheese Shawarma', 'rumali cheese shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rumali cheese shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009130, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009078, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Open Shawarma', 'open shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'open shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009131, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009079, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Chicken Platter Salad', 'chicken platter salad', 'SHAWARMA', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken platter salad' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009132, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009080, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Bbq Shawarma', 'bbq shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bbq shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009133, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009081, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Zinger Shawarma', 'zinger shawarma', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'zinger shawarma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009134, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SHAWARMA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009082, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009010, 'Zinger Shawarma With Cheese', 'zinger shawarma with cheese', 'SHAWARMA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'zinger shawarma with cheese'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009135, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009083, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009011, 'Chicken Mayo Roll', 'chicken mayo roll', 'ROLL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken mayo roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009136, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009084, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009011, 'Chicken Tikka Roll', 'chicken tikka roll', 'ROLL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009137, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070009085, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009011, 'Chicken Barbeque Roll', 'chicken barbeque roll', 'ROLL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken barbeque roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009138, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRIED CHICKEN WRAP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009086, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009012, 'Mexican Wrap', 'mexican wrap', 'FRIED CHICKEN WRAP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mexican wrap'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009139, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRIED CHICKEN WRAP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009087, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009012, 'Popcorn Cheese Wrap', 'popcorn cheese wrap', 'FRIED CHICKEN WRAP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'popcorn cheese wrap'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009140, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRIED CHICKEN WRAP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009088, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009012, 'Tikka Wrap', 'tikka wrap', 'FRIED CHICKEN WRAP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tikka wrap'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009141, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRIED CHICKEN WRAP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009089, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009012, 'Nuggets Wrap', 'nuggets wrap', 'FRIED CHICKEN WRAP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nuggets wrap'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009142, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "COLD COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009090, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009013, 'Cold Coffee', 'cold coffee', 'COLD COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cold coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009143, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "COLD COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009091, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009013, 'Coffee On The Rocks', 'coffee on the rocks', 'COLD COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'coffee on the rocks'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009144, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "COLD COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009092, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009013, 'Sweet House Mafia', 'sweet house mafia', 'COLD COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet house mafia'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009145, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "COLD COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009093, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009013, 'Mud Coffee', 'mud coffee', 'COLD COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mud coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009146, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009094, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Falooda', 'falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009147, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009095, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Kesar Falooda', 'kesar falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009148, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009096, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Kulfi Falooda', 'kulfi falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulfi falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009149, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009149, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009097, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Delhi Style Falooda', 'delhi style falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'delhi style falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009150, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009098, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Janata Falooda', 'janata falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009151, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009099, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Royal Falooda', 'royal falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'royal falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009152, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009100, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Fruit Falooda', 'fruit falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009153, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009101, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Rabdi Dry Falooda', 'rabdi dry falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rabdi dry falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009154, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009102, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Dry Fruit Falooda', 'dry fruit falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dry fruit falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009155, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009103, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Vanilla Falooda', 'vanilla falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'vanilla falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009156, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009104, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009014, 'Malai Falooda', 'malai falooda', 'FALOODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009157, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009105, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009015, 'Sweet & Salty', 'sweet & salty', 'SODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet & salty'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009158, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009106, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009015, 'Sweet Soda', 'sweet soda', 'SODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet soda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009159, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SODA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009107, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009015, 'Salty', 'salty', 'SODA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'salty'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009160, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUD MILKSHAKE WITH ICECREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009108, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009016, 'Chocolate Mud', 'chocolate mud', 'MUD MILKSHAKE WITH ICECREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009161, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUD MILKSHAKE WITH ICECREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009109, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009016, 'Mango Mud', 'mango mud', 'MUD MILKSHAKE WITH ICECREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009162, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUD MILKSHAKE WITH ICECREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009110, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009016, 'Strawberry Mud', 'strawberry mud', 'MUD MILKSHAKE WITH ICECREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009163, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUD MILKSHAKE WITH ICECREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009111, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009016, 'Kit Kat Mud', 'kit kat mud', 'MUD MILKSHAKE WITH ICECREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kit kat mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009164, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUD MILKSHAKE WITH ICECREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009112, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009016, 'Oreo Mud', 'oreo mud', 'MUD MILKSHAKE WITH ICECREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'oreo mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009165, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUD MILKSHAKE WITH ICECREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009113, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009016, 'Janata Spl. Mud', 'janata spl. mud', 'MUD MILKSHAKE WITH ICECREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata spl. mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009166, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009114, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Arabic Pudding', 'arabic pudding', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'arabic pudding'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009167, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009115, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Caramel Custard', 'caramel custard', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'caramel custard'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009168, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009116, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Gulab Jamun', 'gulab jamun', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'gulab jamun'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009169, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009117, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Matka Rabdi', 'matka rabdi', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'matka rabdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009170, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009118, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Apricot Delight', 'apricot delight', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'apricot delight'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009171, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009119, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Lava Cake', 'lava cake', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lava cake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009172, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DESSERT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009120, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009017, 'Browni With Ice Cream', 'browni with ice cream', 'DESSERT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'browni with ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009173, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH CREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009121, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009018, 'Sitafal (seasonal)', 'sitafal (seasonal)', 'FRESH CREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sitafal (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009174, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH CREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009122, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009018, 'Strawberry (seasonal)', 'strawberry (seasonal)', 'FRESH CREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009175, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH CREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009123, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009018, 'Mix Fruit Cream', 'mix fruit cream', 'FRESH CREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fruit cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009176, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH CREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009124, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009018, 'Mulberry Cream', 'mulberry cream', 'FRESH CREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mulberry cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009177, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH CREAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009125, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009018, 'Mango (seasonal)', 'mango (seasonal)', 'FRESH CREAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009178, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009126, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Pineapple', 'pineapple', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009179, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009179, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009127, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Watermelon', 'watermelon', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'watermelon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009180, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009128, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Musk Melon', 'musk melon', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'musk melon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009181, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009129, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Orange', 'orange', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'orange'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009182, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009130, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Mango (seasonal)', 'mango (seasonal)', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009183, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009131, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Strawberry (seasonal)', 'strawberry (seasonal)', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009184, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009132, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Chikoo', 'chikoo', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chikoo'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009185, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009133, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Papaya', 'papaya', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'papaya'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009186, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009134, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Mosambi (sweet Lime)', 'mosambi (sweet lime)', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mosambi (sweet lime)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009187, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009135, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Fresh Lemon', 'fresh lemon', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fresh lemon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009188, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009136, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Moroccan Mint Lime', 'moroccan mint lime', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'moroccan mint lime'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009189, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009137, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Pomegranate (anar)', 'pomegranate (anar)', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pomegranate (anar)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009190, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009138, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Carrot', 'carrot', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'carrot'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009191, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009139, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Dragon', 'dragon', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dragon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009192, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009140, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Kiwi', 'kiwi', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kiwi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009193, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009141, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Mix', 'mix', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009194, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009142, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Beetroot', 'beetroot', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'beetroot'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009195, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009143, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Tender Coconut', 'tender coconut', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tender coconut'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009196, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009144, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Sitafal (custard Apple) (seasonal)', 'sitafal (custard apple) (seasonal)', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sitafal (custard apple) (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009197, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRESH JUICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009145, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009019, 'Ganga Jamuna (sweet Lime Orange + Pineapple)', 'ganga jamuna (sweet lime orange + pineapple)', 'FRESH JUICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ganga jamuna (sweet lime orange + pineapple)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009198, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NO ICE NO SUGAR NO WATER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009146, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009020, 'Cap- Carrot Apple Pineapple', 'cap- carrot apple pineapple', 'NO ICE NO SUGAR NO WATER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cap- carrot apple pineapple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009199, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NO ICE NO SUGAR NO WATER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009147, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009020, 'Abc Apple Beetroot Carrot', 'abc apple beetroot carrot', 'NO ICE NO SUGAR NO WATER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'abc apple beetroot carrot'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009200, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009148, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Sweet Lassi', 'sweet lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009201, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009149, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Fruit Lassi', 'fruit lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009202, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009150, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Mango Lassi', 'mango lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009203, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009151, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Banana Lassi', 'banana lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banana lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009204, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009152, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Strawberry Lassi', 'strawberry lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009205, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009153, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Dry Fruit Lassi', 'dry fruit lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dry fruit lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009206, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009154, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Saffron Lassi', 'saffron lassi', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'saffron lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009207, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "LASSI WASSI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009155, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009021, 'Buttermilk (chas)', 'buttermilk (chas)', 'LASSI WASSI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'buttermilk (chas)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009208, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009156, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Virgin Mojito', 'virgin mojito', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'virgin mojito'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009209, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009157, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Blue Lagoon', 'blue lagoon', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'blue lagoon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009210, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009158, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Water Melon', 'water melon', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'water melon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009211, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009159, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Green Apple', 'green apple', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green apple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009212, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009160, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Blue Berry', 'blue berry', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'blue berry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009213, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009161, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Berry Paper Shot', 'berry paper shot', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'berry paper shot'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009214, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009162, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Passion Fruit', 'passion fruit', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'passion fruit'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009215, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009163, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Mango Mojito', 'mango mojito', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango mojito'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009216, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAILS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009164, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009022, 'Strawberry Mojito', 'strawberry mojito', 'MOCKTAILS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry mojito'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009217, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009165, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Belgian Chocolate', 'belgian chocolate', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'belgian chocolate'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009218, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009166, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Oreo Shake', 'oreo shake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'oreo shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009219, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009167, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Ferrero Automatic', 'ferrero automatic', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ferrero automatic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009220, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009168, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Butter Scotch Shake', 'butter scotch shake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter scotch shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009221, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009169, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Pista Banana Milkshake', 'pista banana milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pista banana milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009222, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009170, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Banana Milk Shake', 'banana milk shake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banana milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009223, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009171, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Mango Banana Milkshake', 'mango banana milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango banana milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009224, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009172, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Nutella Shake', 'nutella shake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nutella shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009225, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009173, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Mango Strawberry', 'mango strawberry', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango strawberry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009226, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009174, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Very Berry Strawberry', 'very berry strawberry', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'very berry strawberry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009227, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009175, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Mango Milk Shake', 'mango milk shake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango milk shake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009228, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009176, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Tropical Mix Fruit', 'tropical mix fruit', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tropical mix fruit'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009229, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009177, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Musk Melon Milkshake', 'musk melon milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'musk melon milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009230, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009178, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Anjeer Milkshake', 'anjeer milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'anjeer milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009231, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009179, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Kaju Anjeer Milkshake', 'kaju anjeer milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju anjeer milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009232, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009180, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Avocado Milkshake', 'avocado milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'avocado milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009233, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009181, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Dragon Milkshake', 'dragon milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dragon milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009234, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009182, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Mix Dry Fruit Milkshake', 'mix dry fruit milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix dry fruit milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009235, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009183, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Kitkat Milkshake', 'kitkat milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kitkat milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009236, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009184, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Mississippi Mud', 'mississippi mud', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mississippi mud'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009237, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009185, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Khajoor Milkshake', 'khajoor milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khajoor milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009238, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009186, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Banana Khajoor Milkshake', 'banana khajoor milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banana khajoor milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009239, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009187, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Sitafal Milkshake (seasonal)', 'sitafal milkshake (seasonal)', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sitafal milkshake (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009240, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009188, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Iku Milkshake', 'iku milkshake', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'iku milkshake'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009241, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILKSHAKE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009189, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009023, 'Rose Milk', 'rose milk', 'MILKSHAKE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rose milk'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009242, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SMOOTHIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009190, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009024, 'Mango Smoothie', 'mango smoothie', 'SMOOTHIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango smoothie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009243, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SMOOTHIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009191, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009024, 'Blueberrie Smoothie', 'blueberrie smoothie', 'SMOOTHIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'blueberrie smoothie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009244, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SMOOTHIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009192, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009024, 'Banana Smoothie', 'banana smoothie', 'SMOOTHIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banana smoothie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009245, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SMOOTHIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009193, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009024, 'Strawberry Smoothie', 'strawberry smoothie', 'SMOOTHIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry smoothie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009246, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009194, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Janata Delight', 'janata delight', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata delight'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009247, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009195, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Caramel Moca Fudge', 'caramel moca fudge', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'caramel moca fudge'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009248, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009196, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Debit By Chocolate', 'debit by chocolate', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'debit by chocolate'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009249, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009197, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Nutella Fudges', 'nutella fudges', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nutella fudges'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009250, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009198, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Nutella Lychees', 'nutella lychees', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nutella lychees'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009251, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009199, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Nutella Brownies', 'nutella brownies', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nutella brownies'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009252, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009252, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009200, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Chocolate Fudges', 'chocolate fudges', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate fudges'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009253, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009253, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009201, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Mexican Brownie', 'mexican brownie', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mexican brownie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009254, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009202, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Fruit Salad Icecream', 'fruit salad icecream', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad icecream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009255, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009203, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Fruit And Cream', 'fruit and cream', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit and cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009256, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ICECREAM SUNDAE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070009204, ctx.restaurant_id, item_cd.canonical_dish_id, 400070009025, 'Fruit Overload', 'fruit overload', 'ICECREAM SUNDAE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit overload'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070009257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070009257, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
SELECT 400070009001, ctx.restaurant_id, 'Main Menu', 'a_la_carte' FROM khaustan_onboarding_ctx ctx;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT ctx.restaurant_id, 400070009001, x.menu_category_id, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070009001, 1), (400070009002, 2), (400070009003, 3), (400070009004, 4), (400070009005, 5), (400070009006, 6), (400070009007, 7), (400070009008, 8), (400070009009, 9), (400070009010, 10), (400070009011, 11), (400070009012, 12), (400070009013, 13), (400070009014, 14), (400070009015, 15), (400070009016, 16), (400070009017, 17), (400070009018, 18), (400070009019, 19), (400070009020, 20), (400070009021, 21), (400070009022, 22), (400070009023, 23), (400070009024, 24), (400070009025, 25)) AS x(menu_category_id, display_sequence);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence, is_featured)
SELECT x.menu_board_item_id, ctx.restaurant_id, 400070009001, x.menu_item_id, x.menu_category_id, x.display_sequence, x.is_featured
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070009001, 400070009001, 400070009001, 1, FALSE), (400070009002, 400070009002, 400070009001, 2, FALSE), (400070009003, 400070009003, 400070009001, 3, FALSE), (400070009004, 400070009004, 400070009001, 4, FALSE), (400070009005, 400070009005, 400070009001, 5, FALSE), (400070009006, 400070009006, 400070009002, 6, FALSE), (400070009007, 400070009007, 400070009002, 7, FALSE), (400070009008, 400070009008, 400070009002, 8, FALSE), (400070009009, 400070009009, 400070009002, 9, FALSE), (400070009010, 400070009010, 400070009002, 10, FALSE), (400070009011, 400070009011, 400070009002, 11, FALSE), (400070009012, 400070009012, 400070009002, 12, FALSE), (400070009013, 400070009013, 400070009003, 13, FALSE), (400070009014, 400070009014, 400070009003, 14, FALSE), (400070009015, 400070009015, 400070009003, 15, FALSE), (400070009016, 400070009016, 400070009003, 16, FALSE), (400070009017, 400070009017, 400070009003, 17, FALSE), (400070009018, 400070009018, 400070009003, 18, FALSE), (400070009019, 400070009019, 400070009003, 19, FALSE), (400070009020, 400070009020, 400070009004, 20, FALSE), (400070009021, 400070009021, 400070009004, 21, FALSE), (400070009022, 400070009022, 400070009004, 22, FALSE), (400070009023, 400070009023, 400070009004, 23, FALSE), (400070009024, 400070009024, 400070009005, 24, FALSE), (400070009025, 400070009025, 400070009005, 25, FALSE), (400070009026, 400070009026, 400070009005, 26, FALSE), (400070009027, 400070009027, 400070009005, 27, FALSE), (400070009028, 400070009028, 400070009005, 28, FALSE), (400070009029, 400070009029, 400070009005, 29, FALSE), (400070009030, 400070009030, 400070009005, 30, FALSE), (400070009031, 400070009031, 400070009005, 31, FALSE), (400070009032, 400070009032, 400070009005, 32, FALSE), (400070009033, 400070009033, 400070009006, 33, FALSE), (400070009034, 400070009034, 400070009006, 34, FALSE), (400070009035, 400070009035, 400070009006, 35, FALSE), (400070009036, 400070009036, 400070009007, 36, FALSE), (400070009037, 400070009037, 400070009007, 37, FALSE), (400070009038, 400070009038, 400070009007, 38, FALSE), (400070009039, 400070009039, 400070009007, 39, FALSE), (400070009040, 400070009040, 400070009007, 40, FALSE), (400070009041, 400070009041, 400070009007, 41, FALSE), (400070009042, 400070009042, 400070009007, 42, FALSE), (400070009043, 400070009043, 400070009007, 43, FALSE), (400070009044, 400070009044, 400070009007, 44, FALSE), (400070009045, 400070009045, 400070009007, 45, FALSE), (400070009046, 400070009046, 400070009007, 46, FALSE), (400070009047, 400070009047, 400070009007, 47, FALSE), (400070009048, 400070009048, 400070009007, 48, FALSE), (400070009049, 400070009049, 400070009008, 49, FALSE), (400070009050, 400070009050, 400070009008, 50, FALSE), (400070009051, 400070009051, 400070009008, 51, FALSE), (400070009052, 400070009052, 400070009008, 52, FALSE), (400070009053, 400070009053, 400070009008, 53, FALSE), (400070009054, 400070009054, 400070009008, 54, FALSE), (400070009055, 400070009055, 400070009008, 55, FALSE), (400070009056, 400070009056, 400070009008, 56, FALSE), (400070009057, 400070009057, 400070009008, 57, FALSE), (400070009058, 400070009058, 400070009008, 58, FALSE), (400070009059, 400070009059, 400070009008, 59, FALSE), (400070009060, 400070009060, 400070009009, 60, FALSE), (400070009061, 400070009061, 400070009009, 61, FALSE), (400070009062, 400070009062, 400070009009, 62, FALSE), (400070009063, 400070009063, 400070009009, 63, FALSE), (400070009064, 400070009064, 400070009009, 64, FALSE), (400070009065, 400070009065, 400070009009, 65, FALSE), (400070009066, 400070009066, 400070009009, 66, FALSE), (400070009067, 400070009067, 400070009009, 67, FALSE), (400070009068, 400070009068, 400070009009, 68, FALSE), (400070009069, 400070009069, 400070009009, 69, FALSE), (400070009070, 400070009070, 400070009009, 70, FALSE), (400070009071, 400070009071, 400070009009, 71, FALSE), (400070009072, 400070009072, 400070009010, 72, FALSE), (400070009073, 400070009073, 400070009010, 73, FALSE), (400070009074, 400070009074, 400070009010, 74, FALSE), (400070009075, 400070009075, 400070009010, 75, FALSE), (400070009076, 400070009076, 400070009010, 76, FALSE), (400070009077, 400070009077, 400070009010, 77, FALSE), (400070009078, 400070009078, 400070009010, 78, FALSE), (400070009079, 400070009079, 400070009010, 79, FALSE), (400070009080, 400070009080, 400070009010, 80, FALSE), (400070009081, 400070009081, 400070009010, 81, FALSE), (400070009082, 400070009082, 400070009010, 82, FALSE), (400070009083, 400070009083, 400070009011, 83, FALSE), (400070009084, 400070009084, 400070009011, 84, FALSE), (400070009085, 400070009085, 400070009011, 85, FALSE), (400070009086, 400070009086, 400070009012, 86, FALSE), (400070009087, 400070009087, 400070009012, 87, FALSE), (400070009088, 400070009088, 400070009012, 88, FALSE), (400070009089, 400070009089, 400070009012, 89, FALSE), (400070009090, 400070009090, 400070009013, 90, FALSE), (400070009091, 400070009091, 400070009013, 91, FALSE), (400070009092, 400070009092, 400070009013, 92, FALSE), (400070009093, 400070009093, 400070009013, 93, FALSE), (400070009094, 400070009094, 400070009014, 94, FALSE), (400070009095, 400070009095, 400070009014, 95, FALSE), (400070009096, 400070009096, 400070009014, 96, FALSE), (400070009097, 400070009097, 400070009014, 97, FALSE), (400070009098, 400070009098, 400070009014, 98, FALSE), (400070009099, 400070009099, 400070009014, 99, FALSE), (400070009100, 400070009100, 400070009014, 100, FALSE), (400070009101, 400070009101, 400070009014, 101, FALSE), (400070009102, 400070009102, 400070009014, 102, FALSE), (400070009103, 400070009103, 400070009014, 103, FALSE), (400070009104, 400070009104, 400070009014, 104, FALSE), (400070009105, 400070009105, 400070009015, 105, FALSE), (400070009106, 400070009106, 400070009015, 106, FALSE), (400070009107, 400070009107, 400070009015, 107, FALSE), (400070009108, 400070009108, 400070009016, 108, FALSE), (400070009109, 400070009109, 400070009016, 109, FALSE), (400070009110, 400070009110, 400070009016, 110, FALSE), (400070009111, 400070009111, 400070009016, 111, FALSE), (400070009112, 400070009112, 400070009016, 112, FALSE), (400070009113, 400070009113, 400070009016, 113, FALSE), (400070009114, 400070009114, 400070009017, 114, FALSE), (400070009115, 400070009115, 400070009017, 115, FALSE), (400070009116, 400070009116, 400070009017, 116, FALSE), (400070009117, 400070009117, 400070009017, 117, FALSE), (400070009118, 400070009118, 400070009017, 118, FALSE), (400070009119, 400070009119, 400070009017, 119, FALSE), (400070009120, 400070009120, 400070009017, 120, FALSE), (400070009121, 400070009121, 400070009018, 121, FALSE), (400070009122, 400070009122, 400070009018, 122, FALSE), (400070009123, 400070009123, 400070009018, 123, FALSE), (400070009124, 400070009124, 400070009018, 124, FALSE), (400070009125, 400070009125, 400070009018, 125, FALSE), (400070009126, 400070009126, 400070009019, 126, FALSE), (400070009127, 400070009127, 400070009019, 127, FALSE), (400070009128, 400070009128, 400070009019, 128, FALSE), (400070009129, 400070009129, 400070009019, 129, FALSE), (400070009130, 400070009130, 400070009019, 130, FALSE), (400070009131, 400070009131, 400070009019, 131, FALSE), (400070009132, 400070009132, 400070009019, 132, FALSE), (400070009133, 400070009133, 400070009019, 133, FALSE), (400070009134, 400070009134, 400070009019, 134, FALSE), (400070009135, 400070009135, 400070009019, 135, FALSE), (400070009136, 400070009136, 400070009019, 136, FALSE), (400070009137, 400070009137, 400070009019, 137, FALSE), (400070009138, 400070009138, 400070009019, 138, FALSE), (400070009139, 400070009139, 400070009019, 139, FALSE), (400070009140, 400070009140, 400070009019, 140, FALSE), (400070009141, 400070009141, 400070009019, 141, FALSE), (400070009142, 400070009142, 400070009019, 142, FALSE), (400070009143, 400070009143, 400070009019, 143, FALSE), (400070009144, 400070009144, 400070009019, 144, FALSE), (400070009145, 400070009145, 400070009019, 145, FALSE), (400070009146, 400070009146, 400070009020, 146, FALSE), (400070009147, 400070009147, 400070009020, 147, FALSE), (400070009148, 400070009148, 400070009021, 148, FALSE), (400070009149, 400070009149, 400070009021, 149, FALSE), (400070009150, 400070009150, 400070009021, 150, FALSE), (400070009151, 400070009151, 400070009021, 151, FALSE), (400070009152, 400070009152, 400070009021, 152, FALSE), (400070009153, 400070009153, 400070009021, 153, FALSE), (400070009154, 400070009154, 400070009021, 154, FALSE), (400070009155, 400070009155, 400070009021, 155, FALSE), (400070009156, 400070009156, 400070009022, 156, FALSE), (400070009157, 400070009157, 400070009022, 157, FALSE), (400070009158, 400070009158, 400070009022, 158, FALSE), (400070009159, 400070009159, 400070009022, 159, FALSE), (400070009160, 400070009160, 400070009022, 160, FALSE), (400070009161, 400070009161, 400070009022, 161, FALSE), (400070009162, 400070009162, 400070009022, 162, FALSE), (400070009163, 400070009163, 400070009022, 163, FALSE), (400070009164, 400070009164, 400070009022, 164, FALSE), (400070009165, 400070009165, 400070009023, 165, FALSE), (400070009166, 400070009166, 400070009023, 166, FALSE), (400070009167, 400070009167, 400070009023, 167, FALSE), (400070009168, 400070009168, 400070009023, 168, FALSE), (400070009169, 400070009169, 400070009023, 169, FALSE), (400070009170, 400070009170, 400070009023, 170, FALSE), (400070009171, 400070009171, 400070009023, 171, FALSE), (400070009172, 400070009172, 400070009023, 172, FALSE), (400070009173, 400070009173, 400070009023, 173, FALSE), (400070009174, 400070009174, 400070009023, 174, FALSE), (400070009175, 400070009175, 400070009023, 175, FALSE), (400070009176, 400070009176, 400070009023, 176, FALSE), (400070009177, 400070009177, 400070009023, 177, FALSE), (400070009178, 400070009178, 400070009023, 178, FALSE), (400070009179, 400070009179, 400070009023, 179, FALSE), (400070009180, 400070009180, 400070009023, 180, FALSE), (400070009181, 400070009181, 400070009023, 181, FALSE), (400070009182, 400070009182, 400070009023, 182, FALSE), (400070009183, 400070009183, 400070009023, 183, FALSE), (400070009184, 400070009184, 400070009023, 184, FALSE), (400070009185, 400070009185, 400070009023, 185, FALSE), (400070009186, 400070009186, 400070009023, 186, FALSE), (400070009187, 400070009187, 400070009023, 187, FALSE), (400070009188, 400070009188, 400070009023, 188, FALSE), (400070009189, 400070009189, 400070009023, 189, FALSE), (400070009190, 400070009190, 400070009024, 190, FALSE), (400070009191, 400070009191, 400070009024, 191, FALSE), (400070009192, 400070009192, 400070009024, 192, FALSE), (400070009193, 400070009193, 400070009024, 193, FALSE), (400070009194, 400070009194, 400070009025, 194, FALSE), (400070009195, 400070009195, 400070009025, 195, FALSE), (400070009196, 400070009196, 400070009025, 196, FALSE), (400070009197, 400070009197, 400070009025, 197, FALSE), (400070009198, 400070009198, 400070009025, 198, FALSE), (400070009199, 400070009199, 400070009025, 199, FALSE), (400070009200, 400070009200, 400070009025, 200, FALSE), (400070009201, 400070009201, 400070009025, 201, FALSE), (400070009202, 400070009202, 400070009025, 202, FALSE), (400070009203, 400070009203, 400070009025, 203, FALSE), (400070009204, 400070009204, 400070009025, 204, FALSE)) AS x(menu_board_item_id, menu_item_id, menu_category_id, display_sequence, is_featured);

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row with
-- verification_status_code = 'needs_review', one line each.
-- =============================================================================
-- NEEDS_REVIEW [0.70] "Veg Cheese Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Margherita Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Hawaiian Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Mexican Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Paneer Makhani Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Sweet Corn Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Baby Corn Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line. Additionally this line names two topping options separated by '/' ('Baby Corn / Mashroom') -- read as two separate pizzas sharing the same three prices, not one combined-topping pizza.
-- NEEDS_REVIEW [0.70] "Mashroom Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line. Additionally this line names two topping options separated by '/' ('Baby Corn / Mashroom') -- read as two separate pizzas sharing the same three prices, not one combined-topping pizza.
-- NEEDS_REVIEW [0.70] "Paneer Tikka Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Veg Italian Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Veg Melting Pizza" (VEG PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Cheese Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Tandoori Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Shawarma Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Makrani Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Tikka Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Janata Spl. Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Melting Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Cassic Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Bbq Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Nawabi Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Chicken Popcorn Pizza" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.
-- NEEDS_REVIEW [0.70] "Extra Cheese" (CHICKEN PIZZA): Three prices given with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large here by the standard convention for this kind of listing, at lower confidence since it isn't stated on this line.

-- =============================================================================
-- UNMAPPED: restaurant-level facts with no clean schema home, or deliberately
-- left for a human decision.
-- =============================================================================
-- UNMAPPED: restaurant.brand_id points to the SAME 'Janata' brand row as Janata Tawa & Grill (identify-or-create -- whichever of the two scripts runs first creates it; this one reuses it).
-- UNMAPPED: brand.website_url, if this script creates the brand row first, is set to Tawa & Grill's own domain (https://janatatawaandgrill.in/) rather than left blank, for consistency regardless of which script runs first -- this restaurant's own JSON gives no distinct brand domain of its own.
-- UNMAPPED: No schema column exists for an establishment or brand EMAIL address -- same gap as Tawa & Grill's script; janatarestaurantkurla@gmail.com has no home in this schema.
-- UNMAPPED: This JSON also names two OTHER Janata Fast Food locations (Jogeshwari, J.J. Junction) as separate physical premises -- out of scope for this task (only the Kurla listing, establishment_id 400070008, was requested) and not created here.
-- UNMAPPED: 'We Use Mineral Water For Our Preparation' and 'We Accept Party Orders' are restaurant-wide notes with no clean schema home -- preserved here verbatim rather than dropped.
-- UNMAPPED: Roughly 20 pizza-family items give three prices with no size label anywhere in the source (no 'Small/Medium/Large' or inch sizing stated) -- labeled Small/Medium/Large by the standard convention for this kind of listing, flagged needs_review since it isn't stated on the source lines themselves.
-- UNMAPPED: 'Baby Corn / Mashroom Pizza' read as two separate pizzas (a topping CHOICE) sharing the same three prices, not one combined-topping pizza -- 'Mashroom' kept verbatim (likely a source typo for 'Mushroom', not corrected here).
-- UNMAPPED: GST/tax fields on menu_item_price are left unset -- the source states no GST/tax convention.
