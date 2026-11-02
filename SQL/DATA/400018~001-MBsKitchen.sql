-- ============================================================================
-- KHAUSTAN.COM - KhaustanRestaurantMenu - DATA LOAD FOR MB'S KITCHEN
-- Source JSON : MBs_Kitchen_Menu_OCR.json
-- Namespace   : establishment_id = restaurant_id = source_id = 400018001   (all child IDs are 400018001NNN, NNN = 001..999)
-- Target      : PostgreSQL, run with psql (uses \connect, \set, \encoding, \gset)
-- ============================================================================
--
-- WHAT THIS SCRIPT LOADS
--   15 categories | 132 menu items (20 of them from VEG/NON-VEG splits) | 149 variants | 149 prices | 1 a_la_carte board
--   121 distinct canonical-dish keys (new rows only where no exact normalized-name match already exists)
--
-- ID RULES
--   Deterministic: menu_board / menu_category / menu_item / menu_item_variant / menu_item_price / menu_board_item = 400018001NNN.
--   Standalone IDs (restaurant_phone, restaurant_hours, restaurant_tag, menu_extraction_batch, canonical_dish,
--   canonical_dish_name, restaurant_delivery_provider) = MAX(existing id) + n, captured once per table with \gset
--   at the top of the transaction. This is a choice made here because the processing prompt names no scheme for them -
--   swap in your own allocator if you use block ranges.
--
-- SAFETY
--   \set ON_ERROR_STOP on; whole load is one transaction; a pre-flight block aborts if this restaurant is already
--   loaded or if any lookup row it needs (protein_type / platform_tag / delivery_provider / service_mode) is missing.
--   Lookup tables are read, never written.
--
-- FIELD RULES APPLIED
--   name / description / category text are verbatim from the JSON (only quantity markers such as "(H/F)", "(2 PCS)",
--   "(500ml)" are moved out of the name into a variant).
--   food_classification_code and protein_type come from JSON text only (section titles, price labels, item names).
--   is_jain / is_vegan / is_eggless use Claude judgement (permitted for this batch), conservatively:
--     - non_veg and egg items: is_jain = FALSE, is_vegan = FALSE; is_eggless = FALSE for egg items, NULL for non_veg
--     - veg items: is_eggless = TRUE (a veg item contains no egg under the Indian veg definition)
--     - is_jain: TRUE only when the name says Jain; FALSE on explicit garlic / onion / potato / mushroom / pav bhaji
--       markers (single-dish names only); otherwise NULL
--     - is_vegan: FALSE on explicit dairy / egg / cheese / cream / butter / pizza etc.; TRUE only for evidently
--       plant-only items (fresh juices, fruit mixology drinks, papad, plain/steamed rice, green salad, water, soft drinks);
--       otherwise NULL
--   A canonical_dish link is made only when the JSON name is self-descriptive and matches exactly after
--   trim / collapse-whitespace / lower-case; abbreviations (e.g. "Chi.") are NOT expanded.
--
-- ASSUMPTIONS AND OWNER INSTRUCTIONS APPLIED
--   - establishment_id = restaurant_id = 400018001 as instructed by the owner (the JSON carried 400081001; the address PIN 400018 agrees with the supplied value).
--   - JSON timings "10:30 AM to 03:30 PM; 07:00 PM to 11:45 PM": two slots per day, applied to all 7 days.
--   - State is not in the JSON address: defaulted to Maharashtra (standing rule). City Mumbai and PIN 400018 are in the JSON address.
--   - Delivery partners ZOMATO and SWIGGY: JSON delivery field, also the zomato / swiggy logos on both pages. Charges are not in the JSON.
--   - First phone listed is marked primary; is_personal_number left at its FALSE default for both numbers (mobile-series numbers - confirm whether either is a personal line, DPDP).
--   - Price lines labeled VEG / NON-VEG (8 soups, 2 pastas) become two rows each sharing one split_group_key; NON-VEG rows carry no protein because the JSON names none.
--   - Names, spellings and typos are verbatim (for example MASHROOM, BESIL, TRIPPLE, SOUCE).
--   - No tax or GST wording appears anywhere in this JSON - tax columns NULL.
--
-- INFERRED LEGENDS / STRUCTURE
--   - Unlabeled two-price lines (4 in 'PANEER SEZWAN FRIED RICE' and 'BIRYANI') read as Half/Full by analogy with labeled rows (confidence 0.70, needs_review)
--   - 'GULĀB JAMUN (2 PCS)' -> item 'GULĀB JAMUN' + variant '2 pcs' (quantity marker moved out of the name)
--
-- CLASSIFICATION INFERENCES (confidence 0.85, not flagged for review)
--   - 10 item(s): classification inferred: no non-veg marker and every listed topping is vegetarian
--   - 1 item(s): classification inferred: dessert with no non-veg marker in the JSON
--
-- Rows needing review / confidence < 0.80 are listed in the first trailing comment block (1 item row(s), 8 price row(s)); restaurant-level notes with no schema column are in the second block.

\set ON_ERROR_STOP on
\connect "KhaustanRestaurantMenu"
\encoding UTF8

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. PRE-FLIGHT: already loaded? required lookup rows present?
-- ----------------------------------------------------------------------------
DO $preflight$
DECLARE
    v_missing text;
BEGIN
    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400018001)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400018001)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 400018001)
       OR EXISTS (SELECT 1 FROM menu_item WHERE restaurant_id = 400018001)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400018001 AND source_id = 400018001) THEN
        RAISE EXCEPTION 'Restaurant 400018001 is already loaded; aborting so menu items are not duplicated.';
    END IF;
    SELECT string_agg(n.code, ', ') INTO v_missing
    FROM (VALUES ('CHICKEN'), ('EGG')) AS n(code)
    WHERE NOT EXISTS (SELECT 1 FROM protein_type t WHERE upper(t.code) = n.code);
    IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'Missing protein_type lookup row(s): %', v_missing; END IF;
    SELECT string_agg(n.code, ', ') INTO v_missing
    FROM (VALUES ('ZOMATO'), ('SWIGGY')) AS n(code)
    WHERE NOT EXISTS (SELECT 1 FROM delivery_provider t WHERE t.provider_code = n.code);
    IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'Missing delivery_provider lookup row(s): %', v_missing; END IF;
    SELECT string_agg(n.code, ', ') INTO v_missing
    FROM (VALUES ('delivery')) AS n(code)
    WHERE NOT EXISTS (SELECT 1 FROM service_mode t WHERE t.code = n.code);
    IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'Missing service_mode lookup row(s): %', v_missing; END IF;
END
$preflight$;

-- ----------------------------------------------------------------------------
-- 1. STANDALONE ID BASES (captured once; MAX(existing) + n)
-- ----------------------------------------------------------------------------
SELECT COALESCE(MAX(restaurant_phone_id), 0) AS base_phone FROM restaurant_phone \gset
SELECT COALESCE(MAX(restaurant_hours_id), 0) AS base_hours FROM restaurant_hours \gset
SELECT COALESCE(MAX(extraction_batch_id), 0) AS base_batch FROM menu_extraction_batch \gset
SELECT COALESCE(MAX(canonical_dish_id), 0) AS base_cdish FROM canonical_dish \gset
SELECT COALESCE(MAX(canonical_dish_name_id), 0) AS base_cname FROM canonical_dish_name \gset
SELECT COALESCE(MAX(restaurant_delivery_provider_id), 0) AS base_rdp FROM restaurant_delivery_provider \gset

-- ----------------------------------------------------------------------------
-- 2. BRAND / ESTABLISHMENT / RESTAURANT / SOURCE / EXTRACTION BATCH
-- ----------------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2, locality, city, state,
                           postal_code, latitude, longitude)
VALUES (400018001, 'MB''s kitchen', 'mb''s kitchen',
        'Shop no. 21, Banatwala Chawl No. 2, Ganapatrao Kadam Marg',
        'Worli Naka, Opp. Sai Milan Building, Near Shriram Mill', 'Worli', 'Mumbai', 'Maharashtra', '400018',
        18.99860902354273, 72.82118815813688);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, veg_nonveg_status,
                        has_bar, bar_license_type)
VALUES (400018001, 400018001, 'MB''s kitchen', 'mb''s kitchen', 'veg_and_nonveg', FALSE, 'none');
INSERT INTO source_record (source_id, source_type_code, external_reference)
VALUES (400018001, 'ai_menu_extraction', 'MBs_Kitchen_Menu_OCR.json');
INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at,
                                   status_code, overall_confidence)
VALUES ((:base_batch + 1), 400018001, 400018001, (clock_timestamp() AT TIME ZONE 'UTC'),
        (clock_timestamp() AT TIME ZONE 'UTC'), 'completed', 0.93220);
-- overall_confidence = mean of the menu_item_source confidences below

-- ----------------------------------------------------------------------------
-- 3. PHONES / HOURS / TAGS / SERVICE MODES
-- ----------------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (:base_phone + 1, 400018001, '8850250382', TRUE),
    (:base_phone + 2, 400018001, '9967832799', FALSE);
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (:base_hours + 1, 400018001, 1, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 2, 400018001, 1, 2, TIME '19:00', TIME '23:45'),
    (:base_hours + 3, 400018001, 2, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 4, 400018001, 2, 2, TIME '19:00', TIME '23:45'),
    (:base_hours + 5, 400018001, 3, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 6, 400018001, 3, 2, TIME '19:00', TIME '23:45'),
    (:base_hours + 7, 400018001, 4, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 8, 400018001, 4, 2, TIME '19:00', TIME '23:45'),
    (:base_hours + 9, 400018001, 5, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 10, 400018001, 5, 2, TIME '19:00', TIME '23:45'),
    (:base_hours + 11, 400018001, 6, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 12, 400018001, 6, 2, TIME '19:00', TIME '23:45'),
    (:base_hours + 13, 400018001, 7, 1, TIME '10:30', TIME '15:30'),
    (:base_hours + 14, 400018001, 7, 2, TIME '19:00', TIME '23:45');
INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT 400018001, m.service_mode_id, TRUE, v.notes
FROM (VALUES
    ('delivery', 'JSON delivery: "ZOMATO, SWIGGY"')
) AS v(code, notes)
JOIN service_mode m ON m.code = v.code;

-- ----------------------------------------------------------------------------
-- 4. CANONICAL DISHES - 121 keys; inserted only where no exact normalized-name match exists
-- ----------------------------------------------------------------------------
WITH src (seq, canonical_name, normalized_name, food_classification_code, protein_code,
          is_jain, is_vegan, is_eggless) AS (
    VALUES
    (1, 'MANCHURIAN SOUP', 'manchurian soup', NULL, NULL, NULL, NULL, NULL),
    (2, 'LEMON CORIANDER SOUP', 'lemon coriander soup', NULL, NULL, NULL, NULL, NULL),
    (3, 'HOT & SOUR SOUP', 'hot & sour soup', NULL, NULL, NULL, NULL, NULL),
    (4, 'SWEET CORN SOUP', 'sweet corn soup', NULL, NULL, NULL, NULL, NULL),
    (5, 'NOODLE SOUP', 'noodle soup', NULL, NULL, NULL, NULL, NULL),
    (6, 'CLEAR SOUP', 'clear soup', NULL, NULL, NULL, NULL, NULL),
    (7, 'BURMESE SOUP', 'burmese soup', NULL, NULL, NULL, NULL, NULL),
    (8, 'TOMATO SOUP', 'tomato soup', NULL, NULL, NULL, NULL, NULL),
    (9, 'CHICKEN CHILLY DRY/GRAVY', 'chicken chilly dry/gravy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (10, 'CHICKEN CRISPY', 'chicken crispy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (11, 'CHICKEN MANCHURIAN/GRAVY', 'chicken manchurian/gravy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (12, 'CHICKEN 65', 'chicken 65', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (13, 'CHICKEN HONG KONG', 'chicken hong kong', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (14, 'CHICKEN HOT BESIL', 'chicken hot besil', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (15, 'CHICKEN BRUNT GARLIC DRY/GRAVY', 'chicken brunt garlic dry/gravy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (16, 'CHICKEN HOT GARLIC DRY/GRAVY', 'chicken hot garlic dry/gravy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (17, 'CHICKEN PERI PERI DRY', 'chicken peri peri dry', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (18, 'CHICKEN LOLLYPOP (OIL FRY)', 'chicken lollypop (oil fry)', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (19, 'CHICKEN LOLLYPOP (MASALA DRY)', 'chicken lollypop (masala dry)', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (20, 'CHICKEN BLACKPAPER SAUCE DRY', 'chicken blackpaper sauce dry', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (21, 'PANNER CHILLY DRY/GRAVY', 'panner chilly dry/gravy', 'veg', NULL, NULL, FALSE, TRUE),
    (22, 'VEG MANCHURIAN DRY/GRAVY', 'veg manchurian dry/gravy', 'veg', NULL, NULL, NULL, TRUE),
    (23, 'VEG CRISPY', 'veg crispy', 'veg', NULL, NULL, NULL, TRUE),
    (24, 'VEG 65', 'veg 65', 'veg', NULL, NULL, NULL, TRUE),
    (25, 'PANEER 65', 'paneer 65', 'veg', NULL, NULL, FALSE, TRUE),
    (26, 'PANEER CRISPY / PANEER SEZWAN', 'paneer crispy / paneer sezwan', 'veg', NULL, NULL, FALSE, TRUE),
    (27, 'PANEER SHATEY WITH PEANUT BUTTER SOUCE', 'paneer shatey with peanut butter souce', 'veg', NULL, NULL, FALSE, TRUE),
    (28, 'PANEER SHANGHAI / DRAGON PANEER', 'paneer shanghai / dragon paneer', 'veg', NULL, NULL, FALSE, TRUE),
    (29, 'PANEER HONG KONG', 'paneer hong kong', 'veg', NULL, NULL, FALSE, TRUE),
    (30, 'PANEER HOT BRASIL DRY/GRAVY', 'paneer hot brasil dry/gravy', 'veg', NULL, NULL, FALSE, TRUE),
    (31, 'PANEER BLACK PAPER SAUCE DRY', 'paneer black paper sauce dry', 'veg', NULL, NULL, FALSE, TRUE),
    (32, 'PANEER PERI PERI DRY', 'paneer peri peri dry', 'veg', NULL, NULL, FALSE, TRUE),
    (33, 'KING POOW PANEER', 'king poow paneer', 'veg', NULL, NULL, FALSE, TRUE),
    (34, 'PANEER MANCHURIAN DRY/GRAVY', 'paneer manchurian dry/gravy', 'veg', NULL, NULL, FALSE, TRUE),
    (35, 'MASHROOM CHILLY DRY/GRAVY', 'mashroom chilly dry/gravy', 'veg', NULL, NULL, NULL, TRUE),
    (36, 'MASHROOM MANCHURIAN DRY/GRAVY', 'mashroom manchurian dry/gravy', 'veg', NULL, NULL, NULL, TRUE),
    (37, 'VEG SPRING ROLL', 'veg spring roll', 'veg', NULL, NULL, NULL, TRUE),
    (38, 'PANEER SPRING ROLL', 'paneer spring roll', 'veg', NULL, NULL, FALSE, TRUE),
    (39, 'PANEER HOT GARLIC DRY', 'paneer hot garlic dry', 'veg', NULL, FALSE, FALSE, TRUE),
    (40, 'EGG FRIED RICE', 'egg fried rice', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (41, 'CHICKEN FRIED RICE', 'chicken fried rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (42, 'CHICKEN SEZWAN FRIED RICE', 'chicken sezwan fried rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (43, 'CHICKEN TRIPPLE SEZWAN FRIED RICE', 'chicken tripple sezwan fried rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (44, 'CHICKEN BRUNT GARLIC RICE', 'chicken brunt garlic rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (45, 'CHICKEN POT RICE', 'chicken pot rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (46, 'CHICKEN HONG KONG RICE', 'chicken hong kong rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (47, 'CHICKEN SINGAPORE RICE', 'chicken singapore rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (48, 'CHICKEN COMBINATION RICE', 'chicken combination rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (49, 'CHICKEN CHILLY GARLIC RICE', 'chicken chilly garlic rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (50, 'CHICKEN MAXICAN RICE', 'chicken maxican rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (51, 'EGG SEZWAN FRIED RICE', 'egg sezwan fried rice', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (52, 'CHICKEN BAM BOO RICE', 'chicken bam boo rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (53, 'VEG FRIED RICE', 'veg fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (54, 'VEG SEZWAN FRIED RICE', 'veg sezwan fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (55, 'VEG TRIPPLE SEZWAN FRIED RICE', 'veg tripple sezwan fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (56, 'PANEER FRIED RICE', 'paneer fried rice', 'veg', NULL, NULL, FALSE, TRUE),
    (57, 'PANEER SEZWAN FRIED RICE', 'paneer sezwan fried rice', 'veg', NULL, NULL, FALSE, TRUE),
    (58, 'MASHROOM FRIED RICE', 'mashroom fried rice', 'veg', NULL, FALSE, NULL, TRUE),
    (59, 'VEG POT RICE', 'veg pot rice', 'veg', NULL, NULL, NULL, TRUE),
    (60, 'VEG HONG KONG RICE', 'veg hong kong rice', 'veg', NULL, NULL, NULL, TRUE),
    (61, 'VEG SINGAPURE RICE', 'veg singapure rice', 'veg', NULL, NULL, NULL, TRUE),
    (62, 'VEG STRONG FRICE', 'veg strong frice', 'veg', NULL, NULL, NULL, TRUE),
    (63, 'VEG MEXICAN RICE', 'veg mexican rice', 'veg', NULL, NULL, NULL, TRUE),
    (64, 'VEG BHATURA RICE', 'veg bhatura rice', 'veg', NULL, NULL, NULL, TRUE),
    (65, 'VEG COMBINATION RICE', 'veg combination rice', 'veg', NULL, NULL, NULL, TRUE),
    (66, 'VEG CHILLY GARLIC RICE', 'veg chilly garlic rice', 'veg', NULL, FALSE, NULL, TRUE),
    (67, 'VEG BRUNT GARLIC RICE', 'veg brunt garlic rice', 'veg', NULL, FALSE, NULL, TRUE),
    (68, 'VEG MANCHURIAN RICE', 'veg manchurian rice', 'veg', NULL, NULL, NULL, TRUE),
    (69, 'VEG BAM BOO RICE', 'veg bam boo rice', 'veg', NULL, NULL, NULL, TRUE),
    (70, 'CHICKEN BIRYANI', 'chicken biryani', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (71, 'CHICKEN HYDRABADI BIRYANI', 'chicken hydrabadi biryani', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (72, 'CHICKEN KHEEMA SUKHA MASALA', 'chicken kheema sukha masala', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (73, 'EGG HAKKA NOODLES', 'egg hakka noodles', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (74, 'CHICKEN HAKKA NOODLES', 'chicken hakka noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (75, 'CHICKEN SEZWAN NOODLES', 'chicken sezwan noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (76, 'CHICKEN TRIPPLE SEZWAN NOODLES', 'chicken tripple sezwan noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (77, 'CHICKEN HONG KONG NOODLES', 'chicken hong kong noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (78, 'CHICKEN PAN FRIED HAKKA NOODLES', 'chicken pan fried hakka noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (79, 'EGG SEZWAN NOODLES', 'egg sezwan noodles', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (80, 'CHICKEN CHILLY GARLIC NOODLES', 'chicken chilly garlic noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (81, 'CHICKEN BRUNT GARLIC NOODLES', 'chicken brunt garlic noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (82, 'CHICKEN MAXICAN NOODLES', 'chicken maxican noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (83, 'CHICKEN CHOW MAIN', 'chicken chow main', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (84, 'CHICKEN AMERICAN CHOUPSEY', 'chicken american choupsey', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (85, 'CHICKEN CHINESE CHOUPSEY', 'chicken chinese choupsey', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (86, 'CHICKEN CHINESE BHEL', 'chicken chinese bhel', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (87, 'VEG HAKKA NOODLES', 'veg hakka noodles', 'veg', NULL, NULL, NULL, TRUE),
    (88, 'VEG SEZWAN NOODLES', 'veg sezwan noodles', 'veg', NULL, NULL, NULL, TRUE),
    (89, 'VEG TRIPPLE SEZWAN NOODLES', 'veg tripple sezwan noodles', 'veg', NULL, NULL, NULL, TRUE),
    (90, 'VEG CHILLY GARLIC SEZWAN NOODLES', 'veg chilly garlic sezwan noodles', 'veg', NULL, FALSE, NULL, TRUE),
    (91, 'VEG BRUNT GARLIC NOODLES', 'veg brunt garlic noodles', 'veg', NULL, FALSE, NULL, TRUE),
    (92, 'VEG HONG KONG NOODLES', 'veg hong kong noodles', 'veg', NULL, NULL, NULL, TRUE),
    (93, 'VEG SINGAPORE NOODLES', 'veg singapore noodles', 'veg', NULL, NULL, NULL, TRUE),
    (94, 'VEG CHAWMAIN', 'veg chawmain', 'veg', NULL, NULL, NULL, TRUE),
    (95, 'VEG PAN FRIED HAKKA NOODLES', 'veg pan fried hakka noodles', 'veg', NULL, NULL, NULL, TRUE),
    (96, 'VEG AMERICAN CHOUPSEY', 'veg american choupsey', 'veg', NULL, NULL, NULL, TRUE),
    (97, 'VEG CHINESE CHOUPSEY', 'veg chinese choupsey', 'veg', NULL, NULL, NULL, TRUE),
    (98, 'CHINESE BHEL', 'chinese bhel', 'veg', NULL, NULL, NULL, TRUE),
    (99, 'PLAIN CHEESE PIZZA', 'plain cheese pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (100, 'MARGHERITA PIZZA', 'margherita pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (101, 'PERI PERI PANEER PIZZA', 'peri peri paneer pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (102, 'FRENCH PIZZA', 'french pizza', 'veg', NULL, FALSE, FALSE, TRUE),
    (103, 'ITALIAN PIZZA', 'italian pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (104, 'VEG CHEESE PIZZA', 'veg cheese pizza', 'veg', NULL, FALSE, FALSE, TRUE),
    (105, 'MAXICAN PIZZA', 'maxican pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (106, 'CANADIAN PIZZA', 'canadian pizza', 'veg', NULL, FALSE, FALSE, TRUE),
    (107, 'MEDITERRANEAN PIZZA', 'mediterranean pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (108, 'PHILIPINA PIZZA', 'philipina pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (109, 'PASTA WHITE SAUCE', 'pasta white sauce', NULL, NULL, NULL, FALSE, NULL),
    (110, 'PASTA RED SAUCE', 'pasta red sauce', NULL, NULL, NULL, NULL, NULL),
    (111, 'VEG SANDWICH', 'veg sandwich', 'veg', NULL, NULL, NULL, TRUE),
    (112, 'VEG CHEESE SANDWICH', 'veg cheese sandwich', 'veg', NULL, NULL, FALSE, TRUE),
    (113, 'MASALA TOAST SANDWICH', 'masala toast sandwich', 'veg', NULL, NULL, NULL, TRUE),
    (114, 'MASALA CHEESE TOAST SANDWICH', 'masala cheese toast sandwich', 'veg', NULL, NULL, FALSE, TRUE),
    (115, 'VEG CHEESE GRILL SANDWICH', 'veg cheese grill sandwich', 'veg', NULL, NULL, FALSE, TRUE),
    (116, 'VEG GRILL SANDWICH', 'veg grill sandwich', 'veg', NULL, NULL, NULL, TRUE),
    (117, 'MB’S SPL SANDWICH', 'mb’s spl sandwich', 'veg', NULL, NULL, NULL, TRUE),
    (118, 'CHEESE SANDWICH', 'cheese sandwich', 'veg', NULL, NULL, FALSE, TRUE),
    (119, 'CHICKEN SANDWICH', 'chicken sandwich', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (120, 'CHICKEN TIKKA SANDWICH', 'chicken tikka sandwich', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (121, 'GULĀB JAMUN', 'gulāb jamun', 'veg', NULL, NULL, FALSE, TRUE)
), new_dish AS (
    SELECT :base_cdish + row_number() OVER (ORDER BY s.seq) AS canonical_dish_id,
           s.canonical_name, s.normalized_name, s.food_classification_code, s.protein_code,
           s.is_jain::boolean AS is_jain, s.is_vegan::boolean AS is_vegan, s.is_eggless::boolean AS is_eggless
    FROM src s
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish d WHERE d.normalized_name = s.normalized_name)
), ins_dish AS (
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code,
                                default_protein_type_id, is_jain, is_vegan, is_eggless)
    SELECT n.canonical_dish_id, n.canonical_name, n.normalized_name, n.food_classification_code,
           pt.protein_type_id, n.is_jain, n.is_vegan, n.is_eggless
    FROM new_dish n
    LEFT JOIN protein_type pt ON upper(pt.code) = n.protein_code
    RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name,
                                 normalized_name, name_type_code)
SELECT :base_cname + row_number() OVER (ORDER BY n.canonical_dish_id), n.canonical_dish_id, 'en',
       n.canonical_name, n.normalized_name, 'primary'
FROM new_dish n;

-- ----------------------------------------------------------------------------
-- 5. MENU BOARD AND CATEGORIES (JSON section order)
-- ----------------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, display_sequence)
VALUES (400018001001, 400018001, 'A La Carte', 'a_la_carte', 1);
-- board name is a structural label (the JSON names no board); the JSON describes one overall menu
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence, is_active)
VALUES
    -- pages[0].sections[0] (MBsKitchen1.jpg, column 1)
    (400018001001, 400018001, 'CHINESE SOUP', 1, TRUE),
    -- pages[0].sections[1] (MBsKitchen1.jpg, column 1)
    (400018001002, 400018001, 'CHINESE NON-VEG STARTERS', 2, TRUE),
    -- pages[0].sections[2] (MBsKitchen1.jpg, column 1)
    (400018001003, 400018001, 'VEG STARTERS', 3, TRUE),
    -- pages[0].sections[3] (MBsKitchen1.jpg, column 2)
    (400018001004, 400018001, 'PANEER', 4, TRUE),
    -- pages[0].sections[4] (MBsKitchen1.jpg, column 2)
    (400018001005, 400018001, 'CHINESE NON-VEG RICE', 5, TRUE),
    -- pages[0].sections[5] (MBsKitchen1.jpg, column 2)
    (400018001006, 400018001, 'CHINESE VEG RICE', 6, TRUE),
    -- pages[0].sections[6] (MBsKitchen1.jpg, column 3)
    (400018001007, 400018001, 'PANEER SEZWAN FRIED RICE', 7, TRUE),
    -- pages[0].sections[7] (MBsKitchen1.jpg, column 3)
    (400018001008, 400018001, 'BIRYANI', 8, TRUE),
    -- pages[0].sections[8] (MBsKitchen1.jpg, column 3)
    (400018001009, 400018001, 'CHINESE NON-VEG NOODLES', 9, TRUE),
    -- pages[1].sections[0] (MBsKitchen2.jpg, column 1)
    (400018001010, 400018001, 'CHINESE VEG NOODLES', 10, TRUE),
    -- pages[1].sections[1] (MBsKitchen2.jpg, column 1)
    (400018001011, 400018001, 'PIZZA', 11, TRUE),
    -- pages[1].sections[2] (MBsKitchen2.jpg, column 2)
    (400018001012, 400018001, 'PASTA', 12, TRUE),
    -- pages[1].sections[3] (MBsKitchen2.jpg, column 2)
    (400018001013, 400018001, 'VEG SANDWICH', 13, TRUE),
    -- pages[1].sections[4] (MBsKitchen2.jpg, column 2)
    (400018001014, 400018001, 'NON-VEG SANDWICH', 14, TRUE),
    -- pages[1].sections[5] (MBsKitchen2.jpg, column 2)
    (400018001015, 400018001, 'DESERTS', 15, TRUE);

-- ----------------------------------------------------------------------------
-- 6. MENU ITEMS, VARIANTS, PRICES (one block per JSON section)
-- ----------------------------------------------------------------------------

-- [1/15] CHINESE SOUP  |  JSON: pages[0].sections[0]  (MBsKitchen1.jpg, column 1; 8 JSON line(s) -> 16 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] MANCHURIAN SOUP [VEG]
    (400018001001, 400018001001, 'MANCHURIAN SOUP', 'manchurian soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-01', 'unverified', 'manchurian soup'),
    -- items[0] MANCHURIAN SOUP [NON-VEG]
    (400018001002, 400018001001, 'MANCHURIAN SOUP', 'manchurian soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-01', 'unverified', 'manchurian soup'),
    -- items[1] LEMON CORIANDER SOUP [VEG]
    (400018001003, 400018001001, 'LEMON CORIANDER SOUP', 'lemon coriander soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-02', 'unverified', 'lemon coriander soup'),
    -- items[1] LEMON CORIANDER SOUP [NON-VEG]
    (400018001004, 400018001001, 'LEMON CORIANDER SOUP', 'lemon coriander soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-02', 'unverified', 'lemon coriander soup'),
    -- items[2] HOT & SOUR SOUP [VEG]
    (400018001005, 400018001001, 'HOT & SOUR SOUP', 'hot & sour soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-03', 'unverified', 'hot & sour soup'),
    -- items[2] HOT & SOUR SOUP [NON-VEG]
    (400018001006, 400018001001, 'HOT & SOUR SOUP', 'hot & sour soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-03', 'unverified', 'hot & sour soup'),
    -- items[3] SWEET CORN SOUP [VEG]
    (400018001007, 400018001001, 'SWEET CORN SOUP', 'sweet corn soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-04', 'unverified', 'sweet corn soup'),
    -- items[3] SWEET CORN SOUP [NON-VEG]
    (400018001008, 400018001001, 'SWEET CORN SOUP', 'sweet corn soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-04', 'unverified', 'sweet corn soup'),
    -- items[4] NOODLE SOUP [VEG]
    (400018001009, 400018001001, 'NOODLE SOUP', 'noodle soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-05', 'unverified', 'noodle soup'),
    -- items[4] NOODLE SOUP [NON-VEG]
    (400018001010, 400018001001, 'NOODLE SOUP', 'noodle soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-05', 'unverified', 'noodle soup'),
    -- items[5] CLEAR SOUP [VEG]
    (400018001011, 400018001001, 'CLEAR SOUP', 'clear soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-06', 'unverified', 'clear soup'),
    -- items[5] CLEAR SOUP [NON-VEG]
    (400018001012, 400018001001, 'CLEAR SOUP', 'clear soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-06', 'unverified', 'clear soup'),
    -- items[6] BURMESE SOUP [VEG]
    (400018001013, 400018001001, 'BURMESE SOUP', 'burmese soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-07', 'unverified', 'burmese soup'),
    -- items[6] BURMESE SOUP [NON-VEG]
    (400018001014, 400018001001, 'BURMESE SOUP', 'burmese soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-07', 'unverified', 'burmese soup'),
    -- items[7] TOMATO SOUP [VEG]
    (400018001015, 400018001001, 'TOMATO SOUP', 'tomato soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, NULL, TRUE, '400018001-01-01-08', 'unverified', 'tomato soup'),
    -- items[7] TOMATO SOUP [NON-VEG]
    (400018001016, 400018001001, 'TOMATO SOUP', 'tomato soup', NULL, 'CHINESE SOUP', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-01-01-08', 'unverified', 'tomato soup')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001001, 400018001001, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001002, 400018001002, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001003, 400018001003, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001004, 400018001004, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001005, 400018001005, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001006, 400018001006, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001007, 400018001007, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001008, 400018001008, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001009, 400018001009, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001010, 400018001010, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001011, 400018001011, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001012, 400018001012, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001013, 400018001013, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001014, 400018001014, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001015, 400018001015, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001016, 400018001016, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001001, 400018001001, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001002, 400018001002, 130.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001003, 400018001003, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001004, 400018001004, 130.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001005, 400018001005, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001006, 400018001006, 130.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001007, 400018001007, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001008, 400018001008, 130.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001009, 400018001009, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001010, 400018001010, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001011, 400018001011, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001012, 400018001012, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001013, 400018001013, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001014, 400018001014, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001015, 400018001015, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001016, 400018001016, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [2/15] CHINESE NON-VEG STARTERS  |  JSON: pages[0].sections[1]  (MBsKitchen1.jpg, column 1; 12 JSON line(s) -> 12 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] CHICKEN CHILLY DRY/GRAVY
    (400018001017, 400018001002, 'CHICKEN CHILLY DRY/GRAVY', 'chicken chilly dry/gravy', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken chilly dry/gravy'),
    -- items[1] CHICKEN CRISPY
    (400018001018, 400018001002, 'CHICKEN CRISPY', 'chicken crispy', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken crispy'),
    -- items[2] CHICKEN MANCHURIAN/GRAVY
    (400018001019, 400018001002, 'CHICKEN MANCHURIAN/GRAVY', 'chicken manchurian/gravy', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken manchurian/gravy'),
    -- items[3] CHICKEN 65
    (400018001020, 400018001002, 'CHICKEN 65', 'chicken 65', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken 65'),
    -- items[4] CHICKEN HONG KONG
    (400018001021, 400018001002, 'CHICKEN HONG KONG', 'chicken hong kong', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hong kong'),
    -- items[5] CHICKEN HOT BESIL
    (400018001022, 400018001002, 'CHICKEN HOT BESIL', 'chicken hot besil', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hot besil'),
    -- items[6] CHICKEN BRUNT GARLIC DRY/GRAVY
    (400018001023, 400018001002, 'CHICKEN BRUNT GARLIC DRY/GRAVY', 'chicken brunt garlic dry/gravy', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken brunt garlic dry/gravy'),
    -- items[7] CHICKEN HOT GARLIC DRY/GRAVY
    (400018001024, 400018001002, 'CHICKEN HOT GARLIC DRY/GRAVY', 'chicken hot garlic dry/gravy', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hot garlic dry/gravy'),
    -- items[8] CHICKEN PERI PERI DRY
    (400018001025, 400018001002, 'CHICKEN PERI PERI DRY', 'chicken peri peri dry', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken peri peri dry'),
    -- items[9] CHICKEN LOLLYPOP (OIL FRY)
    (400018001026, 400018001002, 'CHICKEN LOLLYPOP (OIL FRY)', 'chicken lollypop (oil fry)', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken lollypop (oil fry)'),
    -- items[10] CHICKEN LOLLYPOP (MASALA DRY)
    (400018001027, 400018001002, 'CHICKEN LOLLYPOP (MASALA DRY)', 'chicken lollypop (masala dry)', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken lollypop (masala dry)'),
    -- items[11] CHICKEN BLACKPAPER SAUCE DRY
    (400018001028, 400018001002, 'CHICKEN BLACKPAPER SAUCE DRY', 'chicken blackpaper sauce dry', NULL, 'CHINESE NON-VEG STARTERS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken blackpaper sauce dry')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001017, 400018001017, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001018, 400018001017, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001019, 400018001018, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001020, 400018001018, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001021, 400018001019, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001022, 400018001019, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001023, 400018001020, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001024, 400018001021, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001025, 400018001022, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001026, 400018001023, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001027, 400018001024, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001028, 400018001025, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001029, 400018001026, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001030, 400018001026, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001031, 400018001027, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001032, 400018001027, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001033, 400018001028, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001017, 400018001017, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001018, 400018001018, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001019, 400018001019, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001020, 400018001020, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001021, 400018001021, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001022, 400018001022, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001023, 400018001023, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001024, 400018001024, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001025, 400018001025, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001026, 400018001026, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001027, 400018001027, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001028, 400018001028, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001029, 400018001029, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001030, 400018001030, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001031, 400018001031, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001032, 400018001032, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001033, 400018001033, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [3/15] VEG STARTERS  |  JSON: pages[0].sections[2]  (MBsKitchen1.jpg, column 1; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] PANNER CHILLY DRY/GRAVY
    (400018001029, 400018001003, 'PANNER CHILLY DRY/GRAVY', 'panner chilly dry/gravy', NULL, 'VEG STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'panner chilly dry/gravy'),
    -- items[1] VEG MANCHURIAN DRY/GRAVY
    (400018001030, 400018001003, 'VEG MANCHURIAN DRY/GRAVY', 'veg manchurian dry/gravy', NULL, 'VEG STARTERS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg manchurian dry/gravy'),
    -- items[2] VEG CRISPY
    (400018001031, 400018001003, 'VEG CRISPY', 'veg crispy', NULL, 'VEG STARTERS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg crispy'),
    -- items[3] VEG 65
    (400018001032, 400018001003, 'VEG 65', 'veg 65', NULL, 'VEG STARTERS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg 65'),
    -- items[4] PANEER 65
    (400018001033, 400018001003, 'PANEER 65', 'paneer 65', NULL, 'VEG STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer 65'),
    -- items[5] PANEER CRISPY / PANEER SEZWAN
    (400018001034, 400018001003, 'PANEER CRISPY / PANEER SEZWAN', 'paneer crispy / paneer sezwan', NULL, 'VEG STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer crispy / paneer sezwan'),
    -- items[6] PANEER SHATEY WITH PEANUT BUTTER SOUCE
    (400018001035, 400018001003, 'PANEER SHATEY WITH PEANUT BUTTER SOUCE', 'paneer shatey with peanut butter souce', NULL, 'VEG STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer shatey with peanut butter souce')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001034, 400018001029, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001035, 400018001030, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001036, 400018001031, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001037, 400018001032, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001038, 400018001033, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001039, 400018001034, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001040, 400018001035, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001034, 400018001034, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001035, 400018001035, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001036, 400018001036, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001037, 400018001037, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001038, 400018001038, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001039, 400018001039, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001040, 400018001040, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [4/15] PANEER  |  JSON: pages[0].sections[3]  (MBsKitchen1.jpg, column 2; 12 JSON line(s) -> 12 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] PANEER SHANGHAI / DRAGON PANEER
    (400018001036, 400018001004, 'PANEER SHANGHAI / DRAGON PANEER', 'paneer shanghai / dragon paneer', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer shanghai / dragon paneer'),
    -- items[1] PANEER HONG KONG
    (400018001037, 400018001004, 'PANEER HONG KONG', 'paneer hong kong', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer hong kong'),
    -- items[2] PANEER HOT BRASIL DRY/GRAVY
    (400018001038, 400018001004, 'PANEER HOT BRASIL DRY/GRAVY', 'paneer hot brasil dry/gravy', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer hot brasil dry/gravy'),
    -- items[3] PANEER BLACK PAPER SAUCE DRY
    (400018001039, 400018001004, 'PANEER BLACK PAPER SAUCE DRY', 'paneer black paper sauce dry', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer black paper sauce dry'),
    -- items[4] PANEER PERI PERI DRY
    (400018001040, 400018001004, 'PANEER PERI PERI DRY', 'paneer peri peri dry', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer peri peri dry'),
    -- items[5] KING POOW PANEER
    (400018001041, 400018001004, 'KING POOW PANEER', 'king poow paneer', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'king poow paneer'),
    -- items[6] PANEER MANCHURIAN DRY/GRAVY
    (400018001042, 400018001004, 'PANEER MANCHURIAN DRY/GRAVY', 'paneer manchurian dry/gravy', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer manchurian dry/gravy'),
    -- items[7] MASHROOM CHILLY DRY/GRAVY
    (400018001043, 400018001004, 'MASHROOM CHILLY DRY/GRAVY', 'mashroom chilly dry/gravy', NULL, 'PANEER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mashroom chilly dry/gravy'),
    -- items[8] MASHROOM MANCHURIAN DRY/GRAVY
    (400018001044, 400018001004, 'MASHROOM MANCHURIAN DRY/GRAVY', 'mashroom manchurian dry/gravy', NULL, 'PANEER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mashroom manchurian dry/gravy'),
    -- items[9] VEG SPRING ROLL
    (400018001045, 400018001004, 'VEG SPRING ROLL', 'veg spring roll', NULL, 'PANEER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg spring roll'),
    -- items[10] PANEER SPRING ROLL
    (400018001046, 400018001004, 'PANEER SPRING ROLL', 'paneer spring roll', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer spring roll'),
    -- items[11] PANEER HOT GARLIC DRY
    (400018001047, 400018001004, 'PANEER HOT GARLIC DRY', 'paneer hot garlic dry', NULL, 'PANEER', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'paneer hot garlic dry')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001041, 400018001036, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001042, 400018001037, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001043, 400018001038, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001044, 400018001039, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001045, 400018001040, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001046, 400018001041, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001047, 400018001042, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001048, 400018001043, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001049, 400018001044, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001050, 400018001045, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001051, 400018001046, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001052, 400018001047, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001041, 400018001041, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001042, 400018001042, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001043, 400018001043, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001044, 400018001044, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001045, 400018001045, 190.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001046, 400018001046, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001047, 400018001047, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001048, 400018001048, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001049, 400018001049, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001050, 400018001050, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001051, 400018001051, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001052, 400018001052, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [5/15] CHINESE NON-VEG RICE  |  JSON: pages[0].sections[4]  (MBsKitchen1.jpg, column 2; 13 JSON line(s) -> 13 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] EGG FRIED RICE
    (400018001048, 400018001005, 'EGG FRIED RICE', 'egg fried rice', NULL, 'CHINESE NON-VEG RICE', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg fried rice'),
    -- items[1] CHICKEN FRIED RICE
    (400018001049, 400018001005, 'CHICKEN FRIED RICE', 'chicken fried rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken fried rice'),
    -- items[2] CHICKEN SEZWAN FRIED RICE
    (400018001050, 400018001005, 'CHICKEN SEZWAN FRIED RICE', 'chicken sezwan fried rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken sezwan fried rice'),
    -- items[3] CHICKEN TRIPPLE SEZWAN FRIED RICE
    (400018001051, 400018001005, 'CHICKEN TRIPPLE SEZWAN FRIED RICE', 'chicken tripple sezwan fried rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken tripple sezwan fried rice'),
    -- items[4] CHICKEN BRUNT GARLIC RICE
    (400018001052, 400018001005, 'CHICKEN BRUNT GARLIC RICE', 'chicken brunt garlic rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken brunt garlic rice'),
    -- items[5] CHICKEN POT RICE
    (400018001053, 400018001005, 'CHICKEN POT RICE', 'chicken pot rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken pot rice'),
    -- items[6] CHICKEN HONG KONG RICE
    (400018001054, 400018001005, 'CHICKEN HONG KONG RICE', 'chicken hong kong rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hong kong rice'),
    -- items[7] CHICKEN SINGAPORE RICE
    (400018001055, 400018001005, 'CHICKEN SINGAPORE RICE', 'chicken singapore rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken singapore rice'),
    -- items[8] CHICKEN COMBINATION RICE
    (400018001056, 400018001005, 'CHICKEN COMBINATION RICE', 'chicken combination rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken combination rice'),
    -- items[9] CHICKEN CHILLY GARLIC RICE
    (400018001057, 400018001005, 'CHICKEN CHILLY GARLIC RICE', 'chicken chilly garlic rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken chilly garlic rice'),
    -- items[10] CHICKEN MAXICAN RICE
    (400018001058, 400018001005, 'CHICKEN MAXICAN RICE', 'chicken maxican rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken maxican rice'),
    -- items[11] EGG SEZWAN FRIED RICE
    (400018001059, 400018001005, 'EGG SEZWAN FRIED RICE', 'egg sezwan fried rice', NULL, 'CHINESE NON-VEG RICE', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg sezwan fried rice'),
    -- items[12] CHICKEN BAM BOO RICE
    (400018001060, 400018001005, 'CHICKEN BAM BOO RICE', 'chicken bam boo rice', NULL, 'CHINESE NON-VEG RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken bam boo rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001053, 400018001048, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001054, 400018001048, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001055, 400018001049, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001056, 400018001049, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001057, 400018001050, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001058, 400018001050, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001059, 400018001051, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001060, 400018001051, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001061, 400018001052, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001062, 400018001053, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001063, 400018001054, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001064, 400018001055, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001065, 400018001056, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001066, 400018001057, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001067, 400018001058, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001068, 400018001059, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001069, 400018001060, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001053, 400018001053, 130.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001054, 400018001054, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001055, 400018001055, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001056, 400018001056, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001057, 400018001057, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001058, 400018001058, 190.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001059, 400018001059, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001060, 400018001060, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001061, 400018001061, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001062, 400018001062, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001063, 400018001063, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001064, 400018001064, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001065, 400018001065, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001066, 400018001066, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001067, 400018001067, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001068, 400018001068, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001069, 400018001069, 240.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [6/15] CHINESE VEG RICE  |  JSON: pages[0].sections[5]  (MBsKitchen1.jpg, column 2; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] VEG FRIED RICE
    (400018001061, 400018001006, 'VEG FRIED RICE', 'veg fried rice', NULL, 'CHINESE VEG RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg fried rice'),
    -- items[1] VEG SEZWAN FRIED RICE
    (400018001062, 400018001006, 'VEG SEZWAN FRIED RICE', 'veg sezwan fried rice', NULL, 'CHINESE VEG RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg sezwan fried rice'),
    -- items[2] VEG TRIPPLE SEZWAN FRIED RICE
    (400018001063, 400018001006, 'VEG TRIPPLE SEZWAN FRIED RICE', 'veg tripple sezwan fried rice', NULL, 'CHINESE VEG RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg tripple sezwan fried rice'),
    -- items[3] PANEER FRIED RICE
    (400018001064, 400018001006, 'PANEER FRIED RICE', 'paneer fried rice', NULL, 'CHINESE VEG RICE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer fried rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001070, 400018001061, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001071, 400018001061, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001072, 400018001062, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001073, 400018001062, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001074, 400018001063, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001075, 400018001063, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001076, 400018001064, 'Half', 'HALF', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001077, 400018001064, 'Full', 'FULL', 'fixed', NULL, NULL, 2, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001070, 400018001070, 110.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001071, 400018001071, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001072, 400018001072, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001073, 400018001073, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001074, 400018001074, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001075, 400018001075, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001076, 400018001076, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001077, 400018001077, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [7/15] PANEER SEZWAN FRIED RICE  |  JSON: pages[0].sections[6]  (MBsKitchen1.jpg, column 3; 13 JSON line(s) -> 13 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] PANEER SEZWAN FRIED RICE
    (400018001065, 400018001007, 'PANEER SEZWAN FRIED RICE', 'paneer sezwan fried rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer sezwan fried rice'),
    -- items[1] MASHROOM FRIED RICE
    (400018001066, 400018001007, 'MASHROOM FRIED RICE', 'mashroom fried rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mashroom fried rice'),
    -- items[2] VEG POT RICE
    (400018001067, 400018001007, 'VEG POT RICE', 'veg pot rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg pot rice'),
    -- items[3] VEG HONG KONG RICE
    (400018001068, 400018001007, 'VEG HONG KONG RICE', 'veg hong kong rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg hong kong rice'),
    -- items[4] VEG SINGAPURE RICE
    (400018001069, 400018001007, 'VEG SINGAPURE RICE', 'veg singapure rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg singapure rice'),
    -- items[5] VEG STRONG FRICE
    (400018001070, 400018001007, 'VEG STRONG FRICE', 'veg strong frice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg strong frice'),
    -- items[6] VEG MEXICAN RICE
    (400018001071, 400018001007, 'VEG MEXICAN RICE', 'veg mexican rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg mexican rice'),
    -- items[7] VEG BHATURA RICE
    (400018001072, 400018001007, 'VEG BHATURA RICE', 'veg bhatura rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg bhatura rice'),
    -- items[8] VEG COMBINATION RICE
    (400018001073, 400018001007, 'VEG COMBINATION RICE', 'veg combination rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg combination rice'),
    -- items[9] VEG CHILLY GARLIC RICE
    (400018001074, 400018001007, 'VEG CHILLY GARLIC RICE', 'veg chilly garlic rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'veg chilly garlic rice'),
    -- items[10] VEG BRUNT GARLIC RICE
    (400018001075, 400018001007, 'VEG BRUNT GARLIC RICE', 'veg brunt garlic rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'veg brunt garlic rice'),
    -- items[11] VEG MANCHURIAN RICE
    (400018001076, 400018001007, 'VEG MANCHURIAN RICE', 'veg manchurian rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg manchurian rice'),
    -- items[12] VEG BAM BOO RICE
    (400018001077, 400018001007, 'VEG BAM BOO RICE', 'veg bam boo rice', NULL, 'PANEER SEZWAN FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg bam boo rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001078, 400018001065, 'Half', NULL, 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001079, 400018001065, 'Full', NULL, 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001080, 400018001066, 'Half', NULL, 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001081, 400018001066, 'Full', NULL, 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001082, 400018001067, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001083, 400018001068, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001084, 400018001069, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001085, 400018001070, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001086, 400018001071, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001087, 400018001072, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001088, 400018001073, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001089, 400018001074, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001090, 400018001075, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001091, 400018001076, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001092, 400018001077, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001078, 400018001078, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001079, 400018001079, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001080, 400018001080, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001081, 400018001081, 190.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001082, 400018001082, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001083, 400018001083, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001084, 400018001084, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001085, 400018001085, 240.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001086, 400018001086, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001087, 400018001087, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001088, 400018001088, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001089, 400018001089, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001090, 400018001090, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001091, 400018001091, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001092, 400018001092, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [8/15] BIRYANI  |  JSON: pages[0].sections[7]  (MBsKitchen1.jpg, column 3; 3 JSON line(s) -> 3 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] CHICKEN BIRYANI
    (400018001078, 400018001008, 'CHICKEN BIRYANI', 'chicken biryani', NULL, 'BIRYANI', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken biryani'),
    -- items[1] CHICKEN HYDRABADI BIRYANI
    (400018001079, 400018001008, 'CHICKEN HYDRABADI BIRYANI', 'chicken hydrabadi biryani', NULL, 'BIRYANI', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hydrabadi biryani'),
    -- items[2] CHICKEN KHEEMA SUKHA MASALA
    (400018001080, 400018001008, 'CHICKEN KHEEMA SUKHA MASALA', 'chicken kheema sukha masala', NULL, 'BIRYANI', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken kheema sukha masala')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001093, 400018001078, 'Half', NULL, 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001094, 400018001078, 'Full', NULL, 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001095, 400018001079, 'Half', NULL, 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400018001096, 400018001079, 'Full', NULL, 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400018001097, 400018001080, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001093, 400018001093, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001094, 400018001094, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001095, 400018001095, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001096, 400018001096, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400018001),
    (400018001097, 400018001097, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [9/15] CHINESE NON-VEG NOODLES  |  JSON: pages[0].sections[8]  (MBsKitchen1.jpg, column 3; 14 JSON line(s) -> 14 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] EGG HAKKA NOODLES
    (400018001081, 400018001009, 'EGG HAKKA NOODLES', 'egg hakka noodles', NULL, 'CHINESE NON-VEG NOODLES', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg hakka noodles'),
    -- items[1] CHICKEN HAKKA NOODLES
    (400018001082, 400018001009, 'CHICKEN HAKKA NOODLES', 'chicken hakka noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hakka noodles'),
    -- items[2] CHICKEN SEZWAN NOODLES
    (400018001083, 400018001009, 'CHICKEN SEZWAN NOODLES', 'chicken sezwan noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken sezwan noodles'),
    -- items[3] CHICKEN TRIPPLE SEZWAN NOODLES
    (400018001084, 400018001009, 'CHICKEN TRIPPLE SEZWAN NOODLES', 'chicken tripple sezwan noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken tripple sezwan noodles'),
    -- items[4] CHICKEN HONG KONG NOODLES
    (400018001085, 400018001009, 'CHICKEN HONG KONG NOODLES', 'chicken hong kong noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken hong kong noodles'),
    -- items[5] CHICKEN PAN FRIED HAKKA NOODLES
    (400018001086, 400018001009, 'CHICKEN PAN FRIED HAKKA NOODLES', 'chicken pan fried hakka noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken pan fried hakka noodles'),
    -- items[6] EGG SEZWAN NOODLES
    (400018001087, 400018001009, 'EGG SEZWAN NOODLES', 'egg sezwan noodles', NULL, 'CHINESE NON-VEG NOODLES', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg sezwan noodles'),
    -- items[7] CHICKEN CHILLY GARLIC NOODLES
    (400018001088, 400018001009, 'CHICKEN CHILLY GARLIC NOODLES', 'chicken chilly garlic noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken chilly garlic noodles'),
    -- items[8] CHICKEN BRUNT GARLIC NOODLES
    (400018001089, 400018001009, 'CHICKEN BRUNT GARLIC NOODLES', 'chicken brunt garlic noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken brunt garlic noodles'),
    -- items[9] CHICKEN MAXICAN NOODLES
    (400018001090, 400018001009, 'CHICKEN MAXICAN NOODLES', 'chicken maxican noodles', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken maxican noodles'),
    -- items[10] CHICKEN CHOW MAIN
    (400018001091, 400018001009, 'CHICKEN CHOW MAIN', 'chicken chow main', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken chow main'),
    -- items[11] CHICKEN AMERICAN CHOUPSEY
    (400018001092, 400018001009, 'CHICKEN AMERICAN CHOUPSEY', 'chicken american choupsey', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken american choupsey'),
    -- items[12] CHICKEN CHINESE CHOUPSEY
    (400018001093, 400018001009, 'CHICKEN CHINESE CHOUPSEY', 'chicken chinese choupsey', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken chinese choupsey'),
    -- items[13] CHICKEN CHINESE BHEL
    (400018001094, 400018001009, 'CHICKEN CHINESE BHEL', 'chicken chinese bhel', NULL, 'CHINESE NON-VEG NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken chinese bhel')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001098, 400018001081, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001099, 400018001082, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001100, 400018001083, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001101, 400018001084, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001102, 400018001085, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001103, 400018001086, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001104, 400018001087, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001105, 400018001088, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001106, 400018001089, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001107, 400018001090, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001108, 400018001091, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001109, 400018001092, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001110, 400018001093, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001111, 400018001094, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001098, 400018001098, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001099, 400018001099, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001100, 400018001100, 190.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001101, 400018001101, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001102, 400018001102, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001103, 400018001103, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001104, 400018001104, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001105, 400018001105, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001106, 400018001106, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001107, 400018001107, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001108, 400018001108, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001109, 400018001109, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001110, 400018001110, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001111, 400018001111, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [10/15] CHINESE VEG NOODLES  |  JSON: pages[1].sections[0]  (MBsKitchen2.jpg, column 1; 13 JSON line(s) -> 13 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] VEG HAKKA NOODLES
    (400018001095, 400018001010, 'VEG HAKKA NOODLES', 'veg hakka noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg hakka noodles'),
    -- items[1] VEG SEZWAN NOODLES
    (400018001096, 400018001010, 'VEG SEZWAN NOODLES', 'veg sezwan noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg sezwan noodles'),
    -- items[2] VEG TRIPPLE SEZWAN NOODLES
    (400018001097, 400018001010, 'VEG TRIPPLE SEZWAN NOODLES', 'veg tripple sezwan noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg tripple sezwan noodles'),
    -- items[3] VEG TRIPPLE SEZWAN NOODLES
    (400018001098, 400018001010, 'VEG TRIPPLE SEZWAN NOODLES', 'veg tripple sezwan noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'needs_review', 'veg tripple sezwan noodles'),
    -- items[4] VEG CHILLY GARLIC SEZWAN NOODLES
    (400018001099, 400018001010, 'VEG CHILLY GARLIC SEZWAN NOODLES', 'veg chilly garlic sezwan noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'veg chilly garlic sezwan noodles'),
    -- items[5] VEG BRUNT GARLIC NOODLES
    (400018001100, 400018001010, 'VEG BRUNT GARLIC NOODLES', 'veg brunt garlic noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'veg brunt garlic noodles'),
    -- items[6] VEG HONG KONG NOODLES
    (400018001101, 400018001010, 'VEG HONG KONG NOODLES', 'veg hong kong noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg hong kong noodles'),
    -- items[7] VEG SINGAPORE NOODLES
    (400018001102, 400018001010, 'VEG SINGAPORE NOODLES', 'veg singapore noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg singapore noodles'),
    -- items[8] VEG CHAWMAIN
    (400018001103, 400018001010, 'VEG CHAWMAIN', 'veg chawmain', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg chawmain'),
    -- items[9] VEG PAN FRIED HAKKA NOODLES
    (400018001104, 400018001010, 'VEG PAN FRIED HAKKA NOODLES', 'veg pan fried hakka noodles', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg pan fried hakka noodles'),
    -- items[10] VEG AMERICAN CHOUPSEY
    (400018001105, 400018001010, 'VEG AMERICAN CHOUPSEY', 'veg american choupsey', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg american choupsey'),
    -- items[11] VEG CHINESE CHOUPSEY
    (400018001106, 400018001010, 'VEG CHINESE CHOUPSEY', 'veg chinese choupsey', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg chinese choupsey'),
    -- items[12] CHINESE BHEL
    (400018001107, 400018001010, 'CHINESE BHEL', 'chinese bhel', NULL, 'CHINESE VEG NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'chinese bhel')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001112, 400018001095, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001113, 400018001096, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001114, 400018001097, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001115, 400018001098, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001116, 400018001099, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001117, 400018001100, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001118, 400018001101, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001119, 400018001102, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001120, 400018001103, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001121, 400018001104, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001122, 400018001105, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001123, 400018001106, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001124, 400018001107, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001112, 400018001112, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001113, 400018001113, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001114, 400018001114, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001115, 400018001115, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001116, 400018001116, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001117, 400018001117, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001118, 400018001118, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001119, 400018001119, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001120, 400018001120, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001121, 400018001121, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001122, 400018001122, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001123, 400018001123, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001124, 400018001124, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [11/15] PIZZA  |  JSON: pages[1].sections[1]  (MBsKitchen2.jpg, column 1; 10 JSON line(s) -> 10 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] PLAIN CHEESE PIZZA
    (400018001108, 400018001011, 'PLAIN CHEESE PIZZA', 'plain cheese pizza', NULL, 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'plain cheese pizza'),
    -- items[1] MARGHERITA PIZZA
    (400018001109, 400018001011, 'MARGHERITA PIZZA', 'margherita pizza', '(SLICED TOMATO AND BESIL)', 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'margherita pizza'),
    -- items[2] PERI PERI PANEER PIZZA
    (400018001110, 400018001011, 'PERI PERI PANEER PIZZA', 'peri peri paneer pizza', '(MARINATED PANEER, CAPSICUM)', 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'peri peri paneer pizza'),
    -- items[3] FRENCH PIZZA
    (400018001111, 400018001011, 'FRENCH PIZZA', 'french pizza', '(ONION, GARLIC, BELLPAPER ZUCHINI, TOMATOS, BLACK OLIVE)', 'PIZZA', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'french pizza'),
    -- items[4] ITALIAN PIZZA
    (400018001112, 400018001011, 'ITALIAN PIZZA', 'italian pizza', '(BLACK OLIVE, RED, YELLOW, GREEN BELLPEPPER)', 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'italian pizza'),
    -- items[5] VEG CHEESE PIZZA
    (400018001113, 400018001011, 'VEG CHEESE PIZZA', 'veg cheese pizza', '(ONION, TOMATOS, CAPSICUM)', 'PIZZA', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'veg cheese pizza'),
    -- items[6] MAXICAN PIZZA
    (400018001114, 400018001011, 'MAXICAN PIZZA', 'maxican pizza', '(FRIED BENS, AMERICAN CORN, JALAPENOS, BELLPEPPER)', 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'maxican pizza'),
    -- items[7] CANADIAN PIZZA
    (400018001115, 400018001011, 'CANADIAN PIZZA', 'canadian pizza', '(MASHROOM, PANEER, TOMATO, BLACK OLIVE, ONION)', 'PIZZA', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'canadian pizza'),
    -- items[8] MEDITERRANEAN PIZZA
    (400018001116, 400018001011, 'MEDITERRANEAN PIZZA', 'mediterranean pizza', '(BLACK OLIVE, WHITE OLIVE, ZUCHINI, BELLPEPPER)', 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'mediterranean pizza'),
    -- items[9] PHILIPINA PIZZA
    (400018001117, 400018001011, 'PHILIPINA PIZZA', 'philipina pizza', '(GREEN OLIVE, BLACK OLIVE, ZUCHINI, BROKOLI, JALAPENO, BABY CORN)', 'PIZZA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'philipina pizza')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001125, 400018001108, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001126, 400018001109, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001127, 400018001110, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001128, 400018001111, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001129, 400018001112, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001130, 400018001113, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001131, 400018001114, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001132, 400018001115, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001133, 400018001116, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001134, 400018001117, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001125, 400018001125, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001126, 400018001126, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001127, 400018001127, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001128, 400018001128, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001129, 400018001129, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001130, 400018001130, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001131, 400018001131, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001132, 400018001132, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001133, 400018001133, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001134, 400018001134, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [12/15] PASTA  |  JSON: pages[1].sections[2]  (MBsKitchen2.jpg, column 2; 2 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] PASTA WHITE SAUCE [VEG]
    (400018001118, 400018001012, 'PASTA WHITE SAUCE', 'pasta white sauce', NULL, 'PASTA', 'veg', NULL, NULL, FALSE, TRUE, '400018001-02-03-01', 'unverified', 'pasta white sauce'),
    -- items[0] PASTA WHITE SAUCE [NON-VEG]
    (400018001119, 400018001012, 'PASTA WHITE SAUCE', 'pasta white sauce', NULL, 'PASTA', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-02-03-01', 'unverified', 'pasta white sauce'),
    -- items[1] PASTA RED SAUCE [VEG]
    (400018001120, 400018001012, 'PASTA RED SAUCE', 'pasta red sauce', NULL, 'PASTA', 'veg', NULL, NULL, NULL, TRUE, '400018001-02-03-02', 'unverified', 'pasta red sauce'),
    -- items[1] PASTA RED SAUCE [NON-VEG]
    (400018001121, 400018001012, 'PASTA RED SAUCE', 'pasta red sauce', NULL, 'PASTA', 'non_veg', NULL, FALSE, FALSE, NULL, '400018001-02-03-02', 'unverified', 'pasta red sauce')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001135, 400018001118, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001136, 400018001119, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001137, 400018001120, 'Regular', 'VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001138, 400018001121, 'Regular', 'NON-VEG', 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001135, 400018001135, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001136, 400018001136, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001137, 400018001137, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001138, 400018001138, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [13/15] VEG SANDWICH  |  JSON: pages[1].sections[3]  (MBsKitchen2.jpg, column 2; 8 JSON line(s) -> 8 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] VEG SANDWICH
    (400018001122, 400018001013, 'VEG SANDWICH', 'veg sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg sandwich'),
    -- items[1] VEG CHEESE SANDWICH
    (400018001123, 400018001013, 'VEG CHEESE SANDWICH', 'veg cheese sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg cheese sandwich'),
    -- items[2] MASALA TOAST SANDWICH
    (400018001124, 400018001013, 'MASALA TOAST SANDWICH', 'masala toast sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'masala toast sandwich'),
    -- items[3] MASALA CHEESE TOAST SANDWICH
    (400018001125, 400018001013, 'MASALA CHEESE TOAST SANDWICH', 'masala cheese toast sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'masala cheese toast sandwich'),
    -- items[4] VEG CHEESE GRILL SANDWICH
    (400018001126, 400018001013, 'VEG CHEESE GRILL SANDWICH', 'veg cheese grill sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg cheese grill sandwich'),
    -- items[5] VEG GRILL SANDWICH
    (400018001127, 400018001013, 'VEG GRILL SANDWICH', 'veg grill sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg grill sandwich'),
    -- items[6] MB’S SPL SANDWICH
    (400018001128, 400018001013, 'MB’S SPL SANDWICH', 'mb’s spl sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mb’s spl sandwich'),
    -- items[7] CHEESE SANDWICH
    (400018001129, 400018001013, 'CHEESE SANDWICH', 'cheese sandwich', NULL, 'VEG SANDWICH', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese sandwich')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001139, 400018001122, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001140, 400018001123, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001141, 400018001124, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001142, 400018001125, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001143, 400018001126, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001144, 400018001127, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001145, 400018001128, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001146, 400018001129, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001139, 400018001139, 50.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001140, 400018001140, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001141, 400018001141, 60.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001142, 400018001142, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001143, 400018001143, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001144, 400018001144, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001145, 400018001145, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001146, 400018001146, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [14/15] NON-VEG SANDWICH  |  JSON: pages[1].sections[4]  (MBsKitchen2.jpg, column 2; 2 JSON line(s) -> 2 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] CHICKEN SANDWICH
    (400018001130, 400018001014, 'CHICKEN SANDWICH', 'chicken sandwich', NULL, 'NON-VEG SANDWICH', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken sandwich'),
    -- items[1] CHICKEN TIKKA SANDWICH
    (400018001131, 400018001014, 'CHICKEN TIKKA SANDWICH', 'chicken tikka sandwich', NULL, 'NON-VEG SANDWICH', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken tikka sandwich')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001147, 400018001130, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400018001148, 400018001131, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001147, 400018001147, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001),
    (400018001148, 400018001148, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- [15/15] DESERTS  |  JSON: pages[1].sections[5]  (MBsKitchen2.jpg, column 2; 1 JSON line(s) -> 1 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400018001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] GULĀB JAMUN
    (400018001132, 400018001015, 'GULĀB JAMUN', 'gulāb jamun', NULL, 'DESERTS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'gulāb jamun')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400018001149, 400018001132, '2 pcs', NULL, 'fixed', 2, 'pieces', 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400018001149, 400018001149, 50.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400018001);

-- ----------------------------------------------------------------------------
-- 7. PROVENANCE LINKS (menu_item_source, menu_item_price_source)
-- ----------------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400018001001, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001002, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001003, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001004, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001005, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001006, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001007, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001008, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001009, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001010, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001011, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001012, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001013, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001014, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001015, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001016, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001017, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001018, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001019, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001020, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001021, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001022, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001023, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001024, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001025, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001026, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001027, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001028, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001029, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001030, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001031, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001032, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001033, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001034, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001035, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001036, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001037, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001038, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001039, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001040, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001041, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001042, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001043, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001044, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001045, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001046, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001047, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001048, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001049, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001050, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001051, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001052, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001053, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001054, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001055, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001056, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001057, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001058, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001059, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001060, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001061, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001062, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001063, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001064, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001065, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001066, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001067, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001068, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001069, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001070, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001071, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001072, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001073, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001074, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001075, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001076, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001077, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001078, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001079, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001080, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001081, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001082, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001083, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001084, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001085, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001086, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001087, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001088, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001089, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001090, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001091, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001092, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001093, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001094, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001095, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001096, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001097, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001098, 400018001, (:base_batch + 1), 0.70000, 'needs_review'),
    (400018001099, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001100, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001101, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001102, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001103, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001104, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001105, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001106, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001107, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001108, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001109, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001110, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001111, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001112, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001113, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001114, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001115, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001116, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001117, 400018001, (:base_batch + 1), 0.85000, 'unverified'),
    (400018001118, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001119, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001120, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001121, 400018001, (:base_batch + 1), 0.90000, 'unverified'),
    (400018001122, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001123, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001124, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001125, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001126, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001127, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001128, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001129, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001130, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001131, 400018001, (:base_batch + 1), 0.95000, 'unverified'),
    (400018001132, 400018001, (:base_batch + 1), 0.85000, 'unverified');
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400018001001, 400018001, (:base_batch + 1), 0.90000),
    (400018001002, 400018001, (:base_batch + 1), 0.90000),
    (400018001003, 400018001, (:base_batch + 1), 0.90000),
    (400018001004, 400018001, (:base_batch + 1), 0.90000),
    (400018001005, 400018001, (:base_batch + 1), 0.90000),
    (400018001006, 400018001, (:base_batch + 1), 0.90000),
    (400018001007, 400018001, (:base_batch + 1), 0.90000),
    (400018001008, 400018001, (:base_batch + 1), 0.90000),
    (400018001009, 400018001, (:base_batch + 1), 0.90000),
    (400018001010, 400018001, (:base_batch + 1), 0.90000),
    (400018001011, 400018001, (:base_batch + 1), 0.90000),
    (400018001012, 400018001, (:base_batch + 1), 0.90000),
    (400018001013, 400018001, (:base_batch + 1), 0.90000),
    (400018001014, 400018001, (:base_batch + 1), 0.90000),
    (400018001015, 400018001, (:base_batch + 1), 0.90000),
    (400018001016, 400018001, (:base_batch + 1), 0.90000),
    (400018001017, 400018001, (:base_batch + 1), 0.95000),
    (400018001018, 400018001, (:base_batch + 1), 0.95000),
    (400018001019, 400018001, (:base_batch + 1), 0.95000),
    (400018001020, 400018001, (:base_batch + 1), 0.95000),
    (400018001021, 400018001, (:base_batch + 1), 0.95000),
    (400018001022, 400018001, (:base_batch + 1), 0.95000),
    (400018001023, 400018001, (:base_batch + 1), 0.95000),
    (400018001024, 400018001, (:base_batch + 1), 0.95000),
    (400018001025, 400018001, (:base_batch + 1), 0.95000),
    (400018001026, 400018001, (:base_batch + 1), 0.95000),
    (400018001027, 400018001, (:base_batch + 1), 0.95000),
    (400018001028, 400018001, (:base_batch + 1), 0.95000),
    (400018001029, 400018001, (:base_batch + 1), 0.95000),
    (400018001030, 400018001, (:base_batch + 1), 0.95000),
    (400018001031, 400018001, (:base_batch + 1), 0.95000),
    (400018001032, 400018001, (:base_batch + 1), 0.95000),
    (400018001033, 400018001, (:base_batch + 1), 0.95000),
    (400018001034, 400018001, (:base_batch + 1), 0.95000),
    (400018001035, 400018001, (:base_batch + 1), 0.95000),
    (400018001036, 400018001, (:base_batch + 1), 0.95000),
    (400018001037, 400018001, (:base_batch + 1), 0.95000),
    (400018001038, 400018001, (:base_batch + 1), 0.95000),
    (400018001039, 400018001, (:base_batch + 1), 0.95000),
    (400018001040, 400018001, (:base_batch + 1), 0.95000),
    (400018001041, 400018001, (:base_batch + 1), 0.95000),
    (400018001042, 400018001, (:base_batch + 1), 0.95000),
    (400018001043, 400018001, (:base_batch + 1), 0.95000),
    (400018001044, 400018001, (:base_batch + 1), 0.95000),
    (400018001045, 400018001, (:base_batch + 1), 0.95000),
    (400018001046, 400018001, (:base_batch + 1), 0.95000),
    (400018001047, 400018001, (:base_batch + 1), 0.95000),
    (400018001048, 400018001, (:base_batch + 1), 0.95000),
    (400018001049, 400018001, (:base_batch + 1), 0.95000),
    (400018001050, 400018001, (:base_batch + 1), 0.95000),
    (400018001051, 400018001, (:base_batch + 1), 0.95000),
    (400018001052, 400018001, (:base_batch + 1), 0.95000),
    (400018001053, 400018001, (:base_batch + 1), 0.95000),
    (400018001054, 400018001, (:base_batch + 1), 0.95000),
    (400018001055, 400018001, (:base_batch + 1), 0.95000),
    (400018001056, 400018001, (:base_batch + 1), 0.95000),
    (400018001057, 400018001, (:base_batch + 1), 0.95000),
    (400018001058, 400018001, (:base_batch + 1), 0.95000),
    (400018001059, 400018001, (:base_batch + 1), 0.95000),
    (400018001060, 400018001, (:base_batch + 1), 0.95000),
    (400018001061, 400018001, (:base_batch + 1), 0.95000),
    (400018001062, 400018001, (:base_batch + 1), 0.95000),
    (400018001063, 400018001, (:base_batch + 1), 0.95000),
    (400018001064, 400018001, (:base_batch + 1), 0.95000),
    (400018001065, 400018001, (:base_batch + 1), 0.95000),
    (400018001066, 400018001, (:base_batch + 1), 0.95000),
    (400018001067, 400018001, (:base_batch + 1), 0.95000),
    (400018001068, 400018001, (:base_batch + 1), 0.95000),
    (400018001069, 400018001, (:base_batch + 1), 0.95000),
    (400018001070, 400018001, (:base_batch + 1), 0.95000),
    (400018001071, 400018001, (:base_batch + 1), 0.95000),
    (400018001072, 400018001, (:base_batch + 1), 0.95000),
    (400018001073, 400018001, (:base_batch + 1), 0.95000),
    (400018001074, 400018001, (:base_batch + 1), 0.95000),
    (400018001075, 400018001, (:base_batch + 1), 0.95000),
    (400018001076, 400018001, (:base_batch + 1), 0.95000),
    (400018001077, 400018001, (:base_batch + 1), 0.95000),
    (400018001078, 400018001, (:base_batch + 1), 0.70000),
    (400018001079, 400018001, (:base_batch + 1), 0.70000),
    (400018001080, 400018001, (:base_batch + 1), 0.70000),
    (400018001081, 400018001, (:base_batch + 1), 0.70000),
    (400018001082, 400018001, (:base_batch + 1), 0.95000),
    (400018001083, 400018001, (:base_batch + 1), 0.95000),
    (400018001084, 400018001, (:base_batch + 1), 0.95000),
    (400018001085, 400018001, (:base_batch + 1), 0.95000),
    (400018001086, 400018001, (:base_batch + 1), 0.95000),
    (400018001087, 400018001, (:base_batch + 1), 0.95000),
    (400018001088, 400018001, (:base_batch + 1), 0.95000),
    (400018001089, 400018001, (:base_batch + 1), 0.95000),
    (400018001090, 400018001, (:base_batch + 1), 0.95000),
    (400018001091, 400018001, (:base_batch + 1), 0.95000),
    (400018001092, 400018001, (:base_batch + 1), 0.95000),
    (400018001093, 400018001, (:base_batch + 1), 0.70000),
    (400018001094, 400018001, (:base_batch + 1), 0.70000),
    (400018001095, 400018001, (:base_batch + 1), 0.70000),
    (400018001096, 400018001, (:base_batch + 1), 0.70000),
    (400018001097, 400018001, (:base_batch + 1), 0.95000),
    (400018001098, 400018001, (:base_batch + 1), 0.95000),
    (400018001099, 400018001, (:base_batch + 1), 0.95000),
    (400018001100, 400018001, (:base_batch + 1), 0.95000),
    (400018001101, 400018001, (:base_batch + 1), 0.95000),
    (400018001102, 400018001, (:base_batch + 1), 0.95000),
    (400018001103, 400018001, (:base_batch + 1), 0.95000),
    (400018001104, 400018001, (:base_batch + 1), 0.95000),
    (400018001105, 400018001, (:base_batch + 1), 0.95000),
    (400018001106, 400018001, (:base_batch + 1), 0.95000),
    (400018001107, 400018001, (:base_batch + 1), 0.95000),
    (400018001108, 400018001, (:base_batch + 1), 0.95000),
    (400018001109, 400018001, (:base_batch + 1), 0.95000),
    (400018001110, 400018001, (:base_batch + 1), 0.95000),
    (400018001111, 400018001, (:base_batch + 1), 0.95000),
    (400018001112, 400018001, (:base_batch + 1), 0.95000),
    (400018001113, 400018001, (:base_batch + 1), 0.95000),
    (400018001114, 400018001, (:base_batch + 1), 0.95000),
    (400018001115, 400018001, (:base_batch + 1), 0.95000),
    (400018001116, 400018001, (:base_batch + 1), 0.95000),
    (400018001117, 400018001, (:base_batch + 1), 0.95000),
    (400018001118, 400018001, (:base_batch + 1), 0.95000),
    (400018001119, 400018001, (:base_batch + 1), 0.95000),
    (400018001120, 400018001, (:base_batch + 1), 0.95000),
    (400018001121, 400018001, (:base_batch + 1), 0.95000),
    (400018001122, 400018001, (:base_batch + 1), 0.95000),
    (400018001123, 400018001, (:base_batch + 1), 0.95000),
    (400018001124, 400018001, (:base_batch + 1), 0.95000),
    (400018001125, 400018001, (:base_batch + 1), 0.95000),
    (400018001126, 400018001, (:base_batch + 1), 0.95000),
    (400018001127, 400018001, (:base_batch + 1), 0.95000),
    (400018001128, 400018001, (:base_batch + 1), 0.95000),
    (400018001129, 400018001, (:base_batch + 1), 0.95000),
    (400018001130, 400018001, (:base_batch + 1), 0.95000),
    (400018001131, 400018001, (:base_batch + 1), 0.95000),
    (400018001132, 400018001, (:base_batch + 1), 0.95000),
    (400018001133, 400018001, (:base_batch + 1), 0.95000),
    (400018001134, 400018001, (:base_batch + 1), 0.95000),
    (400018001135, 400018001, (:base_batch + 1), 0.90000),
    (400018001136, 400018001, (:base_batch + 1), 0.90000),
    (400018001137, 400018001, (:base_batch + 1), 0.90000),
    (400018001138, 400018001, (:base_batch + 1), 0.90000),
    (400018001139, 400018001, (:base_batch + 1), 0.95000),
    (400018001140, 400018001, (:base_batch + 1), 0.95000),
    (400018001141, 400018001, (:base_batch + 1), 0.95000),
    (400018001142, 400018001, (:base_batch + 1), 0.95000),
    (400018001143, 400018001, (:base_batch + 1), 0.95000),
    (400018001144, 400018001, (:base_batch + 1), 0.95000),
    (400018001145, 400018001, (:base_batch + 1), 0.95000),
    (400018001146, 400018001, (:base_batch + 1), 0.95000),
    (400018001147, 400018001, (:base_batch + 1), 0.95000),
    (400018001148, 400018001, (:base_batch + 1), 0.95000),
    (400018001149, 400018001, (:base_batch + 1), 0.95000);

-- ----------------------------------------------------------------------------
-- 8. DELIVERY CAPABILITY
-- ----------------------------------------------------------------------------
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available)
VALUES (400018001, TRUE, FALSE);
-- self_delivery_available FALSE = not stated in the JSON; delivery is via the partners below
INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id,
                                          is_available, delivery_charge_type_code, effective_from)
SELECT :base_rdp + row_number() OVER (ORDER BY p.delivery_provider_id), 400018001, p.delivery_provider_id, TRUE,
       'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM delivery_provider p WHERE p.provider_code IN ('ZOMATO', 'SWIGGY');
-- delivery_charge_type_code is NOT NULL with no neutral value; 'fixed' + NULL base_delivery_charge = charge unknown

-- ----------------------------------------------------------------------------
-- 9. BOARD MAPPINGS (board <- categories <- items, JSON order)
-- ----------------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400018001, 400018001001, 400018001001, 1),
    (400018001, 400018001001, 400018001002, 2),
    (400018001, 400018001001, 400018001003, 3),
    (400018001, 400018001001, 400018001004, 4),
    (400018001, 400018001001, 400018001005, 5),
    (400018001, 400018001001, 400018001006, 6),
    (400018001, 400018001001, 400018001007, 7),
    (400018001, 400018001001, 400018001008, 8),
    (400018001, 400018001001, 400018001009, 9),
    (400018001, 400018001001, 400018001010, 10),
    (400018001, 400018001001, 400018001011, 11),
    (400018001, 400018001001, 400018001012, 12),
    (400018001, 400018001001, 400018001013, 13),
    (400018001, 400018001001, 400018001014, 14),
    (400018001, 400018001001, 400018001015, 15);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id,
                             display_sequence)
VALUES
    (400018001001, 400018001, 400018001001, 400018001001, 400018001001, 1),
    (400018001002, 400018001, 400018001001, 400018001002, 400018001001, 2),
    (400018001003, 400018001, 400018001001, 400018001003, 400018001001, 3),
    (400018001004, 400018001, 400018001001, 400018001004, 400018001001, 4),
    (400018001005, 400018001, 400018001001, 400018001005, 400018001001, 5),
    (400018001006, 400018001, 400018001001, 400018001006, 400018001001, 6),
    (400018001007, 400018001, 400018001001, 400018001007, 400018001001, 7),
    (400018001008, 400018001, 400018001001, 400018001008, 400018001001, 8),
    (400018001009, 400018001, 400018001001, 400018001009, 400018001001, 9),
    (400018001010, 400018001, 400018001001, 400018001010, 400018001001, 10),
    (400018001011, 400018001, 400018001001, 400018001011, 400018001001, 11),
    (400018001012, 400018001, 400018001001, 400018001012, 400018001001, 12),
    (400018001013, 400018001, 400018001001, 400018001013, 400018001001, 13),
    (400018001014, 400018001, 400018001001, 400018001014, 400018001001, 14),
    (400018001015, 400018001, 400018001001, 400018001015, 400018001001, 15),
    (400018001016, 400018001, 400018001001, 400018001016, 400018001001, 16),
    (400018001017, 400018001, 400018001001, 400018001017, 400018001002, 17),
    (400018001018, 400018001, 400018001001, 400018001018, 400018001002, 18),
    (400018001019, 400018001, 400018001001, 400018001019, 400018001002, 19),
    (400018001020, 400018001, 400018001001, 400018001020, 400018001002, 20),
    (400018001021, 400018001, 400018001001, 400018001021, 400018001002, 21),
    (400018001022, 400018001, 400018001001, 400018001022, 400018001002, 22),
    (400018001023, 400018001, 400018001001, 400018001023, 400018001002, 23),
    (400018001024, 400018001, 400018001001, 400018001024, 400018001002, 24),
    (400018001025, 400018001, 400018001001, 400018001025, 400018001002, 25),
    (400018001026, 400018001, 400018001001, 400018001026, 400018001002, 26),
    (400018001027, 400018001, 400018001001, 400018001027, 400018001002, 27),
    (400018001028, 400018001, 400018001001, 400018001028, 400018001002, 28),
    (400018001029, 400018001, 400018001001, 400018001029, 400018001003, 29),
    (400018001030, 400018001, 400018001001, 400018001030, 400018001003, 30),
    (400018001031, 400018001, 400018001001, 400018001031, 400018001003, 31),
    (400018001032, 400018001, 400018001001, 400018001032, 400018001003, 32),
    (400018001033, 400018001, 400018001001, 400018001033, 400018001003, 33),
    (400018001034, 400018001, 400018001001, 400018001034, 400018001003, 34),
    (400018001035, 400018001, 400018001001, 400018001035, 400018001003, 35),
    (400018001036, 400018001, 400018001001, 400018001036, 400018001004, 36),
    (400018001037, 400018001, 400018001001, 400018001037, 400018001004, 37),
    (400018001038, 400018001, 400018001001, 400018001038, 400018001004, 38),
    (400018001039, 400018001, 400018001001, 400018001039, 400018001004, 39),
    (400018001040, 400018001, 400018001001, 400018001040, 400018001004, 40),
    (400018001041, 400018001, 400018001001, 400018001041, 400018001004, 41),
    (400018001042, 400018001, 400018001001, 400018001042, 400018001004, 42),
    (400018001043, 400018001, 400018001001, 400018001043, 400018001004, 43),
    (400018001044, 400018001, 400018001001, 400018001044, 400018001004, 44),
    (400018001045, 400018001, 400018001001, 400018001045, 400018001004, 45),
    (400018001046, 400018001, 400018001001, 400018001046, 400018001004, 46),
    (400018001047, 400018001, 400018001001, 400018001047, 400018001004, 47),
    (400018001048, 400018001, 400018001001, 400018001048, 400018001005, 48),
    (400018001049, 400018001, 400018001001, 400018001049, 400018001005, 49),
    (400018001050, 400018001, 400018001001, 400018001050, 400018001005, 50),
    (400018001051, 400018001, 400018001001, 400018001051, 400018001005, 51),
    (400018001052, 400018001, 400018001001, 400018001052, 400018001005, 52),
    (400018001053, 400018001, 400018001001, 400018001053, 400018001005, 53),
    (400018001054, 400018001, 400018001001, 400018001054, 400018001005, 54),
    (400018001055, 400018001, 400018001001, 400018001055, 400018001005, 55),
    (400018001056, 400018001, 400018001001, 400018001056, 400018001005, 56),
    (400018001057, 400018001, 400018001001, 400018001057, 400018001005, 57),
    (400018001058, 400018001, 400018001001, 400018001058, 400018001005, 58),
    (400018001059, 400018001, 400018001001, 400018001059, 400018001005, 59),
    (400018001060, 400018001, 400018001001, 400018001060, 400018001005, 60),
    (400018001061, 400018001, 400018001001, 400018001061, 400018001006, 61),
    (400018001062, 400018001, 400018001001, 400018001062, 400018001006, 62),
    (400018001063, 400018001, 400018001001, 400018001063, 400018001006, 63),
    (400018001064, 400018001, 400018001001, 400018001064, 400018001006, 64),
    (400018001065, 400018001, 400018001001, 400018001065, 400018001007, 65),
    (400018001066, 400018001, 400018001001, 400018001066, 400018001007, 66),
    (400018001067, 400018001, 400018001001, 400018001067, 400018001007, 67),
    (400018001068, 400018001, 400018001001, 400018001068, 400018001007, 68),
    (400018001069, 400018001, 400018001001, 400018001069, 400018001007, 69),
    (400018001070, 400018001, 400018001001, 400018001070, 400018001007, 70),
    (400018001071, 400018001, 400018001001, 400018001071, 400018001007, 71),
    (400018001072, 400018001, 400018001001, 400018001072, 400018001007, 72),
    (400018001073, 400018001, 400018001001, 400018001073, 400018001007, 73),
    (400018001074, 400018001, 400018001001, 400018001074, 400018001007, 74),
    (400018001075, 400018001, 400018001001, 400018001075, 400018001007, 75),
    (400018001076, 400018001, 400018001001, 400018001076, 400018001007, 76),
    (400018001077, 400018001, 400018001001, 400018001077, 400018001007, 77),
    (400018001078, 400018001, 400018001001, 400018001078, 400018001008, 78),
    (400018001079, 400018001, 400018001001, 400018001079, 400018001008, 79),
    (400018001080, 400018001, 400018001001, 400018001080, 400018001008, 80),
    (400018001081, 400018001, 400018001001, 400018001081, 400018001009, 81),
    (400018001082, 400018001, 400018001001, 400018001082, 400018001009, 82),
    (400018001083, 400018001, 400018001001, 400018001083, 400018001009, 83),
    (400018001084, 400018001, 400018001001, 400018001084, 400018001009, 84),
    (400018001085, 400018001, 400018001001, 400018001085, 400018001009, 85),
    (400018001086, 400018001, 400018001001, 400018001086, 400018001009, 86),
    (400018001087, 400018001, 400018001001, 400018001087, 400018001009, 87),
    (400018001088, 400018001, 400018001001, 400018001088, 400018001009, 88),
    (400018001089, 400018001, 400018001001, 400018001089, 400018001009, 89),
    (400018001090, 400018001, 400018001001, 400018001090, 400018001009, 90),
    (400018001091, 400018001, 400018001001, 400018001091, 400018001009, 91),
    (400018001092, 400018001, 400018001001, 400018001092, 400018001009, 92),
    (400018001093, 400018001, 400018001001, 400018001093, 400018001009, 93),
    (400018001094, 400018001, 400018001001, 400018001094, 400018001009, 94),
    (400018001095, 400018001, 400018001001, 400018001095, 400018001010, 95),
    (400018001096, 400018001, 400018001001, 400018001096, 400018001010, 96),
    (400018001097, 400018001, 400018001001, 400018001097, 400018001010, 97),
    (400018001098, 400018001, 400018001001, 400018001098, 400018001010, 98),
    (400018001099, 400018001, 400018001001, 400018001099, 400018001010, 99),
    (400018001100, 400018001, 400018001001, 400018001100, 400018001010, 100),
    (400018001101, 400018001, 400018001001, 400018001101, 400018001010, 101),
    (400018001102, 400018001, 400018001001, 400018001102, 400018001010, 102),
    (400018001103, 400018001, 400018001001, 400018001103, 400018001010, 103),
    (400018001104, 400018001, 400018001001, 400018001104, 400018001010, 104),
    (400018001105, 400018001, 400018001001, 400018001105, 400018001010, 105),
    (400018001106, 400018001, 400018001001, 400018001106, 400018001010, 106),
    (400018001107, 400018001, 400018001001, 400018001107, 400018001010, 107),
    (400018001108, 400018001, 400018001001, 400018001108, 400018001011, 108),
    (400018001109, 400018001, 400018001001, 400018001109, 400018001011, 109),
    (400018001110, 400018001, 400018001001, 400018001110, 400018001011, 110),
    (400018001111, 400018001, 400018001001, 400018001111, 400018001011, 111),
    (400018001112, 400018001, 400018001001, 400018001112, 400018001011, 112),
    (400018001113, 400018001, 400018001001, 400018001113, 400018001011, 113),
    (400018001114, 400018001, 400018001001, 400018001114, 400018001011, 114),
    (400018001115, 400018001, 400018001001, 400018001115, 400018001011, 115),
    (400018001116, 400018001, 400018001001, 400018001116, 400018001011, 116),
    (400018001117, 400018001, 400018001001, 400018001117, 400018001011, 117),
    (400018001118, 400018001, 400018001001, 400018001118, 400018001012, 118),
    (400018001119, 400018001, 400018001001, 400018001119, 400018001012, 119),
    (400018001120, 400018001, 400018001001, 400018001120, 400018001012, 120),
    (400018001121, 400018001, 400018001001, 400018001121, 400018001012, 121),
    (400018001122, 400018001, 400018001001, 400018001122, 400018001013, 122),
    (400018001123, 400018001, 400018001001, 400018001123, 400018001013, 123),
    (400018001124, 400018001, 400018001001, 400018001124, 400018001013, 124),
    (400018001125, 400018001, 400018001001, 400018001125, 400018001013, 125),
    (400018001126, 400018001, 400018001001, 400018001126, 400018001013, 126),
    (400018001127, 400018001, 400018001001, 400018001127, 400018001013, 127),
    (400018001128, 400018001, 400018001001, 400018001128, 400018001013, 128),
    (400018001129, 400018001, 400018001001, 400018001129, 400018001013, 129),
    (400018001130, 400018001, 400018001001, 400018001130, 400018001014, 130),
    (400018001131, 400018001, 400018001001, 400018001131, 400018001014, 131),
    (400018001132, 400018001, 400018001001, 400018001132, 400018001015, 132);

-- ----------------------------------------------------------------------------
-- 10. LOAD SUMMARY (printed by psql before COMMIT)
-- ----------------------------------------------------------------------------
SELECT 'menu_category' AS table_name, count(*) AS rows_loaded FROM menu_category WHERE restaurant_id = 400018001
UNION ALL SELECT 'menu_item', count(*) FROM menu_item WHERE restaurant_id = 400018001
UNION ALL SELECT 'menu_item_variant', count(*) FROM menu_item_variant v JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 400018001
UNION ALL SELECT 'menu_item_price', count(*) FROM menu_item_price p JOIN menu_item_variant v USING (variant_id) JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 400018001
UNION ALL SELECT 'menu_board_item', count(*) FROM menu_board_item WHERE restaurant_id = 400018001
UNION ALL SELECT 'items linked to a canonical dish', count(*) FROM menu_item WHERE restaurant_id = 400018001 AND canonical_dish_id IS NOT NULL
UNION ALL SELECT 'items needing review', count(*) FROM menu_item WHERE restaurant_id = 400018001 AND verification_status_code = 'needs_review';

COMMIT;

-- ============================================================================
-- BLOCK 1 - ROWS NEEDING REVIEW OR WITH CONFIDENCE < 0.80
-- ============================================================================
-- Category level:
--   - 'PANEER SEZWAN FRIED RICE' (pages[0].sections[6], 13 items): the category text looks like the first item's name repeated by the OCR; every item in it is a veg rice dish, so it probably belongs to 'CHINESE VEG RICE'. Kept verbatim as the JSON gives it.
-- menu_item rows (1):
--   - item 400018001098  VEG TRIPPLE SEZWAN NOODLES  [pages[1].sections[0].columns[0].items[3]]  conf 0.70: exact repeat of the previous line pages[1].sections[0].columns[0].items[2] in the same category (possible OCR repeat); kept as a separate row per the no-de-duplication rule
-- menu_item_price rows (8):
--   - price 400018001078  PANEER SEZWAN FRIED RICE / Half = 170.00  [pages[0].sections[6].columns[0].items[0]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001079  PANEER SEZWAN FRIED RICE / Full = 210.00  [pages[0].sections[6].columns[0].items[0]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001080  MASHROOM FRIED RICE / Half = 140.00  [pages[0].sections[6].columns[0].items[1]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001081  MASHROOM FRIED RICE / Full = 190.00  [pages[0].sections[6].columns[0].items[1]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001093  CHICKEN BIRYANI / Half = 150.00  [pages[0].sections[7].columns[0].items[0]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001094  CHICKEN BIRYANI / Full = 200.00  [pages[0].sections[7].columns[0].items[0]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001095  CHICKEN HYDRABADI BIRYANI / Half = 170.00  [pages[0].sections[7].columns[0].items[1]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)
--   - price 400018001096  CHICKEN HYDRABADI BIRYANI / Full = 220.00  [pages[0].sections[7].columns[0].items[1]]  conf 0.70: two unlabeled prices; ascending pair read as Half/Full by analogy with the Half/Full-labeled rows in the same restaurant (no legend printed for this line)

-- ============================================================================
-- BLOCK 2 - JSON CONTENT WITH NO SCHEMA COLUMN (kept here, not dropped)
-- ============================================================================
--   - Monthly tiffin service printed on both pages: "WE ALSO UNDERTAKE Monthly Tiffin Services" - "Fish Thali - 100/-", "Chicken Thali - 100/-", "Veg Thali - 80/-". Not loaded as items (no category or contents in the JSON); say if they should be.
--   - JSON price_per_person is empty.
--   - JSON establishment_id / restaurant_id 400081001 was overridden by the owner-supplied 400018001.
--   - Page images MBsKitchen1.jpg, MBsKitchen2.jpg: no media storage URIs, so media_asset / menu_extraction_image are not populated.
--   - change_event_outbox is not written by this script.
