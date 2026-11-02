-- =============================================================================
-- Khaustan onboarding script: Janata Tawa & Grill
-- Source: janata_tawa_grill_menu.json (JSON)
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
--   restaurant_id     = 400070008 (hardcoded, per your instruction)
--   source_id         = 400070008
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
    VALUES (v_brand_id, 'Janata', lower(trim('Janata')), 'https://janatatawaandgrill.in/', 'https://www.youtube.com/@janatatawaandgrill');
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
    VALUES (v_establishment_id, 'Janata Restaurant Kurla', lower(trim('Janata Restaurant Kurla')), 'Shop No. 1/2/3/4 & 6, Rassi Wala Chawl, Near New Noor Hospital, L.B.S. Marg', 'Kurla (W)', '400070', 'Mumbai', 'Maharashtra', 'IN', 19.076408185504356, 72.87791609280546, 'www.janatarestaurantkurla.com', '@janatatawaandgrill', 'Janata Tawa & Grill');
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant WHERE restaurant_id = 400070008;

  IF NOT FOUND THEN
    v_restaurant_id := 400070008;
    INSERT INTO restaurant (restaurant_id, establishment_id, brand_id, display_name, normalized_name, has_bar, bar_license_type)
    VALUES (v_restaurant_id, 400070008, v_brand_id, 'Janata Tawa & Grill', lower(trim('Janata Tawa & Grill')), FALSE, 'none');
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
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'janata_tawa_grill_menu.json')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant. Aborting.', 'janata_tawa_grill_menu.json';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
SELECT 400070008, 'ai_menu_extraction', 'janata_tawa_grill_menu.json'
WHERE NOT EXISTS (SELECT 1 FROM source_record WHERE source_id = 400070008);
UPDATE khaustan_onboarding_ctx SET source_id = 400070008;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400070008001, ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx SET extraction_batch_id = 400070008001;

-- No phone numbers captured for this specific restaurant listing (see UNMAPPED notes).

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available)
SELECT ctx.restaurant_id, TRUE, FALSE FROM khaustan_onboarding_ctx ctx;

INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from)
SELECT 400070008001, ctx.restaurant_id, dp.delivery_provider_id, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM khaustan_onboarding_ctx ctx, delivery_provider dp
WHERE dp.provider_code = 'ZOMATO';

INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from)
SELECT 400070008002, ctx.restaurant_id, dp.delivery_provider_id, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM khaustan_onboarding_ctx ctx, delivery_provider dp
WHERE dp.provider_code = 'SWIGGY';

INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
SELECT 400070008001, ctx.restaurant_id, pt.tag_id, TRUE
FROM khaustan_onboarding_ctx ctx, platform_tag pt
WHERE pt.tag_code = 'halal';

INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
SELECT 400070008002, ctx.restaurant_id, pt.tag_id, TRUE
FROM khaustan_onboarding_ctx ctx, platform_tag pt
WHERE pt.tag_code = 'no_beef';

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name, batched
-- into one set-based statement (safe: normalized_name is the identity
-- key and the candidate list is de-duplicated before generation).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_dish_id, canonical_dish_name_id, canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    (400070008001, 400070008001, 'Chicken Tandoori', 'chicken tandoori', 'non_veg', 'CHICKEN'),
    (400070008002, 400070008002, 'Leg Piece', 'leg piece', 'veg', NULL),
    (400070008003, 400070008003, 'Lemon Tandoori', 'lemon tandoori', 'veg', NULL),
    (400070008004, 400070008004, 'Afghani Tandoori', 'afghani tandoori', 'veg', NULL),
    (400070008005, 400070008005, 'Makhmali Tandoori', 'makhmali tandoori', 'veg', NULL),
    (400070008006, 400070008006, 'Hara Bhara Tandoori', 'hara bhara tandoori', 'veg', NULL),
    (400070008007, 400070008007, 'Pomfret Tandoori', 'pomfret tandoori', 'non_veg', 'SEAFOOD'),
    (400070008008, 400070008008, 'Banjara Tandoori', 'banjara tandoori', 'veg', NULL),
    (400070008009, 400070008009, 'Janata Chicken Tandoori', 'janata chicken tandoori', 'non_veg', 'CHICKEN'),
    (400070008010, 400070008010, 'Bater Tandoori (2 Pcs)', 'bater tandoori (2 pcs)', 'non_veg', 'OTHER'),
    (400070008011, 400070008011, 'Paneer Tikka', 'paneer tikka', 'veg', NULL),
    (400070008012, 400070008012, 'Chicken Malai Tikka', 'chicken malai tikka', 'non_veg', 'CHICKEN'),
    (400070008013, 400070008013, 'Chicken Tikka', 'chicken tikka', 'non_veg', 'CHICKEN'),
    (400070008014, 400070008014, 'Chicken Reshmi Tikka', 'chicken reshmi tikka', 'non_veg', 'CHICKEN'),
    (400070008015, 400070008015, 'Chicken Pahadi Tikka', 'chicken pahadi tikka', 'non_veg', 'CHICKEN'),
    (400070008016, 400070008016, 'Chicken Garlic Tikka', 'chicken garlic tikka', 'non_veg', 'CHICKEN'),
    (400070008017, 400070008017, 'Chicken Zaffrani Tikka', 'chicken zaffrani tikka', 'non_veg', 'CHICKEN'),
    (400070008018, 400070008018, 'Chicken Dahi Lasooni Tikka', 'chicken dahi lasooni tikka', 'non_veg', 'CHICKEN'),
    (400070008019, 400070008019, 'Alu Tikka', 'alu tikka', 'veg', NULL),
    (400070008020, 400070008020, 'Prawns Tikka', 'prawns tikka', 'non_veg', 'SEAFOOD'),
    (400070008021, 400070008021, 'Chicken Burra', 'chicken burra', 'non_veg', 'CHICKEN'),
    (400070008022, 400070008022, 'Chicken Reshmi Tikka Burra', 'chicken reshmi tikka burra', 'non_veg', 'CHICKEN'),
    (400070008023, 400070008023, 'Chicken Tikka Burra', 'chicken tikka burra', 'non_veg', 'CHICKEN'),
    (400070008024, 400070008024, 'Mutton Burra (4 Pcs)', 'mutton burra (4 pcs)', 'non_veg', 'MUTTON'),
    (400070008025, 400070008025, 'Mutton Banjara Tandoori', 'mutton banjara tandoori', 'non_veg', 'MUTTON'),
    (400070008026, 400070008026, 'Mutton Tandoori', 'mutton tandoori', 'non_veg', 'MUTTON'),
    (400070008027, 400070008027, 'Mutton Kalimiri Tandoori', 'mutton kalimiri tandoori', 'non_veg', 'MUTTON'),
    (400070008028, 400070008028, 'Mutton Chaap (3 Pcs)', 'mutton chaap (3 pcs)', 'non_veg', 'MUTTON'),
    (400070008029, 400070008029, 'Mutton Chaap Burra', 'mutton chaap burra', 'non_veg', 'MUTTON'),
    (400070008030, 400070008030, 'Raan Burra', 'raan burra', 'non_veg', 'MUTTON'),
    (400070008031, 400070008031, 'Raan Banjara', 'raan banjara', 'non_veg', 'MUTTON'),
    (400070008032, 400070008032, 'Raan Kalimiri', 'raan kalimiri', 'non_veg', 'MUTTON'),
    (400070008033, 400070008033, 'Raan Tandoori', 'raan tandoori', 'non_veg', 'MUTTON'),
    (400070008034, 400070008034, 'Chicken Malai Drum (4 Pcs)', 'chicken malai drum (4 pcs)', 'non_veg', 'CHICKEN'),
    (400070008035, 400070008035, 'Chicken Tangdi Drum', 'chicken tangdi drum', 'non_veg', 'CHICKEN'),
    (400070008036, 400070008036, 'Chicken Reshmi Drum', 'chicken reshmi drum', 'non_veg', 'CHICKEN'),
    (400070008037, 400070008037, 'Chicken Adraki Tangdi', 'chicken adraki tangdi', 'non_veg', 'CHICKEN'),
    (400070008038, 400070008038, 'Chicken Seekh (4 Pcs)', 'chicken seekh (4 pcs)', 'non_veg', 'CHICKEN'),
    (400070008039, 400070008039, 'Chicken Irani Seekh', 'chicken irani seekh', 'non_veg', 'CHICKEN'),
    (400070008040, 400070008040, 'Chicken Malai Seekh', 'chicken malai seekh', 'non_veg', 'CHICKEN'),
    (400070008041, 400070008041, 'Chicken Cheese Seekh', 'chicken cheese seekh', 'non_veg', 'CHICKEN'),
    (400070008042, 400070008042, 'Mutton Seekh (4 Pcs)', 'mutton seekh (4 pcs)', 'non_veg', 'MUTTON'),
    (400070008043, 400070008043, 'Mutton Turkish Boti (6 Pcs)', 'mutton turkish boti (6 pcs)', 'non_veg', 'MUTTON'),
    (400070008044, 400070008044, 'Achari Kebab (6 Pcs)', 'achari kebab (6 pcs)', 'veg', NULL),
    (400070008045, 400070008045, 'Pudina Kebab', 'pudina kebab', 'veg', NULL),
    (400070008046, 400070008046, 'Banjara Keba', 'banjara keba', 'veg', NULL),
    (400070008047, 400070008047, 'Nawabi Kebab', 'nawabi kebab', 'veg', NULL),
    (400070008048, 400070008048, 'Kalimiri Kebab', 'kalimiri kebab', 'veg', NULL),
    (400070008049, 400070008049, 'Janata Chicken Platters', 'janata chicken platters', 'non_veg', 'CHICKEN'),
    (400070008050, 400070008050, 'Janata Chicken Tikka Platters', 'janata chicken tikka platters', 'non_veg', 'CHICKEN'),
    (400070008051, 400070008051, 'Janata Mutton Platters', 'janata mutton platters', 'non_veg', 'MUTTON'),
    (400070008052, 400070008052, 'Turkish Kebab', 'turkish kebab', 'veg', NULL),
    (400070008053, 400070008053, 'Chicken Peshawari', 'chicken peshawari', 'non_veg', 'CHICKEN'),
    (400070008054, 400070008054, 'Prawns Fry', 'prawns fry', 'non_veg', 'SEAFOOD'),
    (400070008055, 400070008055, 'Fish Fry', 'fish fry', 'non_veg', 'SEAFOOD'),
    (400070008056, 400070008056, 'Chicken Lasooni', 'chicken lasooni', 'non_veg', 'CHICKEN'),
    (400070008057, 400070008057, 'Chicken Lal Mirch', 'chicken lal mirch', 'non_veg', 'CHICKEN'),
    (400070008058, 400070008058, 'Golden Chicken', 'golden chicken', 'non_veg', 'CHICKEN'),
    (400070008059, 400070008059, 'Chicken Lamba', 'chicken lamba', 'non_veg', 'CHICKEN'),
    (400070008060, 400070008060, 'Chicken Hariyali', 'chicken hariyali', 'non_veg', 'CHICKEN'),
    (400070008061, 400070008061, 'Chicken Dryfruit', 'chicken dryfruit', 'non_veg', 'CHICKEN'),
    (400070008062, 400070008062, 'Chicken M.M', 'chicken m.m', 'non_veg', 'CHICKEN'),
    (400070008063, 400070008063, 'Chicken Tandoori Lasooni', 'chicken tandoori lasooni', 'non_veg', 'CHICKEN'),
    (400070008064, 400070008064, 'Chicken G.C.C.', 'chicken g.c.c.', 'non_veg', 'CHICKEN'),
    (400070008065, 400070008065, 'Chicken M.B.T.', 'chicken m.b.t.', 'non_veg', 'CHICKEN'),
    (400070008066, 400070008066, 'Chicken Superstar', 'chicken superstar', 'non_veg', 'CHICKEN'),
    (400070008067, 400070008067, 'Chicken Apple', 'chicken apple', 'non_veg', 'CHICKEN'),
    (400070008068, 400070008068, 'Chicken Sukka', 'chicken sukka', 'non_veg', 'CHICKEN'),
    (400070008069, 400070008069, 'Chicken Sultani', 'chicken sultani', 'non_veg', 'CHICKEN'),
    (400070008070, 400070008070, 'Chicken American', 'chicken american', 'non_veg', 'CHICKEN'),
    (400070008071, 400070008071, 'Chicken Koyla', 'chicken koyla', 'non_veg', 'CHICKEN'),
    (400070008072, 400070008072, 'Chicken Kalimiri', 'chicken kalimiri', 'non_veg', 'CHICKEN'),
    (400070008073, 400070008073, 'Chicken White Sauce', 'chicken white sauce', 'non_veg', 'CHICKEN'),
    (400070008074, 400070008074, 'Chicken Soup', 'chicken soup', 'non_veg', 'CHICKEN'),
    (400070008075, 400070008075, 'Chicken Changezi (gravy)', 'chicken changezi (gravy)', 'non_veg', 'CHICKEN'),
    (400070008076, 400070008076, 'Chicken Lapeta (gravy)', 'chicken lapeta (gravy)', 'non_veg', 'CHICKEN'),
    (400070008077, 400070008077, 'Chicken Handi (gravy)', 'chicken handi (gravy)', 'non_veg', 'CHICKEN'),
    (400070008078, 400070008078, 'Mutton Soup', 'mutton soup', 'non_veg', 'MUTTON'),
    (400070008079, 400070008079, 'Mutton Kalimiri (6 Pcs)', 'mutton kalimiri (6 pcs)', 'non_veg', 'MUTTON'),
    (400070008080, 400070008080, 'Mutton Sukka', 'mutton sukka', 'non_veg', 'MUTTON'),
    (400070008081, 400070008081, 'Mutton Chaap Kalimiri (3 Pcs)', 'mutton chaap kalimiri (3 pcs)', 'non_veg', 'MUTTON'),
    (400070008082, 400070008082, 'Mutton Changezi (gravy)', 'mutton changezi (gravy)', 'non_veg', 'MUTTON'),
    (400070008083, 400070008083, 'Mutton Lapeta (gravy)', 'mutton lapeta (gravy)', 'non_veg', 'MUTTON'),
    (400070008084, 400070008084, 'Mutton Handi (gravy)', 'mutton handi (gravy)', 'non_veg', 'MUTTON'),
    (400070008085, 400070008085, 'Mutton Kheema', 'mutton kheema', 'non_veg', 'MUTTON'),
    (400070008086, 400070008086, 'Paneer Lasooni', 'paneer lasooni', 'veg', NULL),
    (400070008087, 400070008087, 'Paneer Dryfruit', 'paneer dryfruit', 'veg', NULL),
    (400070008088, 400070008088, 'Paneer Hariyali', 'paneer hariyali', 'veg', NULL),
    (400070008089, 400070008089, 'Paneer Lal Mirch', 'paneer lal mirch', 'veg', NULL),
    (400070008090, 400070008090, 'Paneer American', 'paneer american', 'veg', NULL),
    (400070008091, 400070008091, 'Dal Khichdi', 'dal khichdi', 'veg', NULL),
    (400070008092, 400070008092, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'veg', NULL),
    (400070008093, 400070008093, 'Dal Fry', 'dal fry', 'veg', NULL),
    (400070008094, 400070008094, 'Dal Ghee', 'dal ghee', 'veg', NULL),
    (400070008095, 400070008095, 'Dal Tadka', 'dal tadka', 'veg', NULL),
    (400070008096, 400070008096, 'Steamed Rice', 'steamed rice', 'veg', NULL),
    (400070008097, 400070008097, 'Jeera Rice', 'jeera rice', 'veg', NULL),
    (400070008098, 400070008098, 'Chicken Mughlai Kepsa', 'chicken mughlai kepsa', 'non_veg', 'CHICKEN'),
    (400070008099, 400070008099, 'Mutton Mughlai Kepsa', 'mutton mughlai kepsa', 'non_veg', 'MUTTON'),
    (400070008100, 400070008100, 'Bheja Masala', 'bheja masala', 'non_veg', 'MUTTON'),
    (400070008101, 400070008101, 'Gurda Masala', 'gurda masala', 'non_veg', 'MUTTON'),
    (400070008102, 400070008102, 'Kaleji Masala', 'kaleji masala', 'non_veg', 'MUTTON'),
    (400070008103, 400070008103, 'Bheja Gurda Masala', 'bheja gurda masala', 'non_veg', 'MUTTON'),
    (400070008104, 400070008104, 'Gurda Kaleji Masala', 'gurda kaleji masala', 'non_veg', 'MUTTON'),
    (400070008105, 400070008105, 'Bheja Kaleji Masala', 'bheja kaleji masala', 'non_veg', 'MUTTON'),
    (400070008106, 400070008106, 'Bheja Plain Fry (2 Pcs.)', 'bheja plain fry (2 pcs.)', 'non_veg', 'MUTTON'),
    (400070008107, 400070008107, 'Kaleji Plain Fry', 'kaleji plain fry', 'non_veg', 'MUTTON'),
    (400070008108, 400070008108, 'Gurda Plain Fry (6 Pcs)', 'gurda plain fry (6 pcs)', 'non_veg', 'MUTTON'),
    (400070008109, 400070008109, 'Katakat Masala (bheja Gurda Kaleji)', 'katakat masala (bheja gurda kaleji)', 'non_veg', 'MUTTON'),
    (400070008110, 400070008110, 'Takatak Masala (bheja Gurda Kaleji Mutton)', 'takatak masala (bheja gurda kaleji mutton)', 'non_veg', 'MUTTON'),
    (400070008111, 400070008111, 'Double Bheja Masala', 'double bheja masala', 'non_veg', 'MUTTON'),
    (400070008112, 400070008112, 'Double Gurda Masala', 'double gurda masala', 'non_veg', 'MUTTON'),
    (400070008113, 400070008113, 'Prawns Tawa Fry', 'prawns tawa fry', 'non_veg', 'SEAFOOD'),
    (400070008114, 400070008114, 'Fish Tawa Fry', 'fish tawa fry', 'non_veg', 'SEAFOOD'),
    (400070008115, 400070008115, 'Pomfret Tawa Fry', 'pomfret tawa fry', 'non_veg', 'SEAFOOD'),
    (400070008116, 400070008116, 'Mutton Tawa Fry', 'mutton tawa fry', 'non_veg', 'MUTTON'),
    (400070008117, 400070008117, 'Tawa Khurchan (boneless)', 'tawa khurchan (boneless)', 'veg', NULL),
    (400070008118, 400070008118, 'Chicken Tawa Lajawab', 'chicken tawa lajawab', 'non_veg', 'CHICKEN'),
    (400070008119, 400070008119, 'Chicken Boti Masala', 'chicken boti masala', 'non_veg', 'CHICKEN'),
    (400070008120, 400070008120, 'Chicken Tikka Masala (boneless)', 'chicken tikka masala (boneless)', 'non_veg', 'CHICKEN'),
    (400070008121, 400070008121, 'Hyderabadi Chicken (boneless)', 'hyderabadi chicken (boneless)', 'non_veg', 'CHICKEN'),
    (400070008122, 400070008122, 'Chicken Kolhapuri', 'chicken kolhapuri', 'non_veg', 'CHICKEN'),
    (400070008123, 400070008123, 'Chicken Bhuna (boneless)', 'chicken bhuna (boneless)', 'non_veg', 'CHICKEN'),
    (400070008124, 400070008124, 'Chicken Patiyala', 'chicken patiyala', 'non_veg', 'CHICKEN'),
    (400070008125, 400070008125, 'Butter Chicken (boneless)', 'butter chicken (boneless)', 'non_veg', 'CHICKEN'),
    (400070008126, 400070008126, 'Chicken Dopyaza (boneless)', 'chicken dopyaza (boneless)', 'non_veg', 'CHICKEN'),
    (400070008127, 400070008127, 'Chicken Angara', 'chicken angara', 'non_veg', 'CHICKEN'),
    (400070008128, 400070008128, 'Chicken Rara', 'chicken rara', 'non_veg', 'CHICKEN'),
    (400070008129, 400070008129, 'Chicken Malwani', 'chicken malwani', 'non_veg', 'CHICKEN'),
    (400070008130, 400070008130, 'Chicken Charbaug', 'chicken charbaug', 'non_veg', 'CHICKEN'),
    (400070008131, 400070008131, 'Matka Chicken (gravy)', 'matka chicken (gravy)', 'non_veg', 'CHICKEN'),
    (400070008132, 400070008132, 'Janata (gravy Boneless)', 'janata (gravy boneless)', 'veg', NULL),
    (400070008133, 400070008133, 'Afgani Masala (boneless)', 'afgani masala (boneless)', 'veg', NULL),
    (400070008134, 400070008134, 'Chicken Chatpata (boneless)', 'chicken chatpata (boneless)', 'non_veg', 'CHICKEN'),
    (400070008135, 400070008135, 'Tandoori Masala', 'tandoori masala', 'veg', NULL),
    (400070008136, 400070008136, 'Murgi Musallam', 'murgi musallam', 'non_veg', 'CHICKEN'),
    (400070008137, 400070008137, 'Chicken Lazeez (boneless)', 'chicken lazeez (boneless)', 'non_veg', 'CHICKEN'),
    (400070008138, 400070008138, 'Chicken Lahori', 'chicken lahori', 'non_veg', 'CHICKEN'),
    (400070008139, 400070008139, 'Prawns Tawa Masala', 'prawns tawa masala', 'non_veg', 'SEAFOOD'),
    (400070008140, 400070008140, 'Fish Tawa Masala', 'fish tawa masala', 'non_veg', 'SEAFOOD'),
    (400070008141, 400070008141, 'Pomfret Tawa Masala', 'pomfret tawa masala', 'non_veg', 'SEAFOOD'),
    (400070008142, 400070008142, 'Prawns Khada Masala', 'prawns khada masala', 'non_veg', 'SEAFOOD'),
    (400070008143, 400070008143, 'Fish Khada Masala', 'fish khada masala', 'non_veg', 'SEAFOOD'),
    (400070008144, 400070008144, 'Pomfret Khada Masala', 'pomfret khada masala', 'non_veg', 'SEAFOOD'),
    (400070008145, 400070008145, 'Mutton Lajawab', 'mutton lajawab', 'non_veg', 'MUTTON'),
    (400070008146, 400070008146, 'Mutton Bhuna (boneless)', 'mutton bhuna (boneless)', 'non_veg', 'MUTTON'),
    (400070008147, 400070008147, 'Mutton Palak Gosht', 'mutton palak gosht', 'non_veg', 'MUTTON'),
    (400070008148, 400070008148, 'Mutton Rara', 'mutton rara', 'non_veg', 'MUTTON'),
    (400070008149, 400070008149, 'Mutton Boti Masala', 'mutton boti masala', 'non_veg', 'MUTTON'),
    (400070008150, 400070008150, 'Mutton Khada Masala', 'mutton khada masala', 'non_veg', 'MUTTON'),
    (400070008151, 400070008151, 'Mutton Dopyaza', 'mutton dopyaza', 'non_veg', 'MUTTON'),
    (400070008152, 400070008152, 'Mutton Maharaja', 'mutton maharaja', 'non_veg', 'MUTTON'),
    (400070008153, 400070008153, 'Mutton Malvani', 'mutton malvani', 'non_veg', 'MUTTON'),
    (400070008154, 400070008154, 'Mutton Patiyala', 'mutton patiyala', 'non_veg', 'MUTTON'),
    (400070008155, 400070008155, 'Mutton Lazeez', 'mutton lazeez', 'non_veg', 'MUTTON'),
    (400070008156, 400070008156, 'Mutton Lahori', 'mutton lahori', 'non_veg', 'MUTTON'),
    (400070008157, 400070008157, 'Mutton Raan Masala', 'mutton raan masala', 'non_veg', 'MUTTON'),
    (400070008158, 400070008158, 'Mutton Tawa Khurchan (boneless)', 'mutton tawa khurchan (boneless)', 'non_veg', 'MUTTON'),
    (400070008159, 400070008159, 'Mutton Chaap Masala (3 Pcs)', 'mutton chaap masala (3 pcs)', 'non_veg', 'MUTTON'),
    (400070008160, 400070008160, 'Veg Kolhapuri', 'veg kolhapuri', 'veg', NULL),
    (400070008161, 400070008161, 'Matar Mushroom Masala', 'matar mushroom masala', 'veg', NULL),
    (400070008162, 400070008162, 'Mix Vegetable Masala', 'mix vegetable masala', 'veg', NULL),
    (400070008163, 400070008163, 'Matar Paneer Masala', 'matar paneer masala', 'veg', NULL),
    (400070008164, 400070008164, 'Paneer Lajawab', 'paneer lajawab', 'veg', NULL),
    (400070008165, 400070008165, 'Paneer Masala', 'paneer masala', 'veg', NULL),
    (400070008166, 400070008166, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'veg', NULL),
    (400070008167, 400070008167, 'Paneer Khada Masala', 'paneer khada masala', 'veg', NULL),
    (400070008168, 400070008168, 'Paneer Afghani Masala', 'paneer afghani masala', 'veg', NULL),
    (400070008169, 400070008169, 'Paneer Lazeez', 'paneer lazeez', 'veg', NULL),
    (400070008170, 400070008170, 'Paneer Chatpata', 'paneer chatpata', 'veg', NULL),
    (400070008171, 400070008171, 'Paneer Khurchan', 'paneer khurchan', 'veg', NULL),
    (400070008172, 400070008172, 'Paneer Lahori', 'paneer lahori', 'veg', NULL),
    (400070008173, 400070008173, 'Chicken Tikka Pulav', 'chicken tikka pulav', 'non_veg', 'CHICKEN'),
    (400070008174, 400070008174, 'Chicken Pulav', 'chicken pulav', 'non_veg', 'CHICKEN'),
    (400070008175, 400070008175, 'Mutton Pulav', 'mutton pulav', 'non_veg', 'MUTTON'),
    (400070008176, 400070008176, 'Double Bheja Pulav', 'double bheja pulav', 'non_veg', 'MUTTON'),
    (400070008177, 400070008177, 'Double Gurda Pulav', 'double gurda pulav', 'non_veg', 'MUTTON'),
    (400070008178, 400070008178, 'Katakat Pulav (bheja Gurda Kaleji)', 'katakat pulav (bheja gurda kaleji)', 'non_veg', 'MUTTON'),
    (400070008179, 400070008179, 'Takatak Pulav (bheja Gurda Kaleji Mutton)', 'takatak pulav (bheja gurda kaleji mutton)', 'non_veg', 'MUTTON'),
    (400070008180, 400070008180, 'Bheja Pulav', 'bheja pulav', 'non_veg', 'MUTTON'),
    (400070008181, 400070008181, 'Mutton Kheema Bheja Pulav', 'mutton kheema bheja pulav', 'non_veg', 'MUTTON'),
    (400070008182, 400070008182, 'Mutton Kheema Pulav', 'mutton kheema pulav', 'non_veg', 'MUTTON'),
    (400070008183, 400070008183, 'Bheja Gurda Pulav', 'bheja gurda pulav', 'non_veg', 'MUTTON'),
    (400070008184, 400070008184, 'Kaleji Bheja Pulav', 'kaleji bheja pulav', 'non_veg', 'MUTTON'),
    (400070008185, 400070008185, 'Gurda Kaleji Pulav', 'gurda kaleji pulav', 'non_veg', 'MUTTON'),
    (400070008186, 400070008186, 'Gurda Pulav', 'gurda pulav', 'non_veg', 'MUTTON'),
    (400070008187, 400070008187, 'Kaleji Pulav', 'kaleji pulav', 'non_veg', 'MUTTON'),
    (400070008188, 400070008188, 'Chicken Tawa Biryani', 'chicken tawa biryani', 'non_veg', 'CHICKEN'),
    (400070008189, 400070008189, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'non_veg', 'CHICKEN'),
    (400070008190, 400070008190, 'Mutton Afghani Pulav', 'mutton afghani pulav', 'non_veg', 'MUTTON'),
    (400070008191, 400070008191, 'Mutton Masoor Pulav', 'mutton masoor pulav', 'non_veg', 'MUTTON'),
    (400070008192, 400070008192, 'Zamzam Pulav', 'zamzam pulav', 'veg', NULL),
    (400070008193, 400070008193, 'Chicken Afghani Pulav', 'chicken afghani pulav', 'non_veg', 'CHICKEN'),
    (400070008194, 400070008194, 'Prawns Pulav', 'prawns pulav', 'non_veg', 'SEAFOOD'),
    (400070008195, 400070008195, 'Mutton Tawa Biryani', 'mutton tawa biryani', 'non_veg', 'MUTTON'),
    (400070008196, 400070008196, 'Chicken Tawa Kepsa', 'chicken tawa kepsa', 'non_veg', 'CHICKEN'),
    (400070008197, 400070008197, 'Mutton Tawa Kepsa', 'mutton tawa kepsa', 'non_veg', 'MUTTON'),
    (400070008198, 400070008198, 'Mutton Raan Biryani', 'mutton raan biryani', 'non_veg', 'MUTTON'),
    (400070008199, 400070008199, 'Veg. Pulav', 'veg. pulav', 'veg', NULL),
    (400070008200, 400070008200, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'veg', NULL),
    (400070008201, 400070008201, 'Veg. Biryani', 'veg. biryani', 'veg', NULL),
    (400070008202, 400070008202, 'Janata Chicken Soup', 'janata chicken soup', 'non_veg', 'CHICKEN'),
    (400070008203, 400070008203, 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'non_veg', 'CHICKEN'),
    (400070008204, 400070008204, 'Chicken Manchow Soup', 'chicken manchow soup', 'non_veg', 'CHICKEN'),
    (400070008205, 400070008205, 'Chicken Hakka Soup', 'chicken hakka soup', 'non_veg', 'CHICKEN'),
    (400070008206, 400070008206, 'Wonton Clear Soup', 'wonton clear soup', 'veg', NULL),
    (400070008207, 400070008207, 'Chicken Oriental Soup', 'chicken oriental soup', 'non_veg', 'CHICKEN'),
    (400070008208, 400070008208, 'Chicken Tom Yum Soup', 'chicken tom yum soup', 'non_veg', 'CHICKEN'),
    (400070008209, 400070008209, 'Chicken Talumein Soup', 'chicken talumein soup', 'non_veg', 'CHICKEN'),
    (400070008210, 400070008210, 'Meat Bowl Soup', 'meat bowl soup', 'veg', NULL),
    (400070008211, 400070008211, 'Chicken Sweet Corn Soup', 'chicken sweet corn soup', 'non_veg', 'CHICKEN'),
    (400070008212, 400070008212, 'Chicken Garlic Soup', 'chicken garlic soup', 'non_veg', 'CHICKEN'),
    (400070008213, 400070008213, 'Chicken Clear Soup', 'chicken clear soup', 'non_veg', 'CHICKEN'),
    (400070008214, 400070008214, 'Chicken Lung Fung Soup', 'chicken lung fung soup', 'non_veg', 'CHICKEN'),
    (400070008215, 400070008215, 'Schezwan Tandoori', 'schezwan tandoori', 'veg', NULL),
    (400070008216, 400070008216, 'Janata Chicken Chilli', 'janata chicken chilli', 'non_veg', 'CHICKEN'),
    (400070008217, 400070008217, 'Chicken Crispy', 'chicken crispy', 'non_veg', 'CHICKEN'),
    (400070008218, 400070008218, 'Chicken Lollipop (8pcs)', 'chicken lollipop (8pcs)', 'non_veg', 'CHICKEN'),
    (400070008219, 400070008219, 'Chicken Lollipop (4pcs)', 'chicken lollipop (4pcs)', 'non_veg', 'CHICKEN'),
    (400070008220, 400070008220, 'Schezwan Lollipop (8pcs)', 'schezwan lollipop (8pcs)', 'veg', NULL),
    (400070008221, 400070008221, 'Schezwan Lollipop (4pcs)', 'schezwan lollipop (4pcs)', 'veg', NULL),
    (400070008222, 400070008222, 'Oyster Chicken', 'oyster chicken', 'non_veg', 'CHICKEN'),
    (400070008223, 400070008223, 'Chicken Chilli', 'chicken chilli', 'non_veg', 'CHICKEN'),
    (400070008224, 400070008224, 'Chicken Manchurian', 'chicken manchurian', 'non_veg', 'CHICKEN'),
    (400070008225, 400070008225, 'Schezwan Chicken', 'schezwan chicken', 'non_veg', 'CHICKEN'),
    (400070008226, 400070008226, 'Chicken Barbeque Sauce', 'chicken barbeque sauce', 'non_veg', 'CHICKEN'),
    (400070008227, 400070008227, 'Lemon Chicken', 'lemon chicken', 'non_veg', 'CHICKEN'),
    (400070008228, 400070008228, 'Chicken 65', 'chicken 65', 'non_veg', 'CHICKEN'),
    (400070008229, 400070008229, 'Dragon Chicken', 'dragon chicken', 'non_veg', 'CHICKEN'),
    (400070008230, 400070008230, 'Chicken Hunan', 'chicken hunan', 'non_veg', 'CHICKEN'),
    (400070008231, 400070008231, 'Chicken Kung Pao', 'chicken kung pao', 'non_veg', 'CHICKEN'),
    (400070008232, 400070008232, 'Hot Garlic', 'hot garlic', 'veg', NULL),
    (400070008233, 400070008233, 'Sweet Garlic', 'sweet garlic', 'veg', NULL),
    (400070008234, 400070008234, 'Chicken Green Chilli', 'chicken green chilli', 'non_veg', 'CHICKEN'),
    (400070008235, 400070008235, 'Chicken Black Pepper Sauce', 'chicken black pepper sauce', 'non_veg', 'CHICKEN'),
    (400070008236, 400070008236, 'Chicken Ginger', 'chicken ginger', 'non_veg', 'CHICKEN'),
    (400070008237, 400070008237, 'Chicken Dragon', 'chicken dragon', 'non_veg', 'CHICKEN'),
    (400070008238, 400070008238, 'Chicken Spring Roll', 'chicken spring roll', 'non_veg', 'CHICKEN'),
    (400070008239, 400070008239, 'Thread Chicken', 'thread chicken', 'non_veg', 'CHICKEN'),
    (400070008240, 400070008240, 'Hunan Chicken', 'hunan chicken', 'non_veg', 'CHICKEN'),
    (400070008241, 400070008241, 'Chicken Black', 'chicken black', 'non_veg', 'CHICKEN'),
    (400070008242, 400070008242, 'Chicken Kepsa Rice (hunan/chilli/manchurian)', 'chicken kepsa rice (hunan/chilli/manchurian)', 'non_veg', 'CHICKEN'),
    (400070008243, 400070008243, 'Mutton Kepsa Rice (hunan/chilli/manchurian)', 'mutton kepsa rice (hunan/chilli/manchurian)', 'non_veg', 'MUTTON'),
    (400070008244, 400070008244, 'Janata Rice (gravy)', 'janata rice (gravy)', 'veg', NULL),
    (400070008245, 400070008245, 'Mix Fried Rice', 'mix fried rice', 'veg', NULL),
    (400070008246, 400070008246, 'Malaysian Rice (gravy)', 'malaysian rice (gravy)', 'veg', NULL),
    (400070008247, 400070008247, 'Chicken Pot Rice', 'chicken pot rice', 'non_veg', 'CHICKEN'),
    (400070008248, 400070008248, 'Oyster Chilli Rice (gravy)', 'oyster chilli rice (gravy)', 'veg', NULL),
    (400070008249, 400070008249, 'Chicken Dragon Rice', 'chicken dragon rice', 'non_veg', 'CHICKEN'),
    (400070008250, 400070008250, 'Leg Rice (boneless)', 'leg rice (boneless)', 'veg', NULL),
    (400070008251, 400070008251, 'Chicken Triple Rice (gravy)', 'chicken triple rice (gravy)', 'non_veg', 'CHICKEN'),
    (400070008252, 400070008252, 'Chicken Tandoori Fried Rice', 'chicken tandoori fried rice', 'non_veg', 'CHICKEN'),
    (400070008253, 400070008253, 'Chicken Chilli Rice (gravy)', 'chicken chilli rice (gravy)', 'non_veg', 'CHICKEN'),
    (400070008254, 400070008254, 'Chicken Manchurian Rice (gravy)', 'chicken manchurian rice (gravy)', 'non_veg', 'CHICKEN'),
    (400070008255, 400070008255, 'Chicken Singapore Rice', 'chicken singapore rice', 'non_veg', 'CHICKEN'),
    (400070008256, 400070008256, 'Chicken Hong Kong Rice', 'chicken hong kong rice', 'non_veg', 'CHICKEN'),
    (400070008257, 400070008257, 'Chicken Korean Rice', 'chicken korean rice', 'non_veg', 'CHICKEN'),
    (400070008258, 400070008258, 'Chicken Combination Rice', 'chicken combination rice', 'non_veg', 'CHICKEN'),
    (400070008259, 400070008259, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'non_veg', 'CHICKEN'),
    (400070008260, 400070008260, 'Chicken Fried Rice', 'chicken fried rice', 'non_veg', 'CHICKEN'),
    (400070008261, 400070008261, 'Burn Garlic Rice', 'burn garlic rice', 'veg', NULL),
    (400070008262, 400070008262, 'Egg Fried Rice', 'egg fried rice', 'veg', NULL),
    (400070008263, 400070008263, 'Janata Chicken Noodles (gravy)', 'janata chicken noodles (gravy)', 'non_veg', 'CHICKEN'),
    (400070008264, 400070008264, 'Chicken Manchurian Noodles (gravy)', 'chicken manchurian noodles (gravy)', 'non_veg', 'CHICKEN'),
    (400070008265, 400070008265, 'Chicken Triple Noodles (gravy)', 'chicken triple noodles (gravy)', 'non_veg', 'CHICKEN'),
    (400070008266, 400070008266, 'Chicken Chilli Noodles (gravy)', 'chicken chilli noodles (gravy)', 'non_veg', 'CHICKEN'),
    (400070008267, 400070008267, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'non_veg', 'CHICKEN'),
    (400070008268, 400070008268, 'Chicken Singapore Noodles', 'chicken singapore noodles', 'non_veg', 'CHICKEN'),
    (400070008269, 400070008269, 'Chicken Hong Kong Noodles', 'chicken hong kong noodles', 'non_veg', 'CHICKEN'),
    (400070008270, 400070008270, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'non_veg', 'CHICKEN'),
    (400070008271, 400070008271, 'Burn Garlic Noodles', 'burn garlic noodles', 'veg', NULL),
    (400070008272, 400070008272, 'Pan Fried Noodles (gravy)', 'pan fried noodles (gravy)', 'veg', NULL),
    (400070008273, 400070008273, 'American Chop Suey', 'american chop suey', 'veg', NULL),
    (400070008274, 400070008274, 'Chinese Chop Suey', 'chinese chop suey', 'veg', NULL),
    (400070008275, 400070008275, 'Chowmin Chop Suey', 'chowmin chop suey', 'veg', NULL),
    (400070008276, 400070008276, 'Prawns Oyster Sauce', 'prawns oyster sauce', 'non_veg', 'SEAFOOD'),
    (400070008277, 400070008277, 'Fish Oyster Sauce', 'fish oyster sauce', 'non_veg', 'SEAFOOD'),
    (400070008278, 400070008278, 'Prawns Barbeque Sauce', 'prawns barbeque sauce', 'non_veg', 'SEAFOOD'),
    (400070008279, 400070008279, 'Fish Barbeque Sauce', 'fish barbeque sauce', 'non_veg', 'SEAFOOD'),
    (400070008280, 400070008280, 'Prawns Chilli', 'prawns chilli', 'non_veg', 'SEAFOOD'),
    (400070008281, 400070008281, 'Fish Chilli', 'fish chilli', 'non_veg', 'SEAFOOD'),
    (400070008282, 400070008282, 'Prawns Manchurian', 'prawns manchurian', 'non_veg', 'SEAFOOD'),
    (400070008283, 400070008283, 'Fish Manchurian', 'fish manchurian', 'non_veg', 'SEAFOOD'),
    (400070008284, 400070008284, 'Prawns Butter Garlic', 'prawns butter garlic', 'non_veg', 'SEAFOOD'),
    (400070008285, 400070008285, 'Fish Butter Garlic', 'fish butter garlic', 'non_veg', 'SEAFOOD'),
    (400070008286, 400070008286, 'Prawns Sweet Garlic', 'prawns sweet garlic', 'non_veg', 'SEAFOOD'),
    (400070008287, 400070008287, 'Fish Sweet Garlic', 'fish sweet garlic', 'non_veg', 'SEAFOOD'),
    (400070008288, 400070008288, 'Prawns Hot Garlic', 'prawns hot garlic', 'non_veg', 'SEAFOOD'),
    (400070008289, 400070008289, 'Fish Hot Garlic', 'fish hot garlic', 'non_veg', 'SEAFOOD'),
    (400070008290, 400070008290, 'Prawns Schezwan', 'prawns schezwan', 'non_veg', 'SEAFOOD'),
    (400070008291, 400070008291, 'Fish Schezwan', 'fish schezwan', 'non_veg', 'SEAFOOD'),
    (400070008292, 400070008292, 'Prawns Kung Pao', 'prawns kung pao', 'non_veg', 'SEAFOOD'),
    (400070008293, 400070008293, 'Fish Kung Pao', 'fish kung pao', 'non_veg', 'SEAFOOD'),
    (400070008294, 400070008294, 'Prawns Hunan', 'prawns hunan', 'non_veg', 'SEAFOOD'),
    (400070008295, 400070008295, 'Fish Hunan', 'fish hunan', 'non_veg', 'SEAFOOD'),
    (400070008296, 400070008296, 'Prawns Black Pepper', 'prawns black pepper', 'non_veg', 'SEAFOOD'),
    (400070008297, 400070008297, 'Fish Black Pepper', 'fish black pepper', 'non_veg', 'SEAFOOD'),
    (400070008298, 400070008298, 'Prawns Seafood 65', 'prawns seafood 65', 'non_veg', 'SEAFOOD'),
    (400070008299, 400070008299, 'Fish Seafood 65', 'fish seafood 65', 'non_veg', 'SEAFOOD'),
    (400070008300, 400070008300, 'Prawns Lemon', 'prawns lemon', 'non_veg', 'SEAFOOD'),
    (400070008301, 400070008301, 'Fish Lemon', 'fish lemon', 'non_veg', 'SEAFOOD'),
    (400070008302, 400070008302, 'Prawns Prawns Crispy', 'prawns prawns crispy', 'non_veg', 'SEAFOOD'),
    (400070008303, 400070008303, 'Prawns Janata Rice (gravy)', 'prawns janata rice (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008304, 400070008304, 'Prawns Dragon Rice', 'prawns dragon rice', 'non_veg', 'SEAFOOD'),
    (400070008305, 400070008305, 'Prawns Chilli Rice (gravy)', 'prawns chilli rice (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008306, 400070008306, 'Prawns Pot Rice (gravy)', 'prawns pot rice (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008307, 400070008307, 'Prawns Manchurian Rice (gravy)', 'prawns manchurian rice (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008308, 400070008308, 'Prawns Oyster Chilli Rice (gravy)', 'prawns oyster chilli rice (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008309, 400070008309, 'Prawns Triple Rice (gravy)', 'prawns triple rice (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008310, 400070008310, 'Prawns Singapore Rice', 'prawns singapore rice', 'non_veg', 'SEAFOOD'),
    (400070008311, 400070008311, 'Prawns Schezwan Rice', 'prawns schezwan rice', 'non_veg', 'SEAFOOD'),
    (400070008312, 400070008312, 'Prawns Hong Kong Rice', 'prawns hong kong rice', 'non_veg', 'SEAFOOD'),
    (400070008313, 400070008313, 'Prawns Fried Rice', 'prawns fried rice', 'non_veg', 'SEAFOOD'),
    (400070008314, 400070008314, 'Prawns Burn Garlic Rice', 'prawns burn garlic rice', 'non_veg', 'SEAFOOD'),
    (400070008315, 400070008315, 'Prawns Janata Noodles (gravy)', 'prawns janata noodles (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008316, 400070008316, 'Prawns Hakka Noodles', 'prawns hakka noodles', 'non_veg', 'SEAFOOD'),
    (400070008317, 400070008317, 'Prawns Pan Fried Noodles (gravy)', 'prawns pan fried noodles (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008318, 400070008318, 'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'non_veg', 'SEAFOOD'),
    (400070008319, 400070008319, 'Prawns Singapore Noodles', 'prawns singapore noodles', 'non_veg', 'SEAFOOD'),
    (400070008320, 400070008320, 'Prawns Chilli Noodles (gravy)', 'prawns chilli noodles (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008321, 400070008321, 'Prawns Burn Garlic Noodles', 'prawns burn garlic noodles', 'non_veg', 'SEAFOOD'),
    (400070008322, 400070008322, 'Prawns Hong Kong Noodles', 'prawns hong kong noodles', 'non_veg', 'SEAFOOD'),
    (400070008323, 400070008323, 'Prawns Manchurian (gravy)', 'prawns manchurian (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008324, 400070008324, 'Prawns Triple Noodles (gravy)', 'prawns triple noodles (gravy)', 'non_veg', 'SEAFOOD'),
    (400070008325, 400070008325, 'Janata Veg Soup', 'janata veg soup', 'veg', NULL),
    (400070008326, 400070008326, 'Veg Hot N'' Soup', 'veg hot n'' soup', 'veg', NULL),
    (400070008327, 400070008327, 'Veg Clear Soup', 'veg clear soup', 'veg', NULL),
    (400070008328, 400070008328, 'Veg Sweet Corn Soup', 'veg sweet corn soup', 'veg', NULL),
    (400070008329, 400070008329, 'Veg Manchow Soup', 'veg manchow soup', 'veg', NULL),
    (400070008330, 400070008330, 'Paneer Thread', 'paneer thread', 'veg', NULL),
    (400070008331, 400070008331, 'Paneer Crispy', 'paneer crispy', 'veg', NULL),
    (400070008332, 400070008332, 'Veg. Crispy', 'veg. crispy', 'veg', NULL),
    (400070008333, 400070008333, 'Rolls Dragon', 'rolls dragon', 'veg', NULL),
    (400070008334, 400070008334, 'Rolls Paneer', 'rolls paneer', 'veg', NULL),
    (400070008335, 400070008335, 'Rolls Spring', 'rolls spring', 'veg', NULL),
    (400070008336, 400070008336, 'Paneer Chilli', 'paneer chilli', 'veg', NULL),
    (400070008337, 400070008337, 'Paneer Manchurian', 'paneer manchurian', 'veg', NULL),
    (400070008338, 400070008338, 'Paneer (black Pepper)', 'paneer (black pepper)', 'veg', NULL),
    (400070008339, 400070008339, 'Paneer Butter Garlic', 'paneer butter garlic', 'veg', NULL),
    (400070008340, 400070008340, 'Paneer Schezwan', 'paneer schezwan', 'veg', NULL),
    (400070008341, 400070008341, 'Paneer Kung Pao', 'paneer kung pao', 'veg', NULL),
    (400070008342, 400070008342, 'Paneer Hunan', 'paneer hunan', 'veg', NULL),
    (400070008343, 400070008343, 'Paneer Bbeque', 'paneer bbeque', 'veg', NULL),
    (400070008344, 400070008344, 'Potato Crispy', 'potato crispy', 'veg', NULL),
    (400070008345, 400070008345, 'Baby Corn & Mushroom Chilli', 'baby corn & mushroom chilli', 'veg', NULL),
    (400070008346, 400070008346, 'Baby Corn & Mushroom Manchurian', 'baby corn & mushroom manchurian', 'veg', NULL),
    (400070008347, 400070008347, 'Baby Corn & Mushroom Green Chilli', 'baby corn & mushroom green chilli', 'veg', NULL),
    (400070008348, 400070008348, 'Baby Corn & Mushroom Black Pepper', 'baby corn & mushroom black pepper', 'veg', NULL),
    (400070008349, 400070008349, 'Baby Corn & Mushroom Hot Garlic', 'baby corn & mushroom hot garlic', 'veg', NULL),
    (400070008350, 400070008350, 'Baby Corn & Mushroom Sweet Garlic', 'baby corn & mushroom sweet garlic', 'veg', NULL),
    (400070008351, 400070008351, 'Cauliflower Chilli', 'cauliflower chilli', 'veg', NULL),
    (400070008352, 400070008352, 'Cauliflower Manchurian', 'cauliflower manchurian', 'veg', NULL),
    (400070008353, 400070008353, 'Cauliflower Hongkong', 'cauliflower hongkong', 'veg', NULL),
    (400070008354, 400070008354, 'Cauliflower Schezwan', 'cauliflower schezwan', 'veg', NULL),
    (400070008355, 400070008355, 'Cauliflower Kung Pao', 'cauliflower kung pao', 'veg', NULL),
    (400070008356, 400070008356, 'Cauliflower Hunan', 'cauliflower hunan', 'veg', NULL),
    (400070008357, 400070008357, 'Cauliflower Barbeque', 'cauliflower barbeque', 'veg', NULL),
    (400070008358, 400070008358, 'Cauliflower Green Chilli', 'cauliflower green chilli', 'veg', NULL),
    (400070008359, 400070008359, 'Cauliflower Black Pepper', 'cauliflower black pepper', 'veg', NULL),
    (400070008360, 400070008360, 'Paneer Dragon', 'paneer dragon', 'veg', NULL),
    (400070008361, 400070008361, 'Paneer Kungpao', 'paneer kungpao', 'veg', NULL),
    (400070008362, 400070008362, 'Paneer Barbeque', 'paneer barbeque', 'veg', NULL),
    (400070008363, 400070008363, 'Paneer Green Chilli', 'paneer green chilli', 'veg', NULL),
    (400070008364, 400070008364, 'Paneer Black Pepper', 'paneer black pepper', 'veg', NULL),
    (400070008365, 400070008365, 'Baby Corn & Mushroom Schezwan', 'baby corn & mushroom schezwan', 'veg', NULL),
    (400070008366, 400070008366, 'Baby Corn & Mushroom Kung Pao', 'baby corn & mushroom kung pao', 'veg', NULL),
    (400070008367, 400070008367, 'Baby Corn & Mushroom Hunan', 'baby corn & mushroom hunan', 'veg', NULL),
    (400070008368, 400070008368, 'Baby Corn & Mushroom Barbeque', 'baby corn & mushroom barbeque', 'veg', NULL),
    (400070008369, 400070008369, 'Baby Corn & Mushroom (black Pepper)', 'baby corn & mushroom (black pepper)', 'veg', NULL),
    (400070008370, 400070008370, 'Veg. Bowl Chilli', 'veg. bowl chilli', 'veg', NULL),
    (400070008371, 400070008371, 'Veg. Bowl Manchurian', 'veg. bowl manchurian', 'veg', NULL),
    (400070008372, 400070008372, 'Veg. Bowl Schezwan', 'veg. bowl schezwan', 'veg', NULL),
    (400070008373, 400070008373, 'Veg. Bowl Kung Pao', 'veg. bowl kung pao', 'veg', NULL),
    (400070008374, 400070008374, 'Veg. Bowl Hunan', 'veg. bowl hunan', 'veg', NULL),
    (400070008375, 400070008375, 'Veg. Bowl Green Chilli', 'veg. bowl green chilli', 'veg', NULL),
    (400070008376, 400070008376, 'Veg. Bowl Black Pepper', 'veg. bowl black pepper', 'veg', NULL),
    (400070008377, 400070008377, 'Veg. Bowl Hot Garlic', 'veg. bowl hot garlic', 'veg', NULL),
    (400070008378, 400070008378, 'Veg. Bowl Sweet Garlic', 'veg. bowl sweet garlic', 'veg', NULL),
    (400070008379, 400070008379, 'Potato Chilli', 'potato chilli', 'veg', NULL),
    (400070008380, 400070008380, 'Potato Manchurian', 'potato manchurian', 'veg', NULL),
    (400070008381, 400070008381, 'Potato Black Pepper', 'potato black pepper', 'veg', NULL),
    (400070008382, 400070008382, 'Potato Schezwan', 'potato schezwan', 'veg', NULL),
    (400070008383, 400070008383, 'Potato Hunan', 'potato hunan', 'veg', NULL),
    (400070008384, 400070008384, 'Potato Barbeque', 'potato barbeque', 'veg', NULL),
    (400070008385, 400070008385, 'Potato Ginger', 'potato ginger', 'veg', NULL),
    (400070008386, 400070008386, 'Potato Red Chilli', 'potato red chilli', 'veg', NULL),
    (400070008387, 400070008387, 'Potato Dragon', 'potato dragon', 'veg', NULL),
    (400070008388, 400070008388, 'Veg Janata Noodles (gravy)', 'veg janata noodles (gravy)', 'veg', NULL),
    (400070008389, 400070008389, 'Veg Manchurian Noodles (gravy)', 'veg manchurian noodles (gravy)', 'veg', NULL),
    (400070008390, 400070008390, 'Veg Triple Noodles (gravy)', 'veg triple noodles (gravy)', 'veg', NULL),
    (400070008391, 400070008391, 'Veg Chilli Noodles (gravy)', 'veg chilli noodles (gravy)', 'veg', NULL),
    (400070008392, 400070008392, 'Veg Schezwan Noodles', 'veg schezwan noodles', 'veg', NULL),
    (400070008393, 400070008393, 'Veg Singapore Noodles', 'veg singapore noodles', 'veg', NULL),
    (400070008394, 400070008394, 'Veg Hongkong Noodles', 'veg hongkong noodles', 'veg', NULL),
    (400070008395, 400070008395, 'Veg Hakka Noodles', 'veg hakka noodles', 'veg', NULL),
    (400070008396, 400070008396, 'Veg Burn Garlic Noodles', 'veg burn garlic noodles', 'veg', NULL),
    (400070008397, 400070008397, 'Pan Fry Noodles (gravy)', 'pan fry noodles (gravy)', 'veg', NULL),
    (400070008398, 400070008398, 'Veg Janata Rice (gravy)', 'veg janata rice (gravy)', 'veg', NULL),
    (400070008399, 400070008399, 'Veg Chilli Rice (gravy)', 'veg chilli rice (gravy)', 'veg', NULL),
    (400070008400, 400070008400, 'Veg Triple Rice (gravy)', 'veg triple rice (gravy)', 'veg', NULL),
    (400070008401, 400070008401, 'Veg Manchurian Rice (gravy)', 'veg manchurian rice (gravy)', 'veg', NULL),
    (400070008402, 400070008402, 'Veg Schezwan Rice', 'veg schezwan rice', 'veg', NULL),
    (400070008403, 400070008403, 'Veg Pot Rice (gravy)', 'veg pot rice (gravy)', 'veg', NULL),
    (400070008404, 400070008404, 'Veg Burn Garlic Rice', 'veg burn garlic rice', 'veg', NULL),
    (400070008405, 400070008405, 'Mushroom Rice', 'mushroom rice', 'veg', NULL),
    (400070008406, 400070008406, 'Paneer Fried Rice', 'paneer fried rice', 'veg', NULL),
    (400070008407, 400070008407, 'Paneer Chilli Rice (gravy)', 'paneer chilli rice (gravy)', 'veg', NULL),
    (400070008408, 400070008408, 'Veg Hongkong Rice', 'veg hongkong rice', 'veg', NULL),
    (400070008409, 400070008409, 'Veg. Singapore Rice', 'veg. singapore rice', 'veg', NULL),
    (400070008410, 400070008410, 'Paneer Mushroom Rice', 'paneer mushroom rice', 'veg', NULL),
    (400070008411, 400070008411, 'Veg. Fried Rice', 'veg. fried rice', 'veg', NULL),
    (400070008412, 400070008412, 'Veg American Chop Suey', 'veg american chop suey', 'veg', NULL),
    (400070008413, 400070008413, 'Veg Chinese Chop Suey', 'veg chinese chop suey', 'veg', NULL),
    (400070008414, 400070008414, 'Veg Chowmin Chop Suey', 'veg chowmin chop suey', 'veg', NULL),
    (400070008415, 400070008415, 'Mix Chop Suey', 'mix chop suey', 'veg', NULL),
    (400070008416, 400070008416, 'Bheja Roll', 'bheja roll', 'non_veg', 'MUTTON'),
    (400070008417, 400070008417, 'Mutton Roll', 'mutton roll', 'non_veg', 'MUTTON'),
    (400070008418, 400070008418, 'Mutton Cheese Roll', 'mutton cheese roll', 'non_veg', 'MUTTON'),
    (400070008419, 400070008419, 'Mutton Egg Roti', 'mutton egg roti', 'non_veg', 'MUTTON'),
    (400070008420, 400070008420, 'Mutton Cheese Egg Roti', 'mutton cheese egg roti', 'non_veg', 'MUTTON'),
    (400070008421, 400070008421, 'Gurda Roll', 'gurda roll', 'non_veg', 'MUTTON'),
    (400070008422, 400070008422, 'Chicken Roll', 'chicken roll', 'non_veg', 'CHICKEN'),
    (400070008423, 400070008423, 'Chicken Cheese Roll', 'chicken cheese roll', 'non_veg', 'CHICKEN'),
    (400070008424, 400070008424, 'Chicken Egg Roti', 'chicken egg roti', 'non_veg', 'CHICKEN'),
    (400070008425, 400070008425, 'Chicken Cheese Egg Roti', 'chicken cheese egg roti', 'non_veg', 'CHICKEN'),
    (400070008426, 400070008426, 'Chicken Naan Chaap', 'chicken naan chaap', 'non_veg', 'CHICKEN'),
    (400070008427, 400070008427, 'Mutton Naan Chaap', 'mutton naan chaap', 'non_veg', 'MUTTON'),
    (400070008428, 400070008428, 'Chicken Tikka Roll', 'chicken tikka roll', 'non_veg', 'CHICKEN'),
    (400070008429, 400070008429, 'Chicken Tikka Cheese Roll', 'chicken tikka cheese roll', 'non_veg', 'CHICKEN'),
    (400070008430, 400070008430, 'Paneer Roll', 'paneer roll', 'veg', NULL),
    (400070008431, 400070008431, 'Paneer Cheese Roll', 'paneer cheese roll', 'veg', NULL),
    (400070008432, 400070008432, 'Paneer Tikka Roll', 'paneer tikka roll', 'veg', NULL),
    (400070008433, 400070008433, 'Paneer Tikka Cheese Roll', 'paneer tikka cheese roll', 'veg', NULL),
    (400070008434, 400070008434, 'Tandoori Roti (wheat)', 'tandoori roti (wheat)', 'veg', NULL),
    (400070008435, 400070008435, 'Tandoori Butter Roti (wheat)', 'tandoori butter roti (wheat)', 'veg', NULL),
    (400070008436, 400070008436, 'Roomali Roti', 'roomali roti', 'veg', NULL),
    (400070008437, 400070008437, 'Lachha Paratha (wheat)', 'lachha paratha (wheat)', 'veg', NULL),
    (400070008438, 400070008438, 'Butter Naan', 'butter naan', 'veg', NULL),
    (400070008439, 400070008439, 'Kulcha Paratha', 'kulcha paratha', 'veg', NULL),
    (400070008440, 400070008440, 'Kamachi Naan', 'kamachi naan', 'veg', NULL),
    (400070008441, 400070008441, 'Garlic Naan', 'garlic naan', 'veg', NULL),
    (400070008442, 400070008442, 'Samosa Butter Naan', 'samosa butter naan', 'veg', NULL),
    (400070008443, 400070008443, 'Cheese Garlic Naan', 'cheese garlic naan', 'veg', NULL),
    (400070008444, 400070008444, 'Cheese Naan', 'cheese naan', 'veg', NULL),
    (400070008445, 400070008445, 'Shahi Tukda', 'shahi tukda', 'veg', NULL),
    (400070008446, 400070008446, 'Caramel Custard', 'caramel custard', 'veg', NULL),
    (400070008447, 400070008447, 'Rabdi', 'rabdi', 'veg', NULL),
    (400070008448, 400070008448, 'Chocolate Mouse', 'chocolate mouse', 'veg', NULL),
    (400070008449, 400070008449, 'Arabian Pudding', 'arabian pudding', 'veg', NULL),
    (400070008450, 400070008450, 'Mix Fruit Cream', 'mix fruit cream', 'veg', NULL),
    (400070008451, 400070008451, 'Sitafal Cream (seasonal)', 'sitafal cream (seasonal)', 'veg', NULL),
    (400070008452, 400070008452, 'Mango Cream (seasonal)', 'mango cream (seasonal)', 'veg', NULL),
    (400070008453, 400070008453, 'Strawberry Cream (seasonal)', 'strawberry cream (seasonal)', 'veg', NULL),
    (400070008454, 400070008454, 'Brownie With-ice-cream', 'brownie with-ice-cream', 'veg', NULL),
    (400070008455, 400070008455, 'Chocolate Lava', 'chocolate lava', 'veg', NULL),
    (400070008456, 400070008456, 'Gulab Jamun', 'gulab jamun', 'veg', NULL),
    (400070008457, 400070008457, 'Plain Dahi', 'plain dahi', 'veg', NULL),
    (400070008458, 400070008458, 'Boondi Raita', 'boondi raita', 'veg', NULL),
    (400070008459, 400070008459, 'Mix Raita', 'mix raita', 'veg', NULL),
    (400070008460, 400070008460, 'Raita', 'raita', 'veg', NULL),
    (400070008461, 400070008461, 'Green Salad', 'green salad', 'veg', NULL),
    (400070008462, 400070008462, 'Fruit Salad', 'fruit salad', 'veg', NULL),
    (400070008463, 400070008463, 'Fruit Salad With Ice Cream', 'fruit salad with ice cream', 'veg', NULL),
    (400070008464, 400070008464, 'Papad', 'papad', 'veg', NULL),
    (400070008465, 400070008465, 'Masala Papad', 'masala papad', 'veg', NULL),
    (400070008466, 400070008466, 'Rice Papad', 'rice papad', 'veg', NULL),
    (400070008467, 400070008467, 'Fry Noodle', 'fry noodle', 'veg', NULL),
    (400070008468, 400070008468, 'Schezwan Souce', 'schezwan souce', 'veg', NULL),
    (400070008469, 400070008469, 'Virgin Mojito', 'virgin mojito', 'veg', NULL),
    (400070008470, 400070008470, 'Strawberry', 'strawberry', 'veg', NULL),
    (400070008471, 400070008471, 'Blue Lagoon', 'blue lagoon', 'veg', NULL),
    (400070008472, 400070008472, 'Mango Mojito', 'mango mojito', 'veg', NULL),
    (400070008473, 400070008473, 'Sweet & Salty', 'sweet & salty', 'veg', NULL),
    (400070008474, 400070008474, 'Sweet', 'sweet', 'veg', NULL),
    (400070008475, 400070008475, 'Salty', 'salty', 'veg', NULL),
    (400070008476, 400070008476, 'Fruit Punch', 'fruit punch', 'veg', NULL)
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
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070008001, 'CHARCOAL GRILLED', 1), (400070008002, 'FRY - PAN DISHES', 2), (400070008003, 'TAWA SPECIAL', 3), (400070008004, 'TAWA CHICKEN CURRY', 4), (400070008005, 'TAWA SEA CURRY', 5), (400070008006, 'TAWA MUTTON CURRY', 6), (400070008007, 'TAWA VEG CURRY', 7), (400070008008, 'TAWA PULAV', 8), (400070008009, 'SOUP NON-VEG', 9), (400070008010, 'NON-VEG STARTERS', 10), (400070008011, 'NON - VEG MAIN COURSE GRAVY', 11), (400070008012, 'RICE NON-VEG', 12), (400070008013, 'NOODLES NON-VEG', 13), (400070008014, 'CHOP SUEY NON - VEG', 14), (400070008015, 'SEAFOOD STARTERS', 15), (400070008016, 'SEAFOOD MAIN COURSE GRAVY', 16), (400070008017, 'SEAFOOD RICE', 17), (400070008018, 'SEAFOOD NOODLES', 18), (400070008019, 'SEAFOOD CHOP SUEY', 19), (400070008020, 'VEG SOUP', 20), (400070008021, 'VEG STARTERS', 21), (400070008022, 'VEG MAIN COURSE GRAVY', 22), (400070008023, 'VEG NOODLES', 23), (400070008024, 'VEG RICE', 24), (400070008025, 'VEG CHOP SUEY', 25), (400070008026, 'TAWA ROLLS', 26), (400070008027, 'ROTI', 27), (400070008028, 'DESSERTS', 28), (400070008029, 'RAITA & SALAD', 29), (400070008030, 'MOCKTAIL', 30)) AS x(menu_category_id, name, display_sequence);

-- =============================================================================
-- Menu items (530)
-- =============================================================================

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008001, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Tandoori', 'chicken tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tandoori' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008001, 'Half', FALSE), (400070008002, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008001, 'Half', 270.00, FALSE), (400070008002, 'Full', 480.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008002, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Leg Piece', 'leg piece', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'leg piece'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008003, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008003, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Lemon Tandoori', 'lemon tandoori', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lemon tandoori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008004, 'Half', FALSE), (400070008005, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008004, 'Half', 280.00, FALSE), (400070008005, 'Full', 520.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008004, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Afghani Tandoori', 'afghani tandoori', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'afghani tandoori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008006, 'Half', FALSE), (400070008007, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008006, 'Half', 320.00, FALSE), (400070008007, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008005, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Makhmali Tandoori', 'makhmali tandoori', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'makhmali tandoori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008008, 'Half', FALSE), (400070008009, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008008, 'Half', 320.00, FALSE), (400070008009, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008006, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Hara Bhara Tandoori', 'hara bhara tandoori', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hara bhara tandoori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008010, 'Half', FALSE), (400070008011, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008010, 'Half', 320.00, FALSE), (400070008011, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008007, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Pomfret Tandoori', 'pomfret tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pomfret tandoori' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400070008012, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008008, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Banjara Tandoori', 'banjara tandoori', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banjara tandoori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008013, 'Half', FALSE), (400070008014, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008013, 'Half', 350.00, FALSE), (400070008014, 'Full', 650.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008009, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Janata Chicken Tandoori', 'janata chicken tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken tandoori' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008015, 'Half', FALSE), (400070008016, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008015, 'Half', 350.00, FALSE), (400070008016, 'Full', 650.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008010, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Bater Tandoori (2 Pcs)', 'bater tandoori (2 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bater tandoori (2 pcs)' AND pt.code = 'OTHER'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008017, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008011, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Paneer Tikka', 'paneer tikka', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008018, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008012, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Malai Tikka', 'chicken malai tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken malai tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008019, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008013, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Tikka', 'chicken tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008020, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008014, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Reshmi Tikka', 'chicken reshmi tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken reshmi tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008021, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008015, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Pahadi Tikka', 'chicken pahadi tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pahadi tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008022, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008016, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Garlic Tikka', 'chicken garlic tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken garlic tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008023, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008017, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Zaffrani Tikka', 'chicken zaffrani tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken zaffrani tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008024, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008018, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Dahi Lasooni Tikka', 'chicken dahi lasooni tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken dahi lasooni tikka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008025, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008019, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Alu Tikka', 'alu tikka', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008026, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008020, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Prawns Tikka', 'prawns tikka', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns tikka' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008027, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008021, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Burra', 'chicken burra', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken burra' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008028, 'Half', FALSE), (400070008029, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008028, 'Half', 350.00, FALSE), (400070008029, 'Full', 650.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008022, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Reshmi Tikka Burra', 'chicken reshmi tikka burra', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken reshmi tikka burra' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008030, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008023, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Tikka Burra', 'chicken tikka burra', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka burra' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008031, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008024, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Burra (4 Pcs)', 'mutton burra (4 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton burra (4 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008032, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008025, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Banjara Tandoori', 'mutton banjara tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton banjara tandoori' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008033, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008026, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Tandoori', 'mutton tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton tandoori' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008034, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008027, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Kalimiri Tandoori', 'mutton kalimiri tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton kalimiri tandoori' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008035, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008028, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Chaap (3 Pcs)', 'mutton chaap (3 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton chaap (3 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008036, new_variant.variant_id, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008029, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Chaap Burra', 'mutton chaap burra', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton chaap burra' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008037, new_variant.variant_id, 730.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008030, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Raan Burra', 'raan burra', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'raan burra' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008038, new_variant.variant_id, 2300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008031, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Raan Banjara', 'raan banjara', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'raan banjara' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008039, new_variant.variant_id, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008032, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Raan Kalimiri', 'raan kalimiri', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'raan kalimiri' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008040, new_variant.variant_id, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008033, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Raan Tandoori', 'raan tandoori', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'raan tandoori' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008041, new_variant.variant_id, 2000.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008034, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Malai Drum (4 Pcs)', 'chicken malai drum (4 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken malai drum (4 pcs)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008042, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008035, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Tangdi Drum', 'chicken tangdi drum', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tangdi drum' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008043, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008036, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Reshmi Drum', 'chicken reshmi drum', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken reshmi drum' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008044, new_variant.variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008037, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Adraki Tangdi', 'chicken adraki tangdi', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken adraki tangdi' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008045, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008038, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Seekh (4 Pcs)', 'chicken seekh (4 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken seekh (4 pcs)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008046, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008039, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Irani Seekh', 'chicken irani seekh', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken irani seekh' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008047, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008040, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Malai Seekh', 'chicken malai seekh', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken malai seekh' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008048, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008041, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Chicken Cheese Seekh', 'chicken cheese seekh', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cheese seekh' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008049, new_variant.variant_id, 390.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008042, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Seekh (4 Pcs)', 'mutton seekh (4 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton seekh (4 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008050, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008043, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Mutton Turkish Boti (6 Pcs)', 'mutton turkish boti (6 pcs)', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton turkish boti (6 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008051, new_variant.variant_id, 580.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008044, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Achari Kebab (6 Pcs)', 'achari kebab (6 pcs)', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'achari kebab (6 pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008052, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008045, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Pudina Kebab', 'pudina kebab', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pudina kebab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008053, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008046, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Banjara Keba', 'banjara keba', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banjara keba'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008054, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008047, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Nawabi Kebab', 'nawabi kebab', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nawabi kebab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008055, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008048, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Kalimiri Kebab', 'kalimiri kebab', 'CHARCOAL GRILLED', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kalimiri kebab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008056, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008049, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Janata Chicken Platters', 'janata chicken platters', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken platters' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008057, new_variant.variant_id, 2190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008050, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Janata Chicken Tikka Platters', 'janata chicken tikka platters', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken tikka platters' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008058, new_variant.variant_id, 1160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHARCOAL GRILLED" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008051, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008001, 'Janata Mutton Platters', 'janata mutton platters', 'CHARCOAL GRILLED', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata mutton platters' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008059, new_variant.variant_id, 3290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008052, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Turkish Kebab', 'turkish kebab', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'turkish kebab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008060, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008053, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Peshawari', 'chicken peshawari', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken peshawari' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008061, 'Half', FALSE), (400070008062, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008061, 'Half', 350.00, FALSE), (400070008062, 'Full', 650.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008054, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Prawns Fry', 'prawns fry', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008063, 'Half', FALSE), (400070008064, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008063, 'Half', 940.00, FALSE), (400070008064, 'Full', 1870.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008055, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Fish Fry', 'fish fry', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008065, 'Half', FALSE), (400070008066, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008065, 'Half', 770.00, FALSE), (400070008066, 'Full', 1550.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008056, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Lasooni', 'chicken lasooni', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lasooni' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008067, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008057, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Lal Mirch', 'chicken lal mirch', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lal mirch' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008068, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008058, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Golden Chicken', 'golden chicken', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'golden chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008069, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008059, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Lamba', 'chicken lamba', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lamba' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008070, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008060, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Hariyali', 'chicken hariyali', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hariyali' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008071, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008061, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Dryfruit', 'chicken dryfruit', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken dryfruit' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008072, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008062, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken M.M', 'chicken m.m', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken m.m' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008073, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008063, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Tandoori Lasooni', 'chicken tandoori lasooni', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tandoori lasooni' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008074, new_variant.variant_id, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008064, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken G.C.C.', 'chicken g.c.c.', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken g.c.c.' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008075, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008065, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken M.B.T.', 'chicken m.b.t.', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken m.b.t.' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008076, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008066, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Superstar', 'chicken superstar', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken superstar' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008077, new_variant.variant_id, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008067, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Apple', 'chicken apple', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken apple' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008078, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008068, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Sukka', 'chicken sukka', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sukka' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008079, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008069, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Sultani', 'chicken sultani', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sultani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008080, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008070, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken American', 'chicken american', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken american' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008081, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008071, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Koyla', 'chicken koyla', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken koyla' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008082, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008072, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Kalimiri', 'chicken kalimiri', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kalimiri' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008083, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008073, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken White Sauce', 'chicken white sauce', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken white sauce' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008084, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008074, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Soup', 'chicken soup', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008085, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008075, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Changezi (gravy)', 'chicken changezi (gravy)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken changezi (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008086, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008076, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Lapeta (gravy)', 'chicken lapeta (gravy)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lapeta (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008087, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008077, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Handi (gravy)', 'chicken handi (gravy)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken handi (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008088, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008078, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Soup', 'mutton soup', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton soup' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008089, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008079, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Kalimiri (6 Pcs)', 'mutton kalimiri (6 pcs)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton kalimiri (6 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008090, new_variant.variant_id, 730.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008080, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Sukka', 'mutton sukka', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton sukka' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008091, new_variant.variant_id, 730.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008081, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Chaap Kalimiri (3 Pcs)', 'mutton chaap kalimiri (3 pcs)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton chaap kalimiri (3 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008092, new_variant.variant_id, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008082, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Changezi (gravy)', 'mutton changezi (gravy)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton changezi (gravy)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008093, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008083, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Lapeta (gravy)', 'mutton lapeta (gravy)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton lapeta (gravy)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008094, new_variant.variant_id, 490.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008084, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Handi (gravy)', 'mutton handi (gravy)', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton handi (gravy)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008095, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008085, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Kheema', 'mutton kheema', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton kheema' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008096, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008086, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Paneer Lasooni', 'paneer lasooni', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008097, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008087, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Paneer Dryfruit', 'paneer dryfruit', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer dryfruit'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008098, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008088, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Paneer Hariyali', 'paneer hariyali', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hariyali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008099, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008089, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Paneer Lal Mirch', 'paneer lal mirch', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lal mirch'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008100, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008090, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Paneer American', 'paneer american', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer american'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008101, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008091, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Dal Khichdi', 'dal khichdi', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008102, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008092, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008103, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008093, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Dal Fry', 'dal fry', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008104, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008094, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Dal Ghee', 'dal ghee', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal ghee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008105, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008095, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Dal Tadka', 'dal tadka', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008106, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008096, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Steamed Rice', 'steamed rice', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steamed rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008107, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008097, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Jeera Rice', 'jeera rice', 'FRY - PAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008108, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008098, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Chicken Mughlai Kepsa', 'chicken mughlai kepsa', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken mughlai kepsa' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008109, 'Half', FALSE), (400070008110, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008109, 'Half', 640.00, FALSE), (400070008110, 'Full', 1260.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "FRY - PAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008099, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008002, 'Mutton Mughlai Kepsa', 'mutton mughlai kepsa', 'FRY - PAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton mughlai kepsa' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008111, 'Half', FALSE), (400070008112, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008111, 'Half', 940.00, FALSE), (400070008112, 'Full', 1760.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008100, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Bheja Masala', 'bheja masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008113, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008101, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Gurda Masala', 'gurda masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'gurda masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008114, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008102, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Kaleji Masala', 'kaleji masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'kaleji masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008115, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008103, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Bheja Gurda Masala', 'bheja gurda masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja gurda masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008116, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008104, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Gurda Kaleji Masala', 'gurda kaleji masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'gurda kaleji masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008117, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008105, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Bheja Kaleji Masala', 'bheja kaleji masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja kaleji masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008118, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008106, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Bheja Plain Fry (2 Pcs.)', 'bheja plain fry (2 pcs.)', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja plain fry (2 pcs.)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008119, new_variant.variant_id, 580.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008107, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Kaleji Plain Fry', 'kaleji plain fry', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'kaleji plain fry' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008120, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008108, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Gurda Plain Fry (6 Pcs)', 'gurda plain fry (6 pcs)', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'gurda plain fry (6 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008121, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008109, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Katakat Masala (bheja Gurda Kaleji)', 'katakat masala (bheja gurda kaleji)', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'katakat masala (bheja gurda kaleji)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008122, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008110, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Takatak Masala (bheja Gurda Kaleji Mutton)', 'takatak masala (bheja gurda kaleji mutton)', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'takatak masala (bheja gurda kaleji mutton)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008123, new_variant.variant_id, 510.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008111, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Double Bheja Masala', 'double bheja masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'double bheja masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008124, new_variant.variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008112, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Double Gurda Masala', 'double gurda masala', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'double gurda masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008125, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008113, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Prawns Tawa Fry', 'prawns tawa fry', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns tawa fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008126, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008114, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Fish Tawa Fry', 'fish tawa fry', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish tawa fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008127, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008115, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Pomfret Tawa Fry', 'pomfret tawa fry', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pomfret tawa fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008128, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008116, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008003, 'Mutton Tawa Fry', 'mutton tawa fry', 'TAWA SPECIAL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton tawa fry' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008129, new_variant.variant_id, 580.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008117, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Tawa Khurchan (boneless)', 'tawa khurchan (boneless)', 'TAWA CHICKEN CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa khurchan (boneless)'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008130, 'Half', FALSE), (400070008131, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008130, 'Half', 350.00, FALSE), (400070008131, 'Full', 660.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008118, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Tawa Lajawab', 'chicken tawa lajawab', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tawa lajawab' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008132, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008119, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Boti Masala', 'chicken boti masala', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken boti masala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008133, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008120, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Tikka Masala (boneless)', 'chicken tikka masala (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka masala (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008134, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008121, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Hyderabadi Chicken (boneless)', 'hyderabadi chicken (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'hyderabadi chicken (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008135, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008122, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Kolhapuri', 'chicken kolhapuri', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kolhapuri' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008136, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008123, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Bhuna (boneless)', 'chicken bhuna (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken bhuna (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008137, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008124, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Patiyala', 'chicken patiyala', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken patiyala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008138, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008125, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Butter Chicken (boneless)', 'butter chicken (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'butter chicken (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008139, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008126, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Dopyaza (boneless)', 'chicken dopyaza (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken dopyaza (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008140, 'Half', FALSE), (400070008141, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008140, 'Half', 400.00, FALSE), (400070008141, 'Full', 760.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008127, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Angara', 'chicken angara', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken angara' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008142, 'Half', FALSE), (400070008143, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008142, 'Half', 400.00, FALSE), (400070008143, 'Full', 760.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008128, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Rara', 'chicken rara', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken rara' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008144, 'Half', FALSE), (400070008145, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008144, 'Half', 400.00, FALSE), (400070008145, 'Full', 760.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008129, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Malwani', 'chicken malwani', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken malwani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008146, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008130, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Charbaug', 'chicken charbaug', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken charbaug' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008147, new_variant.variant_id, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008131, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Matka Chicken (gravy)', 'matka chicken (gravy)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'matka chicken (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008148, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008132, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Janata (gravy Boneless)', 'janata (gravy boneless)', 'TAWA CHICKEN CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata (gravy boneless)'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008149, 'Half', FALSE), (400070008150, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008149, 'Half', 310.00, FALSE), (400070008150, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008133, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Afgani Masala (boneless)', 'afgani masala (boneless)', 'TAWA CHICKEN CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'afgani masala (boneless)'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008151, 'Half', FALSE), (400070008152, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008151, 'Half', 310.00, FALSE), (400070008152, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008134, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Chatpata (boneless)', 'chicken chatpata (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chatpata (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008153, 'Half', FALSE), (400070008154, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008153, 'Half', 320.00, FALSE), (400070008154, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008135, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Tandoori Masala', 'tandoori masala', 'TAWA CHICKEN CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tandoori masala'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008155, 'Half', FALSE), (400070008156, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008155, 'Half', 530.00, FALSE), (400070008156, 'Full', 970.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008136, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Murgi Musallam', 'murgi musallam', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'murgi musallam' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008157, 'Half', FALSE), (400070008158, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008157, 'Half', 500.00, FALSE), (400070008158, 'Full', 950.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008137, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Lazeez (boneless)', 'chicken lazeez (boneless)', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lazeez (boneless)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008159, 'Half', FALSE), (400070008160, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008159, 'Half', 310.00, FALSE), (400070008160, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA CHICKEN CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008138, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008004, 'Chicken Lahori', 'chicken lahori', 'TAWA CHICKEN CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lahori' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008161, 'Half', FALSE), (400070008162, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008161, 'Half', 310.00, FALSE), (400070008162, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA SEA CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008139, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008005, 'Prawns Tawa Masala', 'prawns tawa masala', 'TAWA SEA CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns tawa masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008163, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SEA CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008140, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008005, 'Fish Tawa Masala', 'fish tawa masala', 'TAWA SEA CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish tawa masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008164, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SEA CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008141, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008005, 'Pomfret Tawa Masala', 'pomfret tawa masala', 'TAWA SEA CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pomfret tawa masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008165, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SEA CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008142, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008005, 'Prawns Khada Masala', 'prawns khada masala', 'TAWA SEA CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns khada masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008166, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SEA CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008143, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008005, 'Fish Khada Masala', 'fish khada masala', 'TAWA SEA CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish khada masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008167, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA SEA CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008144, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008005, 'Pomfret Khada Masala', 'pomfret khada masala', 'TAWA SEA CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pomfret khada masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008168, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008145, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Lajawab', 'mutton lajawab', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton lajawab' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008169, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008146, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Bhuna (boneless)', 'mutton bhuna (boneless)', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton bhuna (boneless)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008170, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008147, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Palak Gosht', 'mutton palak gosht', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton palak gosht' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008171, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008148, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Rara', 'mutton rara', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton rara' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008172, 'Half', FALSE), (400070008173, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008172, 'Half', 470.00, FALSE), (400070008173, 'Full', 910.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008149, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Boti Masala', 'mutton boti masala', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton boti masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008174, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008150, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Khada Masala', 'mutton khada masala', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton khada masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008175, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008151, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Dopyaza', 'mutton dopyaza', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton dopyaza' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008176, 'Half', FALSE), (400070008177, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008176, 'Half', 470.00, FALSE), (400070008177, 'Full', 910.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008152, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Maharaja', 'mutton maharaja', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton maharaja' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008178, 'Half', FALSE), (400070008179, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008178, 'Half', 490.00, FALSE), (400070008179, 'Full', 950.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008153, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Malvani', 'mutton malvani', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton malvani' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008180, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008154, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Patiyala', 'mutton patiyala', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton patiyala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008181, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008155, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Lazeez', 'mutton lazeez', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton lazeez' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008182, 'Half', FALSE), (400070008183, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008182, 'Half', 420.00, FALSE), (400070008183, 'Full', 820.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008156, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Lahori', 'mutton lahori', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton lahori' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008184, 'Half', FALSE), (400070008185, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008184, 'Half', 420.00, FALSE), (400070008185, 'Full', 820.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008157, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Raan Masala', 'mutton raan masala', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton raan masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008186, new_variant.variant_id, 2320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008158, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Tawa Khurchan (boneless)', 'mutton tawa khurchan (boneless)', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton tawa khurchan (boneless)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008187, 'Half', FALSE), (400070008188, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008187, 'Half', 470.00, FALSE), (400070008188, 'Full', 910.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA MUTTON CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008159, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008006, 'Mutton Chaap Masala (3 Pcs)', 'mutton chaap masala (3 pcs)', 'TAWA MUTTON CURRY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton chaap masala (3 pcs)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008189, new_variant.variant_id, 710.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008160, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Veg Kolhapuri', 'veg kolhapuri', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008190, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008161, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Matar Mushroom Masala', 'matar mushroom masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'matar mushroom masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008191, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008162, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Mix Vegetable Masala', 'mix vegetable masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix vegetable masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008192, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008163, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Matar Paneer Masala', 'matar paneer masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'matar paneer masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008193, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008164, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Lajawab', 'paneer lajawab', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lajawab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008194, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008165, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Masala', 'paneer masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008195, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008166, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mushroom masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008196, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008167, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Khada Masala', 'paneer khada masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer khada masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008197, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008168, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Afghani Masala', 'paneer afghani masala', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer afghani masala'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008198, 'Half', FALSE), (400070008199, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008198, 'Half', 350.00, FALSE), (400070008199, 'Full', 680.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008169, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Lazeez', 'paneer lazeez', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lazeez'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008200, 'Half', FALSE), (400070008201, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008200, 'Half', 350.00, FALSE), (400070008201, 'Full', 680.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008170, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Chatpata', 'paneer chatpata', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chatpata'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008202, 'Half', FALSE), (400070008203, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008202, 'Half', 350.00, FALSE), (400070008203, 'Full', 680.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008171, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Khurchan', 'paneer khurchan', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer khurchan'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008204, 'Half', FALSE), (400070008205, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008204, 'Half', 350.00, FALSE), (400070008205, 'Full', 680.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA VEG CURRY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008172, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008007, 'Paneer Lahori', 'paneer lahori', 'TAWA VEG CURRY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lahori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008206, 'Half', FALSE), (400070008207, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008206, 'Half', 320.00, FALSE), (400070008207, 'Full', 630.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008173, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Chicken Tikka Pulav', 'chicken tikka pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka pulav' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008208, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008174, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Chicken Pulav', 'chicken pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pulav' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008209, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008175, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Pulav', 'mutton pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008210, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008176, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Double Bheja Pulav', 'double bheja pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'double bheja pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008211, new_variant.variant_id, 640.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008177, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Double Gurda Pulav', 'double gurda pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'double gurda pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008212, new_variant.variant_id, 580.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008178, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Katakat Pulav (bheja Gurda Kaleji)', 'katakat pulav (bheja gurda kaleji)', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'katakat pulav (bheja gurda kaleji)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008213, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008179, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Takatak Pulav (bheja Gurda Kaleji Mutton)', 'takatak pulav (bheja gurda kaleji mutton)', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'takatak pulav (bheja gurda kaleji mutton)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008214, new_variant.variant_id, 530.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008180, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Bheja Pulav', 'bheja pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008215, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008181, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Kheema Bheja Pulav', 'mutton kheema bheja pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton kheema bheja pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008216, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008182, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Kheema Pulav', 'mutton kheema pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton kheema pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008217, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008183, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Bheja Gurda Pulav', 'bheja gurda pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja gurda pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008218, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008184, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Kaleji Bheja Pulav', 'kaleji bheja pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'kaleji bheja pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008219, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008185, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Gurda Kaleji Pulav', 'gurda kaleji pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'gurda kaleji pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008220, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008186, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Gurda Pulav', 'gurda pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'gurda pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008221, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008187, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Kaleji Pulav', 'kaleji pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'kaleji pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008222, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008188, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Chicken Tawa Biryani', 'chicken tawa biryani', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tawa biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008223, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008189, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008224, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008190, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Afghani Pulav', 'mutton afghani pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton afghani pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008225, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008191, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Masoor Pulav', 'mutton masoor pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton masoor pulav' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008226, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008192, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Zamzam Pulav', 'zamzam pulav', 'TAWA PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'zamzam pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008227, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008193, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Chicken Afghani Pulav', 'chicken afghani pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken afghani pulav' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008228, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008194, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Prawns Pulav', 'prawns pulav', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns pulav' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008229, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008195, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Tawa Biryani', 'mutton tawa biryani', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton tawa biryani' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008230, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008196, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Chicken Tawa Kepsa', 'chicken tawa kepsa', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tawa kepsa' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008231, 'Half', FALSE), (400070008232, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008231, 'Half', 640.00, FALSE), (400070008232, 'Full', 1260.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008197, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Tawa Kepsa', 'mutton tawa kepsa', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton tawa kepsa' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008233, 'Half', FALSE), (400070008234, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008233, 'Half', 940.00, FALSE), (400070008234, 'Full', 1760.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008198, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Mutton Raan Biryani', 'mutton raan biryani', 'TAWA PULAV', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton raan biryani' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008235, new_variant.variant_id, 2300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008199, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Veg. Pulav', 'veg. pulav', 'TAWA PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008236, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008200, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'TAWA PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008237, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008201, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008008, 'Veg. Biryani', 'veg. biryani', 'TAWA PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008238, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008202, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Janata Chicken Soup', 'janata chicken soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008239, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008203, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hot & sour soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008240, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008204, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Manchow Soup', 'chicken manchow soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchow soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008241, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008205, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Hakka Soup', 'chicken hakka soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hakka soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008242, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008206, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Wonton Clear Soup', 'wonton clear soup', 'SOUP NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'wonton clear soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008243, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008207, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Oriental Soup', 'chicken oriental soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken oriental soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008244, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008208, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Tom Yum Soup', 'chicken tom yum soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tom yum soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008245, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008209, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Talumein Soup', 'chicken talumein soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken talumein soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008246, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008210, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Meat Bowl Soup', 'meat bowl soup', 'SOUP NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'meat bowl soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008247, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008211, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Sweet Corn Soup', 'chicken sweet corn soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sweet corn soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008248, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008212, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Garlic Soup', 'chicken garlic soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken garlic soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008249, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008213, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Clear Soup', 'chicken clear soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken clear soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008250, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUP NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008214, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008009, 'Chicken Lung Fung Soup', 'chicken lung fung soup', 'SOUP NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lung fung soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008251, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008215, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Schezwan Tandoori', 'schezwan tandoori', 'NON-VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan tandoori'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008252, 'Half', FALSE), (400070008253, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008252, 'Half', 320.00, FALSE), (400070008253, 'Full', 590.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008216, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Janata Chicken Chilli', 'janata chicken chilli', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken chilli' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008254, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008217, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Crispy', 'chicken crispy', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken crispy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008255, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008218, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Lollipop (8pcs)', 'chicken lollipop (8pcs)', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lollipop (8pcs)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008256, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008219, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Lollipop (4pcs)', 'chicken lollipop (4pcs)', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lollipop (4pcs)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008257, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008220, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Schezwan Lollipop (8pcs)', 'schezwan lollipop (8pcs)', 'NON-VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan lollipop (8pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008258, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008258, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008221, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Schezwan Lollipop (4pcs)', 'schezwan lollipop (4pcs)', 'NON-VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan lollipop (4pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008259, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008259, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008222, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Oyster Chicken', 'oyster chicken', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'oyster chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008260, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008260, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008223, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Chilli', 'chicken chilli', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilli' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008261, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008261, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008224, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Manchurian', 'chicken manchurian', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008262, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008262, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008225, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Schezwan Chicken', 'schezwan chicken', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'schezwan chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008263, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008263, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008226, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Barbeque Sauce', 'chicken barbeque sauce', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken barbeque sauce' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008264, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008264, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008227, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Lemon Chicken', 'lemon chicken', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'lemon chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008265, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008265, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008228, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken 65', 'chicken 65', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken 65' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008266, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008266, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008229, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Dragon Chicken', 'dragon chicken', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'dragon chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008267, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008267, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008230, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Hunan', 'chicken hunan', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hunan' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008268, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008268, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008231, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Kung Pao', 'chicken kung pao', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kung pao' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008269, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008269, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008232, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Hot Garlic', 'hot garlic', 'NON-VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008270, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008270, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008233, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Sweet Garlic', 'sweet garlic', 'NON-VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008271, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008271, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008234, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Green Chilli', 'chicken green chilli', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken green chilli' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008272, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008272, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008235, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Black Pepper Sauce', 'chicken black pepper sauce', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken black pepper sauce' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008273, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008273, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008236, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Ginger', 'chicken ginger', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken ginger' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008274, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008274, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008237, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Dragon', 'chicken dragon', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'split-non-veg-starters-chickendragonspring-roll', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken dragon' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008275, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008275, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008238, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Chicken Spring Roll', 'chicken spring roll', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'split-non-veg-starters-chickendragonspring-roll', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken spring roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008276, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008276, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "NON-VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008239, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008010, 'Thread Chicken', 'thread chicken', 'NON-VEG STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'thread chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008277, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008277, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008240, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Janata Chicken Chilli', 'janata chicken chilli', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken chilli' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008278, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008278, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008241, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Oyster Chicken', 'oyster chicken', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'oyster chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008279, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008279, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008242, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Schezwan Chicken', 'schezwan chicken', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'schezwan chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008280, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008280, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008243, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken Manchurian', 'chicken manchurian', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008281, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008281, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008244, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken Chilli', 'chicken chilli', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilli' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008282, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008282, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008245, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Hot Garlic', 'hot garlic', 'NON - VEG MAIN COURSE GRAVY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008283, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008283, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008246, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Sweet Garlic', 'sweet garlic', 'NON - VEG MAIN COURSE GRAVY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008284, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008284, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008247, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Hunan Chicken', 'hunan chicken', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'hunan chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008285, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008285, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008248, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Dragon Chicken', 'dragon chicken', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'dragon chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008286, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008286, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008249, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken Kung Pao', 'chicken kung pao', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kung pao' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008287, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008287, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008250, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken Green Chilli', 'chicken green chilli', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken green chilli' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008288, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008288, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008251, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken Black', 'chicken black', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken black' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008289, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008289, new_variant.variant_id, 390.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008252, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken Barbeque Sauce', 'chicken barbeque sauce', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken barbeque sauce' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008290, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008290, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008253, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Lemon Chicken', 'lemon chicken', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'lemon chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008291, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008291, new_variant.variant_id, 390.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NON - VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008254, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008011, 'Chicken 65', 'chicken 65', 'NON - VEG MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken 65' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008292, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008292, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008255, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Kepsa Rice (hunan/chilli/manchurian)', 'chicken kepsa rice (hunan/chilli/manchurian)', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kepsa rice (hunan/chilli/manchurian)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008293, 'Half', FALSE), (400070008294, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008293, 'Half', 610.00, FALSE), (400070008294, 'Full', 1090.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008256, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Mutton Kepsa Rice (hunan/chilli/manchurian)', 'mutton kepsa rice (hunan/chilli/manchurian)', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton kepsa rice (hunan/chilli/manchurian)' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400070008295, 'Half', FALSE), (400070008296, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400070008295, 'Half', 940.00, FALSE), (400070008296, 'Full', 1760.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_prices, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008257, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Janata Rice (gravy)', 'janata rice (gravy)', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008297, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008297, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008258, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Mix Fried Rice', 'mix fried rice', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008298, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008298, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008259, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Malaysian Rice (gravy)', 'malaysian rice (gravy)', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malaysian rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008299, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008299, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008260, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Pot Rice', 'chicken pot rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pot rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008300, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008300, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008261, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Oyster Chilli Rice (gravy)', 'oyster chilli rice (gravy)', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'oyster chilli rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008301, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008301, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008262, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Dragon Rice', 'chicken dragon rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken dragon rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008302, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008302, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008263, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Leg Rice (boneless)', 'leg rice (boneless)', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'leg rice (boneless)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008303, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008303, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008264, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Triple Rice (gravy)', 'chicken triple rice (gravy)', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken triple rice (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008304, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008304, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008265, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Tandoori Fried Rice', 'chicken tandoori fried rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tandoori fried rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008305, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008305, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008266, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Chilli Rice (gravy)', 'chicken chilli rice (gravy)', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilli rice (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008306, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008306, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008267, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Manchurian Rice (gravy)', 'chicken manchurian rice (gravy)', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian rice (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008307, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008307, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008268, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Singapore Rice', 'chicken singapore rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken singapore rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008308, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008308, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008269, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Hong Kong Rice', 'chicken hong kong rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hong kong rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008309, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008309, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008270, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Korean Rice', 'chicken korean rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken korean rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008310, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008310, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008271, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Combination Rice', 'chicken combination rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken combination rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008311, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008311, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008272, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008312, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008312, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008273, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Chicken Fried Rice', 'chicken fried rice', 'RICE NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken fried rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008313, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008313, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008274, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Burn Garlic Rice', 'burn garlic rice', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'burn garlic rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008314, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008314, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RICE NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008275, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008012, 'Egg Fried Rice', 'egg fried rice', 'RICE NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'egg fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008315, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008315, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008276, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Janata Chicken Noodles (gravy)', 'janata chicken noodles (gravy)', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'janata chicken noodles (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008316, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008316, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008277, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Manchurian Noodles (gravy)', 'chicken manchurian noodles (gravy)', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian noodles (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008317, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008317, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008278, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Triple Noodles (gravy)', 'chicken triple noodles (gravy)', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken triple noodles (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008318, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008318, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008279, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Chilli Noodles (gravy)', 'chicken chilli noodles (gravy)', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilli noodles (gravy)' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008319, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008319, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008280, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008320, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008320, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008281, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Singapore Noodles', 'chicken singapore noodles', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken singapore noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008321, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008321, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008282, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Hong Kong Noodles', 'chicken hong kong noodles', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hong kong noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008322, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008322, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008283, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'NOODLES NON-VEG', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hakka noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008323, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008323, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008284, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Burn Garlic Noodles', 'burn garlic noodles', 'NOODLES NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'burn garlic noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008324, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008324, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "NOODLES NON-VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008285, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008013, 'Pan Fried Noodles (gravy)', 'pan fried noodles (gravy)', 'NOODLES NON-VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pan fried noodles (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008325, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008325, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHOP SUEY NON - VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008286, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008014, 'American Chop Suey', 'american chop suey', 'CHOP SUEY NON - VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'american chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008326, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008326, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHOP SUEY NON - VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008287, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008014, 'Chinese Chop Suey', 'chinese chop suey', 'CHOP SUEY NON - VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008327, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008327, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CHOP SUEY NON - VEG" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008288, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008014, 'Chowmin Chop Suey', 'chowmin chop suey', 'CHOP SUEY NON - VEG', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chowmin chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008328, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008328, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008289, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Oyster Sauce', 'prawns oyster sauce', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-oyster-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns oyster sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008329, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008329, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008290, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Oyster Sauce', 'fish oyster sauce', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-oyster-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish oyster sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008330, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008330, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008291, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Barbeque Sauce', 'prawns barbeque sauce', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-barbeque-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns barbeque sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008331, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008331, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008292, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Barbeque Sauce', 'fish barbeque sauce', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-barbeque-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish barbeque sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008332, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008332, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008293, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Chilli', 'prawns chilli', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-chilli', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns chilli' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008333, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008333, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008294, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Chilli', 'fish chilli', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-chilli', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish chilli' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008334, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008334, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008295, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Manchurian', 'prawns manchurian', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-manchurian', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns manchurian' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008335, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008335, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008296, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Manchurian', 'fish manchurian', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-manchurian', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish manchurian' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008336, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008336, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008297, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Butter Garlic', 'prawns butter garlic', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns butter garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008337, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008337, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008298, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Butter Garlic', 'fish butter garlic', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish butter garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008338, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008338, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008299, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Sweet Garlic', 'prawns sweet garlic', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-sweet-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns sweet garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008339, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008339, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008300, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Sweet Garlic', 'fish sweet garlic', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-sweet-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish sweet garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008340, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008340, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008301, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Hot Garlic', 'prawns hot garlic', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hot garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008341, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008341, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008302, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Hot Garlic', 'fish hot garlic', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish hot garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008342, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008342, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008303, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Schezwan', 'prawns schezwan', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-schezwan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns schezwan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008343, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008343, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008304, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Schezwan', 'fish schezwan', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-schezwan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish schezwan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008344, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008344, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008305, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Kung Pao', 'prawns kung pao', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-kung-pao', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns kung pao' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008345, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008345, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008306, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Kung Pao', 'fish kung pao', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-kung-pao', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish kung pao' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008346, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008346, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008307, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Hunan', 'prawns hunan', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-hunan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hunan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008347, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008347, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008308, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Hunan', 'fish hunan', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-hunan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish hunan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008348, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008348, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008309, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Black Pepper', 'prawns black pepper', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-black-pepper', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns black pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008349, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008349, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008310, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Black Pepper', 'fish black pepper', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-black-pepper', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish black pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008350, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008350, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008311, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Seafood 65', 'prawns seafood 65', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-seafood-65', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns seafood 65' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008351, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008351, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008312, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Seafood 65', 'fish seafood 65', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-seafood-65', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish seafood 65' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008352, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008352, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008313, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Lemon', 'prawns lemon', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-lemon', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns lemon' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008353, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008353, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008314, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Fish Lemon', 'fish lemon', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'split-seafood-starters-lemon', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish lemon' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008354, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008354, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008315, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008015, 'Prawns Prawns Crispy', 'prawns prawns crispy', 'SEAFOOD STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns prawns crispy' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008355, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008355, new_variant.variant_id, 510.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008316, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Oyster Sauce', 'prawns oyster sauce', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-oyster-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns oyster sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008356, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008356, new_variant.variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008317, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Oyster Sauce', 'fish oyster sauce', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-oyster-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish oyster sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008357, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008357, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008318, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Barbeque Sauce', 'prawns barbeque sauce', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-barbeque-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns barbeque sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008358, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008358, new_variant.variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008319, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Barbeque Sauce', 'fish barbeque sauce', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-barbeque-sauce', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish barbeque sauce' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008359, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008359, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008320, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Chilli', 'prawns chilli', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-chilli', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns chilli' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008360, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008360, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008321, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Chilli', 'fish chilli', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-chilli', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish chilli' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008361, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008361, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008322, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Manchurian', 'prawns manchurian', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-manchurian', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns manchurian' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008362, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008362, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008323, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Manchurian', 'fish manchurian', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-manchurian', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish manchurian' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008363, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008363, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008324, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Butter Garlic', 'prawns butter garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns butter garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008364, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008364, new_variant.variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008325, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Butter Garlic', 'fish butter garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-butter-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish butter garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008365, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008365, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008326, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Sweet Garlic', 'prawns sweet garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-sweet-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns sweet garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008366, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008366, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008327, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Sweet Garlic', 'fish sweet garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-sweet-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish sweet garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008367, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008367, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008328, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Sweet Garlic', 'prawns sweet garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-sweet-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns sweet garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008368, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008368, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008329, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Sweet Garlic', 'fish sweet garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-sweet-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish sweet garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008369, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008369, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008330, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Hot Garlic', 'prawns hot garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hot garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008370, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008370, new_variant.variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008331, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Hot Garlic', 'fish hot garlic', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-hot-garlic', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish hot garlic' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008371, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008371, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008332, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Schezwan', 'prawns schezwan', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-schezwan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns schezwan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008372, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008372, new_variant.variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008333, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Schezwan', 'fish schezwan', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-schezwan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish schezwan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008373, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008373, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008334, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Kung Pao', 'prawns kung pao', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-kung-pao', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns kung pao' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008374, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008374, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008335, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Kung Pao', 'fish kung pao', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-kung-pao', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish kung pao' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008375, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008375, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008336, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Hunan', 'prawns hunan', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-hunan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hunan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008376, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008376, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008337, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Hunan', 'fish hunan', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-hunan', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish hunan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008377, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008377, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008338, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Prawns Black Pepper', 'prawns black pepper', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-black-pepper', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns black pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008378, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008378, new_variant.variant_id, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070008339, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008016, 'Fish Black Pepper', 'fish black pepper', 'SEAFOOD MAIN COURSE GRAVY', 'non_veg', pt.protein_type_id, 'split-seafood-main-course-gravy-black-pepper', 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish black pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008379, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008379, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008340, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Janata Rice (gravy)', 'prawns janata rice (gravy)', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns janata rice (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008380, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008380, new_variant.variant_id, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008341, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Dragon Rice', 'prawns dragon rice', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns dragon rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008381, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008381, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008342, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Chilli Rice (gravy)', 'prawns chilli rice (gravy)', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns chilli rice (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008382, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008382, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008343, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Pot Rice (gravy)', 'prawns pot rice (gravy)', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns pot rice (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008383, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008383, new_variant.variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008344, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Manchurian Rice (gravy)', 'prawns manchurian rice (gravy)', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns manchurian rice (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008384, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008384, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008345, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Oyster Chilli Rice (gravy)', 'prawns oyster chilli rice (gravy)', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns oyster chilli rice (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008385, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008385, new_variant.variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008346, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Triple Rice (gravy)', 'prawns triple rice (gravy)', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns triple rice (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008386, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008386, new_variant.variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008347, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Singapore Rice', 'prawns singapore rice', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns singapore rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008387, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008387, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008348, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Schezwan Rice', 'prawns schezwan rice', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns schezwan rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008388, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008388, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008349, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Hong Kong Rice', 'prawns hong kong rice', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hong kong rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008389, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008389, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008350, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Fried Rice', 'prawns fried rice', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns fried rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008390, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008390, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008351, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008017, 'Prawns Burn Garlic Rice', 'prawns burn garlic rice', 'SEAFOOD RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns burn garlic rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008391, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008391, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008352, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Janata Noodles (gravy)', 'prawns janata noodles (gravy)', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns janata noodles (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008392, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008392, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008353, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Hakka Noodles', 'prawns hakka noodles', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hakka noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008393, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008393, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008354, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Pan Fried Noodles (gravy)', 'prawns pan fried noodles (gravy)', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns pan fried noodles (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008394, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008394, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008355, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns schezwan noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008395, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008395, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008356, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Singapore Noodles', 'prawns singapore noodles', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns singapore noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008396, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008396, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008357, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Chilli Noodles (gravy)', 'prawns chilli noodles (gravy)', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns chilli noodles (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008397, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008397, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008358, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Burn Garlic Noodles', 'prawns burn garlic noodles', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns burn garlic noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008398, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008398, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008359, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Hong Kong Noodles', 'prawns hong kong noodles', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns hong kong noodles' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008399, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008399, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008360, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Manchurian (gravy)', 'prawns manchurian (gravy)', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns manchurian (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008400, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008400, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008361, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008018, 'Prawns Triple Noodles (gravy)', 'prawns triple noodles (gravy)', 'SEAFOOD NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns triple noodles (gravy)' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008401, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008401, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008362, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008019, 'American Chop Suey', 'american chop suey', 'SEAFOOD CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'american chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008402, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008402, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008363, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008019, 'Chinese Chop Suey', 'chinese chop suey', 'SEAFOOD CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008403, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008403, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SEAFOOD CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008364, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008019, 'Chowmin Chop Suey', 'chowmin chop suey', 'SEAFOOD CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chowmin chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008404, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008404, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008365, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008020, 'Janata Veg Soup', 'janata veg soup', 'VEG SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'janata veg soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008405, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008405, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008366, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008020, 'Veg Hot N'' Soup', 'veg hot n'' soup', 'VEG SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hot n'' soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008406, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008406, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008367, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008020, 'Veg Clear Soup', 'veg clear soup', 'VEG SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg clear soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008407, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008407, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008368, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008020, 'Veg Sweet Corn Soup', 'veg sweet corn soup', 'VEG SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg sweet corn soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008408, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008408, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008369, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008020, 'Veg Manchow Soup', 'veg manchow soup', 'VEG SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg manchow soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008409, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008409, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008370, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Thread', 'paneer thread', 'VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer thread'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008410, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008410, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008371, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Crispy', 'paneer crispy', 'VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008411, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008411, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008372, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Veg. Crispy', 'veg. crispy', 'VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008412, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008412, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008373, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Rolls Dragon', 'rolls dragon', 'VEG STARTERS', 'veg', 'split-veg-starters-rollsdragonpaneerspring', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rolls dragon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008413, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008413, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008374, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Rolls Paneer', 'rolls paneer', 'VEG STARTERS', 'veg', 'split-veg-starters-rollsdragonpaneerspring', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rolls paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008414, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008414, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008375, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Rolls Spring', 'rolls spring', 'VEG STARTERS', 'veg', 'split-veg-starters-rollsdragonpaneerspring', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rolls spring'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008415, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008415, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008376, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Chilli', 'paneer chilli', 'VEG STARTERS', 'veg', 'split-veg-starters-paneerchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008416, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008416, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008377, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Manchurian', 'paneer manchurian', 'VEG STARTERS', 'veg', 'split-veg-starters-paneerchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008417, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008417, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008378, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer (black Pepper)', 'paneer (black pepper)', 'VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer (black pepper)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008418, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008418, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008379, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Butter Garlic', 'paneer butter garlic', 'VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008419, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008419, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008380, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Schezwan', 'paneer schezwan', 'VEG STARTERS', 'veg', 'split-veg-starters-paneerschezwankung-paohunanbbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008420, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008420, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008381, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Kung Pao', 'paneer kung pao', 'VEG STARTERS', 'veg', 'split-veg-starters-paneerschezwankung-paohunanbbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kung pao'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008421, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008421, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008382, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Hunan', 'paneer hunan', 'VEG STARTERS', 'veg', 'split-veg-starters-paneerschezwankung-paohunanbbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008422, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008422, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008383, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Paneer Bbeque', 'paneer bbeque', 'VEG STARTERS', 'veg', 'split-veg-starters-paneerschezwankung-paohunanbbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer bbeque'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008423, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008423, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008384, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Potato Crispy', 'potato crispy', 'VEG STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008424, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008424, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008385, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Baby Corn & Mushroom Chilli', 'baby corn & mushroom chilli', 'VEG STARTERS', 'veg', 'split-veg-starters-baby-corn-&-mushroomchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008425, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008425, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008386, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Baby Corn & Mushroom Manchurian', 'baby corn & mushroom manchurian', 'VEG STARTERS', 'veg', 'split-veg-starters-baby-corn-&-mushroomchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008426, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008426, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008387, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Baby Corn & Mushroom Green Chilli', 'baby corn & mushroom green chilli', 'VEG STARTERS', 'veg', 'split-veg-starters-baby-corn-&-mushroomgreen-chilliblack-pe', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom green chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008427, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008427, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008388, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Baby Corn & Mushroom Black Pepper', 'baby corn & mushroom black pepper', 'VEG STARTERS', 'veg', 'split-veg-starters-baby-corn-&-mushroomgreen-chilliblack-pe', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom black pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008428, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008428, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008389, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Baby Corn & Mushroom Hot Garlic', 'baby corn & mushroom hot garlic', 'VEG STARTERS', 'veg', 'split-veg-starters-baby-corn-&-mushroomhot-garlicsweet-garl', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008429, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008429, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008390, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Baby Corn & Mushroom Sweet Garlic', 'baby corn & mushroom sweet garlic', 'VEG STARTERS', 'veg', 'split-veg-starters-baby-corn-&-mushroomhot-garlicsweet-garl', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom sweet garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008430, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008430, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008391, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Chilli', 'cauliflower chilli', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008431, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008431, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008392, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Manchurian', 'cauliflower manchurian', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008432, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008432, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008393, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Hongkong', 'cauliflower hongkong', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerhongkongschezwan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower hongkong'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008433, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008433, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008394, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Schezwan', 'cauliflower schezwan', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerhongkongschezwan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008434, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008434, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008395, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Kung Pao', 'cauliflower kung pao', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerkung-paohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower kung pao'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008435, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008435, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008396, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Hunan', 'cauliflower hunan', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerkung-paohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008436, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008436, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008397, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Barbeque', 'cauliflower barbeque', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowerkung-paohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower barbeque'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008437, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008437, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008398, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Green Chilli', 'cauliflower green chilli', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowergreen-chilliblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower green chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008438, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008438, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008399, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008021, 'Cauliflower Black Pepper', 'cauliflower black pepper', 'VEG STARTERS', 'veg', 'split-veg-starters-cauliflowergreen-chilliblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower black pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008439, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008439, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008400, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Chilli', 'paneer chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-paneer-chilli-manch-drag', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008440, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008440, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008401, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Manchurian', 'paneer manchurian', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-paneer-chilli-manch-drag', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008441, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008441, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008402, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Dragon', 'paneer dragon', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-paneer-chilli-manch-drag', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer dragon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008442, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008442, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008403, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Butter Garlic', 'paneer butter garlic', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-paneer-chilli-manch-drag', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008443, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008443, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008404, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Schezwan', 'paneer schezwan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-paneerschezwankungpaohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008444, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008444, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008405, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Kungpao', 'paneer kungpao', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-paneerschezwankungpaohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kungpao'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008445, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008445, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008406, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Hunan', 'paneer hunan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-paneerschezwankungpaohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008446, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008446, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008407, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Barbeque', 'paneer barbeque', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-paneerschezwankungpaohunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer barbeque'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008447, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008447, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008408, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Green Chilli', 'paneer green chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-paneergreen-chilliblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer green chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008448, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008448, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008409, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Paneer Black Pepper', 'paneer black pepper', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-paneergreen-chilliblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer black pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008449, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008449, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008410, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Chilli', 'baby corn & mushroom chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-&-mushroomchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008450, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008450, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008411, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Manchurian', 'baby corn & mushroom manchurian', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-&-mushroomchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008451, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008451, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008412, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Schezwan', 'baby corn & mushroom schezwan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-&-mushroomschezwankung-pao', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008452, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008452, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008413, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Kung Pao', 'baby corn & mushroom kung pao', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-&-mushroomschezwankung-pao', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom kung pao'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008453, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008453, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008414, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Hunan', 'baby corn & mushroom hunan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-&-mushroomhunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008454, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008454, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008415, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Barbeque', 'baby corn & mushroom barbeque', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-&-mushroomhunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom barbeque'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008455, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008455, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008416, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom (black Pepper)', 'baby corn & mushroom (black pepper)', 'VEG MAIN COURSE GRAVY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom (black pepper)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008456, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008456, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008417, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Hot Garlic', 'baby corn & mushroom hot garlic', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-mushroomhot-sweet-garl', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008457, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008457, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008418, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Baby Corn & Mushroom Sweet Garlic', 'baby corn & mushroom sweet garlic', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-baby-corn-mushroomhot-sweet-garl', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn & mushroom sweet garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008458, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008458, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008419, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Cauliflower Chilli', 'cauliflower chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-cauliflower-chilli-manch', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008459, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008459, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008420, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Cauliflower Manchurian', 'cauliflower manchurian', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-cauliflower-chilli-manch', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008460, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008460, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008421, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Cauliflower Black Pepper', 'cauliflower black pepper', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-mcg-cauliflower-chilli-manch', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower black pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008461, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008461, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008422, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Cauliflower Schezwan', 'cauliflower schezwan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-cauliflowerschezwanhunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008462, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008462, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008423, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Cauliflower Hunan', 'cauliflower hunan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-cauliflowerschezwanhunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cauliflower hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008463, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008463, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008424, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Chilli', 'veg. bowl chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008464, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008464, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008425, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Manchurian', 'veg. bowl manchurian', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlchillimanchurian', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008465, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008465, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008426, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Schezwan', 'veg. bowl schezwan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlschezwankung-paohunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008466, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008466, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008427, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Kung Pao', 'veg. bowl kung pao', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlschezwankung-paohunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl kung pao'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008467, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008467, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008428, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Hunan', 'veg. bowl hunan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlschezwankung-paohunan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008468, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008468, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008429, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Green Chilli', 'veg. bowl green chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlgreen-chilliblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl green chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008469, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008469, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008430, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Black Pepper', 'veg. bowl black pepper', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlgreen-chilliblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl black pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008470, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008470, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008431, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Hot Garlic', 'veg. bowl hot garlic', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlhot-garlicsweet-garlic', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008471, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008471, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008432, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Veg. Bowl Sweet Garlic', 'veg. bowl sweet garlic', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-veg.-bowlhot-garlicsweet-garlic', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bowl sweet garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008472, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008472, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008433, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Chilli', 'potato chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatochillimanchurianblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008473, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008473, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008434, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Manchurian', 'potato manchurian', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatochillimanchurianblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008474, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008474, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008435, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Black Pepper', 'potato black pepper', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatochillimanchurianblack-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato black pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008475, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008475, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008436, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Schezwan', 'potato schezwan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatoschezwanhunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008476, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008476, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008437, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Hunan', 'potato hunan', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatoschezwanhunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008477, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008477, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008438, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Barbeque', 'potato barbeque', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatoschezwanhunanbarbeque', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato barbeque'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008478, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008478, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008439, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Ginger', 'potato ginger', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatogingerred-chillidragon', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato ginger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008479, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008479, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008440, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Red Chilli', 'potato red chilli', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatogingerred-chillidragon', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato red chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008480, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008480, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG MAIN COURSE GRAVY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400070008441, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008022, 'Potato Dragon', 'potato dragon', 'VEG MAIN COURSE GRAVY', 'veg', 'split-veg-main-course-gravy-potatogingerred-chillidragon', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato dragon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008481, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008481, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008442, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Janata Noodles (gravy)', 'veg janata noodles (gravy)', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg janata noodles (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008482, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008482, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008443, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Manchurian Noodles (gravy)', 'veg manchurian noodles (gravy)', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg manchurian noodles (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008483, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008483, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008444, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Triple Noodles (gravy)', 'veg triple noodles (gravy)', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg triple noodles (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008484, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008484, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008445, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Chilli Noodles (gravy)', 'veg chilli noodles (gravy)', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chilli noodles (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008485, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008485, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008446, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Schezwan Noodles', 'veg schezwan noodles', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008486, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008486, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008447, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Singapore Noodles', 'veg singapore noodles', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg singapore noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008487, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008487, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008448, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Hongkong Noodles', 'veg hongkong noodles', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hongkong noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008488, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008488, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008449, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Hakka Noodles', 'veg hakka noodles', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hakka noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008489, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008489, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008450, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Veg Burn Garlic Noodles', 'veg burn garlic noodles', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg burn garlic noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008490, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008490, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008451, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008023, 'Pan Fry Noodles (gravy)', 'pan fry noodles (gravy)', 'VEG NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pan fry noodles (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008491, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008491, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008452, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Janata Rice (gravy)', 'veg janata rice (gravy)', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg janata rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008492, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008492, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008453, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Chilli Rice (gravy)', 'veg chilli rice (gravy)', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chilli rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008493, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008493, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008454, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Triple Rice (gravy)', 'veg triple rice (gravy)', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg triple rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008494, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008494, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008455, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Manchurian Rice (gravy)', 'veg manchurian rice (gravy)', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg manchurian rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008495, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008495, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008456, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Schezwan Rice', 'veg schezwan rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008496, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008496, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008457, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Pot Rice (gravy)', 'veg pot rice (gravy)', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg pot rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008497, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008497, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008458, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Burn Garlic Rice', 'veg burn garlic rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg burn garlic rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008498, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008498, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008459, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Mushroom Rice', 'mushroom rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008499, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008499, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008460, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Paneer Fried Rice', 'paneer fried rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008500, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008500, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008461, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Paneer Chilli Rice (gravy)', 'paneer chilli rice (gravy)', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli rice (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008501, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008501, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008462, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg Hongkong Rice', 'veg hongkong rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hongkong rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008502, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008502, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008463, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg. Singapore Rice', 'veg. singapore rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. singapore rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008503, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008503, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008464, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Paneer Mushroom Rice', 'paneer mushroom rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mushroom rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008504, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008504, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008465, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008024, 'Veg. Fried Rice', 'veg. fried rice', 'VEG RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008505, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008505, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008466, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008025, 'Veg American Chop Suey', 'veg american chop suey', 'VEG CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg american chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008506, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008506, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008467, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008025, 'Veg Chinese Chop Suey', 'veg chinese chop suey', 'VEG CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chinese chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008507, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008507, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008468, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008025, 'Veg Chowmin Chop Suey', 'veg chowmin chop suey', 'VEG CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chowmin chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008508, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008508, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "VEG CHOP SUEY" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008469, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008025, 'Mix Chop Suey', 'mix chop suey', 'VEG CHOP SUEY', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix chop suey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008509, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008509, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008470, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Bheja Roll', 'bheja roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bheja roll' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008510, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008510, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008471, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Mutton Roll', 'mutton roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton roll' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008511, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008511, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008472, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Mutton Cheese Roll', 'mutton cheese roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton cheese roll' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008512, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008512, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008473, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Mutton Egg Roti', 'mutton egg roti', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton egg roti' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008513, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008513, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008474, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Mutton Cheese Egg Roti', 'mutton cheese egg roti', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton cheese egg roti' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008514, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008514, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008475, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Gurda Roll', 'gurda roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'gurda roll' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008515, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008515, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008476, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Roll', 'chicken roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008516, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008516, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008477, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Cheese Roll', 'chicken cheese roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cheese roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008517, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008517, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008478, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Egg Roti', 'chicken egg roti', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken egg roti' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008518, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008518, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008479, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Cheese Egg Roti', 'chicken cheese egg roti', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken cheese egg roti' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008519, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008519, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008480, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Naan Chaap', 'chicken naan chaap', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken naan chaap' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008520, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008520, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008481, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Mutton Naan Chaap', 'mutton naan chaap', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton naan chaap' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008521, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008521, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008482, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Tikka Roll', 'chicken tikka roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008522, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008522, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070008483, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Chicken Tikka Cheese Roll', 'chicken tikka cheese roll', 'TAWA ROLLS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka cheese roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008523, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008523, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008484, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Paneer Roll', 'paneer roll', 'TAWA ROLLS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008524, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008524, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008485, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Paneer Cheese Roll', 'paneer cheese roll', 'TAWA ROLLS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer cheese roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008525, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008525, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008486, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Paneer Tikka Roll', 'paneer tikka roll', 'TAWA ROLLS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008526, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008526, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TAWA ROLLS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008487, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008026, 'Paneer Tikka Cheese Roll', 'paneer tikka cheese roll', 'TAWA ROLLS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka cheese roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008527, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008527, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008488, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Tandoori Roti (wheat)', 'tandoori roti (wheat)', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tandoori roti (wheat)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008528, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008528, new_variant.variant_id, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008489, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Tandoori Butter Roti (wheat)', 'tandoori butter roti (wheat)', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tandoori butter roti (wheat)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008529, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008529, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008490, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Roomali Roti', 'roomali roti', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roomali roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008530, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008530, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008491, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Lachha Paratha (wheat)', 'lachha paratha (wheat)', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lachha paratha (wheat)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008531, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008531, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008492, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Butter Naan', 'butter naan', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008532, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008532, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008493, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Kulcha Paratha', 'kulcha paratha', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulcha paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008533, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008533, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008494, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Kamachi Naan', 'kamachi naan', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kamachi naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008534, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008534, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008495, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Garlic Naan', 'garlic naan', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008535, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008535, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008496, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Samosa Butter Naan', 'samosa butter naan', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'samosa butter naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008536, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008536, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008497, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Cheese Garlic Naan', 'cheese garlic naan', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008537, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008537, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008498, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008027, 'Cheese Naan', 'cheese naan', 'ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008538, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008538, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008499, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Shahi Tukda', 'shahi tukda', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'shahi tukda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008539, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008539, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008500, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Caramel Custard', 'caramel custard', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'caramel custard'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008540, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008540, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008501, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Rabdi', 'rabdi', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rabdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008541, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008541, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008502, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Chocolate Mouse', 'chocolate mouse', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate mouse'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008542, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008542, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008503, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Arabian Pudding', 'arabian pudding', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'arabian pudding'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008543, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008543, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008504, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Mix Fruit Cream', 'mix fruit cream', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fruit cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008544, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008544, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008505, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Sitafal Cream (seasonal)', 'sitafal cream (seasonal)', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sitafal cream (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008545, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008545, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008506, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Mango Cream (seasonal)', 'mango cream (seasonal)', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango cream (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008546, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008546, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008507, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Strawberry Cream (seasonal)', 'strawberry cream (seasonal)', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry cream (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008547, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008547, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008508, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Brownie With-ice-cream', 'brownie with-ice-cream', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'brownie with-ice-cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008548, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008548, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008509, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Chocolate Lava', 'chocolate lava', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate lava'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008549, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008549, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400070008510, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008028, 'Gulab Jamun', 'gulab jamun', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'gulab jamun'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008550, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008550, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008511, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Plain Dahi', 'plain dahi', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain dahi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008551, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008551, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008512, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Boondi Raita', 'boondi raita', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'boondi raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008552, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008552, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008513, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Mix Raita', 'mix raita', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008553, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008553, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008514, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Raita', 'raita', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008554, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008554, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008515, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Green Salad', 'green salad', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008555, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008555, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008516, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Fruit Salad', 'fruit salad', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008556, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008556, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008517, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Fruit Salad With Ice Cream', 'fruit salad with ice cream', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad with ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008557, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008557, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008518, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Papad', 'papad', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008558, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008558, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008519, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Masala Papad', 'masala papad', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008559, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008559, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008520, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Rice Papad', 'rice papad', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rice papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008560, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008560, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008521, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Fry Noodle', 'fry noodle', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fry noodle'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008561, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008561, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008522, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008029, 'Schezwan Souce', 'schezwan souce', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan souce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008562, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008562, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008523, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Virgin Mojito', 'virgin mojito', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'virgin mojito'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008563, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008563, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008524, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Strawberry', 'strawberry', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008564, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008564, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008525, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Blue Lagoon', 'blue lagoon', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'blue lagoon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008565, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008565, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008526, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Mango Mojito', 'mango mojito', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango mojito'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008566, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008566, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008527, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Sweet & Salty', 'sweet & salty', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet & salty'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008567, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008567, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008528, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Sweet', 'sweet', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008568, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008568, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008529, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Salty', 'salty', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'salty'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008569, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008569, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MOCKTAIL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400070008530, ctx.restaurant_id, item_cd.canonical_dish_id, 400070008030, 'Fruit Punch', 'fruit punch', 'MOCKTAIL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit punch'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070008570, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070008570, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
SELECT 400070008001, ctx.restaurant_id, 'Main Menu', 'a_la_carte' FROM khaustan_onboarding_ctx ctx;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT ctx.restaurant_id, 400070008001, x.menu_category_id, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070008001, 1), (400070008002, 2), (400070008003, 3), (400070008004, 4), (400070008005, 5), (400070008006, 6), (400070008007, 7), (400070008008, 8), (400070008009, 9), (400070008010, 10), (400070008011, 11), (400070008012, 12), (400070008013, 13), (400070008014, 14), (400070008015, 15), (400070008016, 16), (400070008017, 17), (400070008018, 18), (400070008019, 19), (400070008020, 20), (400070008021, 21), (400070008022, 22), (400070008023, 23), (400070008024, 24), (400070008025, 25), (400070008026, 26), (400070008027, 27), (400070008028, 28), (400070008029, 29), (400070008030, 30)) AS x(menu_category_id, display_sequence);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence, is_featured)
SELECT x.menu_board_item_id, ctx.restaurant_id, 400070008001, x.menu_item_id, x.menu_category_id, x.display_sequence, x.is_featured
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400070008001, 400070008001, 400070008001, 1, FALSE), (400070008002, 400070008002, 400070008001, 2, FALSE), (400070008003, 400070008003, 400070008001, 3, FALSE), (400070008004, 400070008004, 400070008001, 4, FALSE), (400070008005, 400070008005, 400070008001, 5, FALSE), (400070008006, 400070008006, 400070008001, 6, FALSE), (400070008007, 400070008007, 400070008001, 7, FALSE), (400070008008, 400070008008, 400070008001, 8, FALSE), (400070008009, 400070008009, 400070008001, 9, FALSE), (400070008010, 400070008010, 400070008001, 10, FALSE), (400070008011, 400070008011, 400070008001, 11, FALSE), (400070008012, 400070008012, 400070008001, 12, FALSE), (400070008013, 400070008013, 400070008001, 13, FALSE), (400070008014, 400070008014, 400070008001, 14, FALSE), (400070008015, 400070008015, 400070008001, 15, FALSE), (400070008016, 400070008016, 400070008001, 16, FALSE), (400070008017, 400070008017, 400070008001, 17, FALSE), (400070008018, 400070008018, 400070008001, 18, FALSE), (400070008019, 400070008019, 400070008001, 19, FALSE), (400070008020, 400070008020, 400070008001, 20, FALSE), (400070008021, 400070008021, 400070008001, 21, FALSE), (400070008022, 400070008022, 400070008001, 22, FALSE), (400070008023, 400070008023, 400070008001, 23, FALSE), (400070008024, 400070008024, 400070008001, 24, FALSE), (400070008025, 400070008025, 400070008001, 25, FALSE), (400070008026, 400070008026, 400070008001, 26, FALSE), (400070008027, 400070008027, 400070008001, 27, FALSE), (400070008028, 400070008028, 400070008001, 28, FALSE), (400070008029, 400070008029, 400070008001, 29, FALSE), (400070008030, 400070008030, 400070008001, 30, FALSE), (400070008031, 400070008031, 400070008001, 31, FALSE), (400070008032, 400070008032, 400070008001, 32, FALSE), (400070008033, 400070008033, 400070008001, 33, FALSE), (400070008034, 400070008034, 400070008001, 34, FALSE), (400070008035, 400070008035, 400070008001, 35, FALSE), (400070008036, 400070008036, 400070008001, 36, FALSE), (400070008037, 400070008037, 400070008001, 37, FALSE), (400070008038, 400070008038, 400070008001, 38, FALSE), (400070008039, 400070008039, 400070008001, 39, FALSE), (400070008040, 400070008040, 400070008001, 40, FALSE), (400070008041, 400070008041, 400070008001, 41, FALSE), (400070008042, 400070008042, 400070008001, 42, FALSE), (400070008043, 400070008043, 400070008001, 43, FALSE), (400070008044, 400070008044, 400070008001, 44, FALSE), (400070008045, 400070008045, 400070008001, 45, FALSE), (400070008046, 400070008046, 400070008001, 46, FALSE), (400070008047, 400070008047, 400070008001, 47, FALSE), (400070008048, 400070008048, 400070008001, 48, FALSE), (400070008049, 400070008049, 400070008001, 49, FALSE), (400070008050, 400070008050, 400070008001, 50, FALSE), (400070008051, 400070008051, 400070008001, 51, FALSE), (400070008052, 400070008052, 400070008002, 52, FALSE), (400070008053, 400070008053, 400070008002, 53, FALSE), (400070008054, 400070008054, 400070008002, 54, FALSE), (400070008055, 400070008055, 400070008002, 55, FALSE), (400070008056, 400070008056, 400070008002, 56, FALSE), (400070008057, 400070008057, 400070008002, 57, FALSE), (400070008058, 400070008058, 400070008002, 58, FALSE), (400070008059, 400070008059, 400070008002, 59, FALSE), (400070008060, 400070008060, 400070008002, 60, FALSE), (400070008061, 400070008061, 400070008002, 61, FALSE), (400070008062, 400070008062, 400070008002, 62, FALSE), (400070008063, 400070008063, 400070008002, 63, FALSE), (400070008064, 400070008064, 400070008002, 64, FALSE), (400070008065, 400070008065, 400070008002, 65, FALSE), (400070008066, 400070008066, 400070008002, 66, FALSE), (400070008067, 400070008067, 400070008002, 67, FALSE), (400070008068, 400070008068, 400070008002, 68, FALSE), (400070008069, 400070008069, 400070008002, 69, FALSE), (400070008070, 400070008070, 400070008002, 70, FALSE), (400070008071, 400070008071, 400070008002, 71, FALSE), (400070008072, 400070008072, 400070008002, 72, FALSE), (400070008073, 400070008073, 400070008002, 73, FALSE), (400070008074, 400070008074, 400070008002, 74, FALSE), (400070008075, 400070008075, 400070008002, 75, FALSE), (400070008076, 400070008076, 400070008002, 76, FALSE), (400070008077, 400070008077, 400070008002, 77, FALSE), (400070008078, 400070008078, 400070008002, 78, FALSE), (400070008079, 400070008079, 400070008002, 79, FALSE), (400070008080, 400070008080, 400070008002, 80, FALSE), (400070008081, 400070008081, 400070008002, 81, FALSE), (400070008082, 400070008082, 400070008002, 82, FALSE), (400070008083, 400070008083, 400070008002, 83, FALSE), (400070008084, 400070008084, 400070008002, 84, FALSE), (400070008085, 400070008085, 400070008002, 85, FALSE), (400070008086, 400070008086, 400070008002, 86, FALSE), (400070008087, 400070008087, 400070008002, 87, FALSE), (400070008088, 400070008088, 400070008002, 88, FALSE), (400070008089, 400070008089, 400070008002, 89, FALSE), (400070008090, 400070008090, 400070008002, 90, FALSE), (400070008091, 400070008091, 400070008002, 91, FALSE), (400070008092, 400070008092, 400070008002, 92, FALSE), (400070008093, 400070008093, 400070008002, 93, FALSE), (400070008094, 400070008094, 400070008002, 94, FALSE), (400070008095, 400070008095, 400070008002, 95, FALSE), (400070008096, 400070008096, 400070008002, 96, FALSE), (400070008097, 400070008097, 400070008002, 97, FALSE), (400070008098, 400070008098, 400070008002, 98, FALSE), (400070008099, 400070008099, 400070008002, 99, FALSE), (400070008100, 400070008100, 400070008003, 100, FALSE), (400070008101, 400070008101, 400070008003, 101, FALSE), (400070008102, 400070008102, 400070008003, 102, FALSE), (400070008103, 400070008103, 400070008003, 103, FALSE), (400070008104, 400070008104, 400070008003, 104, FALSE), (400070008105, 400070008105, 400070008003, 105, FALSE), (400070008106, 400070008106, 400070008003, 106, FALSE), (400070008107, 400070008107, 400070008003, 107, FALSE), (400070008108, 400070008108, 400070008003, 108, FALSE), (400070008109, 400070008109, 400070008003, 109, FALSE), (400070008110, 400070008110, 400070008003, 110, FALSE), (400070008111, 400070008111, 400070008003, 111, FALSE), (400070008112, 400070008112, 400070008003, 112, FALSE), (400070008113, 400070008113, 400070008003, 113, FALSE), (400070008114, 400070008114, 400070008003, 114, FALSE), (400070008115, 400070008115, 400070008003, 115, FALSE), (400070008116, 400070008116, 400070008003, 116, FALSE), (400070008117, 400070008117, 400070008004, 117, FALSE), (400070008118, 400070008118, 400070008004, 118, FALSE), (400070008119, 400070008119, 400070008004, 119, FALSE), (400070008120, 400070008120, 400070008004, 120, FALSE), (400070008121, 400070008121, 400070008004, 121, FALSE), (400070008122, 400070008122, 400070008004, 122, FALSE), (400070008123, 400070008123, 400070008004, 123, FALSE), (400070008124, 400070008124, 400070008004, 124, FALSE), (400070008125, 400070008125, 400070008004, 125, FALSE), (400070008126, 400070008126, 400070008004, 126, FALSE), (400070008127, 400070008127, 400070008004, 127, FALSE), (400070008128, 400070008128, 400070008004, 128, FALSE), (400070008129, 400070008129, 400070008004, 129, FALSE), (400070008130, 400070008130, 400070008004, 130, FALSE), (400070008131, 400070008131, 400070008004, 131, FALSE), (400070008132, 400070008132, 400070008004, 132, FALSE), (400070008133, 400070008133, 400070008004, 133, FALSE), (400070008134, 400070008134, 400070008004, 134, FALSE), (400070008135, 400070008135, 400070008004, 135, FALSE), (400070008136, 400070008136, 400070008004, 136, FALSE), (400070008137, 400070008137, 400070008004, 137, FALSE), (400070008138, 400070008138, 400070008004, 138, FALSE), (400070008139, 400070008139, 400070008005, 139, FALSE), (400070008140, 400070008140, 400070008005, 140, FALSE), (400070008141, 400070008141, 400070008005, 141, FALSE), (400070008142, 400070008142, 400070008005, 142, FALSE), (400070008143, 400070008143, 400070008005, 143, FALSE), (400070008144, 400070008144, 400070008005, 144, FALSE), (400070008145, 400070008145, 400070008006, 145, FALSE), (400070008146, 400070008146, 400070008006, 146, FALSE), (400070008147, 400070008147, 400070008006, 147, FALSE), (400070008148, 400070008148, 400070008006, 148, FALSE), (400070008149, 400070008149, 400070008006, 149, FALSE), (400070008150, 400070008150, 400070008006, 150, FALSE), (400070008151, 400070008151, 400070008006, 151, FALSE), (400070008152, 400070008152, 400070008006, 152, FALSE), (400070008153, 400070008153, 400070008006, 153, FALSE), (400070008154, 400070008154, 400070008006, 154, FALSE), (400070008155, 400070008155, 400070008006, 155, FALSE), (400070008156, 400070008156, 400070008006, 156, FALSE), (400070008157, 400070008157, 400070008006, 157, FALSE), (400070008158, 400070008158, 400070008006, 158, FALSE), (400070008159, 400070008159, 400070008006, 159, FALSE), (400070008160, 400070008160, 400070008007, 160, FALSE), (400070008161, 400070008161, 400070008007, 161, FALSE), (400070008162, 400070008162, 400070008007, 162, FALSE), (400070008163, 400070008163, 400070008007, 163, FALSE), (400070008164, 400070008164, 400070008007, 164, FALSE), (400070008165, 400070008165, 400070008007, 165, FALSE), (400070008166, 400070008166, 400070008007, 166, FALSE), (400070008167, 400070008167, 400070008007, 167, FALSE), (400070008168, 400070008168, 400070008007, 168, FALSE), (400070008169, 400070008169, 400070008007, 169, FALSE), (400070008170, 400070008170, 400070008007, 170, FALSE), (400070008171, 400070008171, 400070008007, 171, FALSE), (400070008172, 400070008172, 400070008007, 172, FALSE), (400070008173, 400070008173, 400070008008, 173, FALSE), (400070008174, 400070008174, 400070008008, 174, FALSE), (400070008175, 400070008175, 400070008008, 175, FALSE), (400070008176, 400070008176, 400070008008, 176, FALSE), (400070008177, 400070008177, 400070008008, 177, FALSE), (400070008178, 400070008178, 400070008008, 178, FALSE), (400070008179, 400070008179, 400070008008, 179, FALSE), (400070008180, 400070008180, 400070008008, 180, FALSE), (400070008181, 400070008181, 400070008008, 181, FALSE), (400070008182, 400070008182, 400070008008, 182, FALSE), (400070008183, 400070008183, 400070008008, 183, FALSE), (400070008184, 400070008184, 400070008008, 184, FALSE), (400070008185, 400070008185, 400070008008, 185, FALSE), (400070008186, 400070008186, 400070008008, 186, FALSE), (400070008187, 400070008187, 400070008008, 187, FALSE), (400070008188, 400070008188, 400070008008, 188, FALSE), (400070008189, 400070008189, 400070008008, 189, FALSE), (400070008190, 400070008190, 400070008008, 190, FALSE), (400070008191, 400070008191, 400070008008, 191, FALSE), (400070008192, 400070008192, 400070008008, 192, FALSE), (400070008193, 400070008193, 400070008008, 193, FALSE), (400070008194, 400070008194, 400070008008, 194, FALSE), (400070008195, 400070008195, 400070008008, 195, FALSE), (400070008196, 400070008196, 400070008008, 196, FALSE), (400070008197, 400070008197, 400070008008, 197, FALSE), (400070008198, 400070008198, 400070008008, 198, FALSE), (400070008199, 400070008199, 400070008008, 199, FALSE), (400070008200, 400070008200, 400070008008, 200, FALSE), (400070008201, 400070008201, 400070008008, 201, FALSE), (400070008202, 400070008202, 400070008009, 202, FALSE), (400070008203, 400070008203, 400070008009, 203, FALSE), (400070008204, 400070008204, 400070008009, 204, FALSE), (400070008205, 400070008205, 400070008009, 205, FALSE), (400070008206, 400070008206, 400070008009, 206, FALSE), (400070008207, 400070008207, 400070008009, 207, FALSE), (400070008208, 400070008208, 400070008009, 208, FALSE), (400070008209, 400070008209, 400070008009, 209, FALSE), (400070008210, 400070008210, 400070008009, 210, FALSE), (400070008211, 400070008211, 400070008009, 211, FALSE), (400070008212, 400070008212, 400070008009, 212, FALSE), (400070008213, 400070008213, 400070008009, 213, FALSE), (400070008214, 400070008214, 400070008009, 214, FALSE), (400070008215, 400070008215, 400070008010, 215, FALSE), (400070008216, 400070008216, 400070008010, 216, FALSE), (400070008217, 400070008217, 400070008010, 217, FALSE), (400070008218, 400070008218, 400070008010, 218, FALSE), (400070008219, 400070008219, 400070008010, 219, FALSE), (400070008220, 400070008220, 400070008010, 220, FALSE), (400070008221, 400070008221, 400070008010, 221, FALSE), (400070008222, 400070008222, 400070008010, 222, FALSE), (400070008223, 400070008223, 400070008010, 223, FALSE), (400070008224, 400070008224, 400070008010, 224, FALSE), (400070008225, 400070008225, 400070008010, 225, FALSE), (400070008226, 400070008226, 400070008010, 226, FALSE), (400070008227, 400070008227, 400070008010, 227, FALSE), (400070008228, 400070008228, 400070008010, 228, FALSE), (400070008229, 400070008229, 400070008010, 229, FALSE), (400070008230, 400070008230, 400070008010, 230, FALSE), (400070008231, 400070008231, 400070008010, 231, FALSE), (400070008232, 400070008232, 400070008010, 232, FALSE), (400070008233, 400070008233, 400070008010, 233, FALSE), (400070008234, 400070008234, 400070008010, 234, FALSE), (400070008235, 400070008235, 400070008010, 235, FALSE), (400070008236, 400070008236, 400070008010, 236, FALSE), (400070008237, 400070008237, 400070008010, 237, FALSE), (400070008238, 400070008238, 400070008010, 238, FALSE), (400070008239, 400070008239, 400070008010, 239, FALSE), (400070008240, 400070008240, 400070008011, 240, FALSE), (400070008241, 400070008241, 400070008011, 241, FALSE), (400070008242, 400070008242, 400070008011, 242, FALSE), (400070008243, 400070008243, 400070008011, 243, FALSE), (400070008244, 400070008244, 400070008011, 244, FALSE), (400070008245, 400070008245, 400070008011, 245, FALSE), (400070008246, 400070008246, 400070008011, 246, FALSE), (400070008247, 400070008247, 400070008011, 247, FALSE), (400070008248, 400070008248, 400070008011, 248, FALSE), (400070008249, 400070008249, 400070008011, 249, FALSE), (400070008250, 400070008250, 400070008011, 250, FALSE), (400070008251, 400070008251, 400070008011, 251, FALSE), (400070008252, 400070008252, 400070008011, 252, FALSE), (400070008253, 400070008253, 400070008011, 253, FALSE), (400070008254, 400070008254, 400070008011, 254, FALSE), (400070008255, 400070008255, 400070008012, 255, FALSE), (400070008256, 400070008256, 400070008012, 256, FALSE), (400070008257, 400070008257, 400070008012, 257, FALSE), (400070008258, 400070008258, 400070008012, 258, FALSE), (400070008259, 400070008259, 400070008012, 259, FALSE), (400070008260, 400070008260, 400070008012, 260, FALSE), (400070008261, 400070008261, 400070008012, 261, FALSE), (400070008262, 400070008262, 400070008012, 262, FALSE), (400070008263, 400070008263, 400070008012, 263, FALSE), (400070008264, 400070008264, 400070008012, 264, FALSE), (400070008265, 400070008265, 400070008012, 265, FALSE), (400070008266, 400070008266, 400070008012, 266, FALSE), (400070008267, 400070008267, 400070008012, 267, FALSE), (400070008268, 400070008268, 400070008012, 268, FALSE), (400070008269, 400070008269, 400070008012, 269, FALSE), (400070008270, 400070008270, 400070008012, 270, FALSE), (400070008271, 400070008271, 400070008012, 271, FALSE), (400070008272, 400070008272, 400070008012, 272, FALSE), (400070008273, 400070008273, 400070008012, 273, FALSE), (400070008274, 400070008274, 400070008012, 274, FALSE), (400070008275, 400070008275, 400070008012, 275, FALSE), (400070008276, 400070008276, 400070008013, 276, FALSE), (400070008277, 400070008277, 400070008013, 277, FALSE), (400070008278, 400070008278, 400070008013, 278, FALSE), (400070008279, 400070008279, 400070008013, 279, FALSE), (400070008280, 400070008280, 400070008013, 280, FALSE), (400070008281, 400070008281, 400070008013, 281, FALSE), (400070008282, 400070008282, 400070008013, 282, FALSE), (400070008283, 400070008283, 400070008013, 283, FALSE), (400070008284, 400070008284, 400070008013, 284, FALSE), (400070008285, 400070008285, 400070008013, 285, FALSE), (400070008286, 400070008286, 400070008014, 286, FALSE), (400070008287, 400070008287, 400070008014, 287, FALSE), (400070008288, 400070008288, 400070008014, 288, FALSE), (400070008289, 400070008289, 400070008015, 289, FALSE), (400070008290, 400070008290, 400070008015, 290, FALSE), (400070008291, 400070008291, 400070008015, 291, FALSE), (400070008292, 400070008292, 400070008015, 292, FALSE), (400070008293, 400070008293, 400070008015, 293, FALSE), (400070008294, 400070008294, 400070008015, 294, FALSE), (400070008295, 400070008295, 400070008015, 295, FALSE), (400070008296, 400070008296, 400070008015, 296, FALSE), (400070008297, 400070008297, 400070008015, 297, FALSE), (400070008298, 400070008298, 400070008015, 298, FALSE), (400070008299, 400070008299, 400070008015, 299, FALSE), (400070008300, 400070008300, 400070008015, 300, FALSE), (400070008301, 400070008301, 400070008015, 301, FALSE), (400070008302, 400070008302, 400070008015, 302, FALSE), (400070008303, 400070008303, 400070008015, 303, FALSE), (400070008304, 400070008304, 400070008015, 304, FALSE), (400070008305, 400070008305, 400070008015, 305, FALSE), (400070008306, 400070008306, 400070008015, 306, FALSE), (400070008307, 400070008307, 400070008015, 307, FALSE), (400070008308, 400070008308, 400070008015, 308, FALSE), (400070008309, 400070008309, 400070008015, 309, FALSE), (400070008310, 400070008310, 400070008015, 310, FALSE), (400070008311, 400070008311, 400070008015, 311, FALSE), (400070008312, 400070008312, 400070008015, 312, FALSE), (400070008313, 400070008313, 400070008015, 313, FALSE), (400070008314, 400070008314, 400070008015, 314, FALSE), (400070008315, 400070008315, 400070008015, 315, FALSE), (400070008316, 400070008316, 400070008016, 316, FALSE), (400070008317, 400070008317, 400070008016, 317, FALSE), (400070008318, 400070008318, 400070008016, 318, FALSE), (400070008319, 400070008319, 400070008016, 319, FALSE), (400070008320, 400070008320, 400070008016, 320, FALSE), (400070008321, 400070008321, 400070008016, 321, FALSE), (400070008322, 400070008322, 400070008016, 322, FALSE), (400070008323, 400070008323, 400070008016, 323, FALSE), (400070008324, 400070008324, 400070008016, 324, FALSE), (400070008325, 400070008325, 400070008016, 325, FALSE), (400070008326, 400070008326, 400070008016, 326, FALSE), (400070008327, 400070008327, 400070008016, 327, FALSE), (400070008328, 400070008328, 400070008016, 328, FALSE), (400070008329, 400070008329, 400070008016, 329, FALSE), (400070008330, 400070008330, 400070008016, 330, FALSE), (400070008331, 400070008331, 400070008016, 331, FALSE), (400070008332, 400070008332, 400070008016, 332, FALSE), (400070008333, 400070008333, 400070008016, 333, FALSE), (400070008334, 400070008334, 400070008016, 334, FALSE), (400070008335, 400070008335, 400070008016, 335, FALSE), (400070008336, 400070008336, 400070008016, 336, FALSE), (400070008337, 400070008337, 400070008016, 337, FALSE), (400070008338, 400070008338, 400070008016, 338, FALSE), (400070008339, 400070008339, 400070008016, 339, FALSE), (400070008340, 400070008340, 400070008017, 340, FALSE), (400070008341, 400070008341, 400070008017, 341, FALSE), (400070008342, 400070008342, 400070008017, 342, FALSE), (400070008343, 400070008343, 400070008017, 343, FALSE), (400070008344, 400070008344, 400070008017, 344, FALSE), (400070008345, 400070008345, 400070008017, 345, FALSE), (400070008346, 400070008346, 400070008017, 346, FALSE), (400070008347, 400070008347, 400070008017, 347, FALSE), (400070008348, 400070008348, 400070008017, 348, FALSE), (400070008349, 400070008349, 400070008017, 349, FALSE), (400070008350, 400070008350, 400070008017, 350, FALSE), (400070008351, 400070008351, 400070008017, 351, FALSE), (400070008352, 400070008352, 400070008018, 352, FALSE), (400070008353, 400070008353, 400070008018, 353, FALSE), (400070008354, 400070008354, 400070008018, 354, FALSE), (400070008355, 400070008355, 400070008018, 355, FALSE), (400070008356, 400070008356, 400070008018, 356, FALSE), (400070008357, 400070008357, 400070008018, 357, FALSE), (400070008358, 400070008358, 400070008018, 358, FALSE), (400070008359, 400070008359, 400070008018, 359, FALSE), (400070008360, 400070008360, 400070008018, 360, FALSE), (400070008361, 400070008361, 400070008018, 361, FALSE), (400070008362, 400070008362, 400070008019, 362, FALSE), (400070008363, 400070008363, 400070008019, 363, FALSE), (400070008364, 400070008364, 400070008019, 364, FALSE), (400070008365, 400070008365, 400070008020, 365, FALSE), (400070008366, 400070008366, 400070008020, 366, FALSE), (400070008367, 400070008367, 400070008020, 367, FALSE), (400070008368, 400070008368, 400070008020, 368, FALSE), (400070008369, 400070008369, 400070008020, 369, FALSE), (400070008370, 400070008370, 400070008021, 370, FALSE), (400070008371, 400070008371, 400070008021, 371, FALSE), (400070008372, 400070008372, 400070008021, 372, FALSE), (400070008373, 400070008373, 400070008021, 373, FALSE), (400070008374, 400070008374, 400070008021, 374, FALSE), (400070008375, 400070008375, 400070008021, 375, FALSE), (400070008376, 400070008376, 400070008021, 376, FALSE), (400070008377, 400070008377, 400070008021, 377, FALSE), (400070008378, 400070008378, 400070008021, 378, FALSE), (400070008379, 400070008379, 400070008021, 379, FALSE), (400070008380, 400070008380, 400070008021, 380, FALSE), (400070008381, 400070008381, 400070008021, 381, FALSE), (400070008382, 400070008382, 400070008021, 382, FALSE), (400070008383, 400070008383, 400070008021, 383, FALSE), (400070008384, 400070008384, 400070008021, 384, FALSE), (400070008385, 400070008385, 400070008021, 385, FALSE), (400070008386, 400070008386, 400070008021, 386, FALSE), (400070008387, 400070008387, 400070008021, 387, FALSE), (400070008388, 400070008388, 400070008021, 388, FALSE), (400070008389, 400070008389, 400070008021, 389, FALSE), (400070008390, 400070008390, 400070008021, 390, FALSE), (400070008391, 400070008391, 400070008021, 391, FALSE), (400070008392, 400070008392, 400070008021, 392, FALSE), (400070008393, 400070008393, 400070008021, 393, FALSE), (400070008394, 400070008394, 400070008021, 394, FALSE), (400070008395, 400070008395, 400070008021, 395, FALSE), (400070008396, 400070008396, 400070008021, 396, FALSE), (400070008397, 400070008397, 400070008021, 397, FALSE), (400070008398, 400070008398, 400070008021, 398, FALSE), (400070008399, 400070008399, 400070008021, 399, FALSE), (400070008400, 400070008400, 400070008022, 400, FALSE), (400070008401, 400070008401, 400070008022, 401, FALSE), (400070008402, 400070008402, 400070008022, 402, FALSE), (400070008403, 400070008403, 400070008022, 403, FALSE), (400070008404, 400070008404, 400070008022, 404, FALSE), (400070008405, 400070008405, 400070008022, 405, FALSE), (400070008406, 400070008406, 400070008022, 406, FALSE), (400070008407, 400070008407, 400070008022, 407, FALSE), (400070008408, 400070008408, 400070008022, 408, FALSE), (400070008409, 400070008409, 400070008022, 409, FALSE), (400070008410, 400070008410, 400070008022, 410, FALSE), (400070008411, 400070008411, 400070008022, 411, FALSE), (400070008412, 400070008412, 400070008022, 412, FALSE), (400070008413, 400070008413, 400070008022, 413, FALSE), (400070008414, 400070008414, 400070008022, 414, FALSE), (400070008415, 400070008415, 400070008022, 415, FALSE), (400070008416, 400070008416, 400070008022, 416, FALSE), (400070008417, 400070008417, 400070008022, 417, FALSE), (400070008418, 400070008418, 400070008022, 418, FALSE), (400070008419, 400070008419, 400070008022, 419, FALSE), (400070008420, 400070008420, 400070008022, 420, FALSE), (400070008421, 400070008421, 400070008022, 421, FALSE), (400070008422, 400070008422, 400070008022, 422, FALSE), (400070008423, 400070008423, 400070008022, 423, FALSE), (400070008424, 400070008424, 400070008022, 424, FALSE), (400070008425, 400070008425, 400070008022, 425, FALSE), (400070008426, 400070008426, 400070008022, 426, FALSE), (400070008427, 400070008427, 400070008022, 427, FALSE), (400070008428, 400070008428, 400070008022, 428, FALSE), (400070008429, 400070008429, 400070008022, 429, FALSE), (400070008430, 400070008430, 400070008022, 430, FALSE), (400070008431, 400070008431, 400070008022, 431, FALSE), (400070008432, 400070008432, 400070008022, 432, FALSE), (400070008433, 400070008433, 400070008022, 433, FALSE), (400070008434, 400070008434, 400070008022, 434, FALSE), (400070008435, 400070008435, 400070008022, 435, FALSE), (400070008436, 400070008436, 400070008022, 436, FALSE), (400070008437, 400070008437, 400070008022, 437, FALSE), (400070008438, 400070008438, 400070008022, 438, FALSE), (400070008439, 400070008439, 400070008022, 439, FALSE), (400070008440, 400070008440, 400070008022, 440, FALSE), (400070008441, 400070008441, 400070008022, 441, FALSE), (400070008442, 400070008442, 400070008023, 442, FALSE), (400070008443, 400070008443, 400070008023, 443, FALSE), (400070008444, 400070008444, 400070008023, 444, FALSE), (400070008445, 400070008445, 400070008023, 445, FALSE), (400070008446, 400070008446, 400070008023, 446, FALSE), (400070008447, 400070008447, 400070008023, 447, FALSE), (400070008448, 400070008448, 400070008023, 448, FALSE), (400070008449, 400070008449, 400070008023, 449, FALSE), (400070008450, 400070008450, 400070008023, 450, FALSE), (400070008451, 400070008451, 400070008023, 451, FALSE), (400070008452, 400070008452, 400070008024, 452, FALSE), (400070008453, 400070008453, 400070008024, 453, FALSE), (400070008454, 400070008454, 400070008024, 454, FALSE), (400070008455, 400070008455, 400070008024, 455, FALSE), (400070008456, 400070008456, 400070008024, 456, FALSE), (400070008457, 400070008457, 400070008024, 457, FALSE), (400070008458, 400070008458, 400070008024, 458, FALSE), (400070008459, 400070008459, 400070008024, 459, FALSE), (400070008460, 400070008460, 400070008024, 460, FALSE), (400070008461, 400070008461, 400070008024, 461, FALSE), (400070008462, 400070008462, 400070008024, 462, FALSE), (400070008463, 400070008463, 400070008024, 463, FALSE), (400070008464, 400070008464, 400070008024, 464, FALSE), (400070008465, 400070008465, 400070008024, 465, FALSE), (400070008466, 400070008466, 400070008025, 466, FALSE), (400070008467, 400070008467, 400070008025, 467, FALSE), (400070008468, 400070008468, 400070008025, 468, FALSE), (400070008469, 400070008469, 400070008025, 469, FALSE), (400070008470, 400070008470, 400070008026, 470, FALSE), (400070008471, 400070008471, 400070008026, 471, FALSE), (400070008472, 400070008472, 400070008026, 472, FALSE), (400070008473, 400070008473, 400070008026, 473, FALSE), (400070008474, 400070008474, 400070008026, 474, FALSE), (400070008475, 400070008475, 400070008026, 475, FALSE), (400070008476, 400070008476, 400070008026, 476, FALSE), (400070008477, 400070008477, 400070008026, 477, FALSE), (400070008478, 400070008478, 400070008026, 478, FALSE), (400070008479, 400070008479, 400070008026, 479, FALSE), (400070008480, 400070008480, 400070008026, 480, FALSE), (400070008481, 400070008481, 400070008026, 481, FALSE), (400070008482, 400070008482, 400070008026, 482, FALSE), (400070008483, 400070008483, 400070008026, 483, FALSE), (400070008484, 400070008484, 400070008026, 484, FALSE), (400070008485, 400070008485, 400070008026, 485, FALSE), (400070008486, 400070008486, 400070008026, 486, FALSE), (400070008487, 400070008487, 400070008026, 487, FALSE), (400070008488, 400070008488, 400070008027, 488, FALSE), (400070008489, 400070008489, 400070008027, 489, FALSE), (400070008490, 400070008490, 400070008027, 490, FALSE), (400070008491, 400070008491, 400070008027, 491, FALSE), (400070008492, 400070008492, 400070008027, 492, FALSE), (400070008493, 400070008493, 400070008027, 493, FALSE), (400070008494, 400070008494, 400070008027, 494, FALSE), (400070008495, 400070008495, 400070008027, 495, FALSE), (400070008496, 400070008496, 400070008027, 496, FALSE), (400070008497, 400070008497, 400070008027, 497, FALSE), (400070008498, 400070008498, 400070008027, 498, FALSE), (400070008499, 400070008499, 400070008028, 499, FALSE), (400070008500, 400070008500, 400070008028, 500, FALSE), (400070008501, 400070008501, 400070008028, 501, FALSE), (400070008502, 400070008502, 400070008028, 502, FALSE), (400070008503, 400070008503, 400070008028, 503, FALSE), (400070008504, 400070008504, 400070008028, 504, FALSE), (400070008505, 400070008505, 400070008028, 505, FALSE), (400070008506, 400070008506, 400070008028, 506, FALSE), (400070008507, 400070008507, 400070008028, 507, FALSE), (400070008508, 400070008508, 400070008028, 508, FALSE), (400070008509, 400070008509, 400070008028, 509, FALSE), (400070008510, 400070008510, 400070008028, 510, FALSE), (400070008511, 400070008511, 400070008029, 511, FALSE), (400070008512, 400070008512, 400070008029, 512, FALSE), (400070008513, 400070008513, 400070008029, 513, FALSE), (400070008514, 400070008514, 400070008029, 514, FALSE), (400070008515, 400070008515, 400070008029, 515, FALSE), (400070008516, 400070008516, 400070008029, 516, FALSE), (400070008517, 400070008517, 400070008029, 517, FALSE), (400070008518, 400070008518, 400070008029, 518, FALSE), (400070008519, 400070008519, 400070008029, 519, FALSE), (400070008520, 400070008520, 400070008029, 520, FALSE), (400070008521, 400070008521, 400070008029, 521, FALSE), (400070008522, 400070008522, 400070008029, 522, FALSE), (400070008523, 400070008523, 400070008030, 523, FALSE), (400070008524, 400070008524, 400070008030, 524, FALSE), (400070008525, 400070008525, 400070008030, 525, FALSE), (400070008526, 400070008526, 400070008030, 526, FALSE), (400070008527, 400070008527, 400070008030, 527, FALSE), (400070008528, 400070008528, 400070008030, 528, FALSE), (400070008529, 400070008529, 400070008030, 529, FALSE), (400070008530, 400070008530, 400070008030, 530, FALSE)) AS x(menu_board_item_id, menu_item_id, menu_category_id, display_sequence, is_featured);

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row with
-- verification_status_code = 'needs_review', one line each.
-- =============================================================================
-- NEEDS_REVIEW [0.90] "Pomfret Tandoori" (CHARCOAL GRILLED): Priced 'APS' (as per season/size) -- is_market_price=TRUE, price left NULL.

-- =============================================================================
-- UNMAPPED: restaurant-level facts with no clean schema home, or deliberately
-- left for a human decision.
-- =============================================================================
-- UNMAPPED: restaurant.brand_id points to a NEW 'Janata' brand row (name inferred from the shared prefix across both restaurant names -- the JSON's own brand field for this restaurant just restates its own name, 'Janata Tawa & Grill', which isn't usable as a name spanning both restaurants).
-- UNMAPPED: establishment.name = 'Janata Restaurant Kurla', taken from this JSON's own related_establishment.name field (explicitly marked same_establishment_context=true) rather than either restaurant's own display name, since the establishment is the physical premises shared by both.
-- UNMAPPED: No schema column exists for an establishment or brand EMAIL address (establishment has website_url/instagram_handle/facebook_handle but no email column; brand has website_url/youtube_channel but no email column either) -- the JSON's contact.email ('janatarestaurantkurla@gmail.com') has no home in this schema and is not stored anywhere, per the rule against inventing a column.
-- UNMAPPED: This restaurant's own address ('Shop No. 1/2/3/4 & 6...') differs slightly from Janata Fast Food's own JSON ('Shop No. 6/7, 168...') despite both being the same shop building/chawl -- both are kept verbatim as each restaurant's own JSON states them; establishment.address_line1 uses THIS JSON's wording since this script runs the establishment identify-or-create first in file order (whichever script actually runs first in practice determines which address text is stored).
-- UNMAPPED: GST/tax fields on menu_item_price are left unset -- neither JSON states a GST/tax convention.
-- UNMAPPED: Two duplicate-looking adjacent 'Sweet Garlic' lines in SEAFOOD MAIN COURSE GRAVY (same prices, same section) were inserted as printed rather than de-duplicated, per the standing rule against silently resolving what the source itself states twice.
