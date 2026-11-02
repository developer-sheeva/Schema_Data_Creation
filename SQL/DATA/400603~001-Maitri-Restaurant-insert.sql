-- ============================================================================
-- KHAUSTAN.COM - KhaustanRestaurantMenu - DATA LOAD FOR MAITRI RESTAURANT
-- Source JSON : Maitri_Restaurant_Menu_OCR.json
-- Namespace   : establishment_id = restaurant_id = source_id = 400603001   (all child IDs are 400603001NNN, NNN = 001..999)
-- Target      : PostgreSQL, run with psql (uses \connect, \set, \encoding, \gset)
-- ============================================================================
--
-- WHAT THIS SCRIPT LOADS
--   25 categories | 222 menu items | 227 variants | 227 prices | 1 a_la_carte board
--   216 distinct canonical-dish keys (new rows only where no exact normalized-name match already exists)
--
-- ID RULES
--   Deterministic: menu_board / menu_category / menu_item / menu_item_variant / menu_item_price / menu_board_item = 400603001NNN.
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
--   - Hours 11:00 to 23:59 as instructed by the owner (JSON header said "11 am-12:30 am"; the printed menu says "11.00 A.M TO 11.59P.M"); applied to all 7 days.
--   - GST (owner instruction): printed "All Prices are Exclusive of GST Tax. Extra 5% GST Applicable" -> every menu_item_price row carries tax_regime_code 'GST', tax_inclusion_code 'exclusive', tax_rate 5.0000 so the viewing app can show the additional-5%-GST message. The value 'GST' for tax_regime_code is chosen here (the schema leaves that column open).
--   - effective_from of every price = 2026-05-06, from "Prices With Effect From 06/05/2026" read as DD/MM/YYYY.
--   - City Thane is taken from the JSON address ("Thane East"); the JSON has no PIN, so postal_code is NULL (the ID prefix 400603 is not used to guess one).
--   - State is not in the JSON: defaulted to Maharashtra (standing rule).
--   - Service modes recorded only where the JSON states them: takeaway ("TAKE AWAY"), delivery ("FOR HOME DELIVERY CALL ..."; self delivery inferred because no partner is named) and bulk_catering (bulk orders). dine_in is not stated and is not recorded.
--   - First phone listed is marked primary; is_personal_number left at its FALSE default.
--   - Owner rule: a price that is not printed takes the maximum printed price - no Maitri line needed it.
--
-- INFERRED LEGENDS / STRUCTURE
--   - 'Chi. Handi (H/F)' -> item 'Chi. Handi' with Half / Full variants (legend '(H/F)' read as Half/Full)
--   - 'Chi. Makhanwala (H/F)' -> item 'Chi. Makhanwala' with Half / Full variants (legend '(H/F)' read as Half/Full)
--   - 'Mutton Handi (H/F)' -> item 'Mutton Handi' with Half / Full variants (legend '(H/F)' read as Half/Full)
--   - 'Neer Dosa (1 pcs.)' -> item 'Neer Dosa' + variant '1 pc' (quantity marker moved out of the name)
--   - 'Chi. Tandoori (H/F)' -> item 'Chi. Tandoori' with Half / Full variants (legend '(H/F)' read as Half/Full)
--   - 'Bisleri Packaged Water (1 Ltr)' -> item 'Bisleri Packaged Water' + variant '1 Ltr' (quantity marker moved out of the name)
--   - 'Bisleri Packaged Water (500ml)' -> item 'Bisleri Packaged Water' + variant '500 ml' (quantity marker moved out of the name)
--   - 'Soft Drinks (600ml)' -> item 'Soft Drinks' + variant '600 ml' (quantity marker moved out of the name)
--   - 'Bisleri Packaged Water': two JSON lines (pages[1].sections[9].columns[0].items[0] and pages[1].sections[9].columns[0].items[1]) merged into one item with 2 size variants
--
-- CLASSIFICATION INFERENCES (confidence 0.85, not flagged for review)
--   - 2 item(s): classification inferred: beverage with no non-veg marker in the JSON
--   - 1 item(s): classification inferred: salad with no non-veg marker in the JSON
--
-- SCHEMA OBSERVATIONS FLAGGED (not worked around silently)
--   - No restaurant-level GST field exists (neither a "prices exclusive of GST" flag nor a GSTIN column). GST is therefore carried on each menu_item_price row (tax_regime_code / tax_inclusion_code / tax_rate); GSTIN 27AABFM7666K1ZY is kept in Block 2.
--
-- Rows needing review / confidence < 0.80 are listed in the first trailing comment block (3 item row(s), 3 price row(s)); restaurant-level notes with no schema column are in the second block.

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
    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400603001)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400603001)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 400603001)
       OR EXISTS (SELECT 1 FROM menu_item WHERE restaurant_id = 400603001)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400603001 AND source_id = 400603001) THEN
        RAISE EXCEPTION 'Restaurant 400603001 is already loaded; aborting so menu items are not duplicated.';
    END IF;
    SELECT string_agg(n.code, ', ') INTO v_missing
    FROM (VALUES ('CHICKEN'), ('EGG'), ('MUTTON'), ('SEAFOOD')) AS n(code)
    WHERE NOT EXISTS (SELECT 1 FROM protein_type t WHERE upper(t.code) = n.code);
    IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'Missing protein_type lookup row(s): %', v_missing; END IF;
    SELECT string_agg(n.code, ', ') INTO v_missing
    FROM (VALUES ('takeaway'), ('delivery'), ('bulk_catering')) AS n(code)
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

-- ----------------------------------------------------------------------------
-- 2. BRAND / ESTABLISHMENT / RESTAURANT / SOURCE / EXTRACTION BATCH
-- ----------------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2, locality, city, state,
                           email_id, latitude, longitude)
VALUES (400603001, 'Maitri Restaurant', 'maitri restaurant', 'Shop no. 6,7,8, Narayan Niwas', 'Opp Thane Railway Station',
        'Thane East', 'Thane', 'Maharashtra', 'maitrihotelgvb@gmail.com',
        19.18518904270521, 72.97528530790134);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, veg_nonveg_status,
                        has_bar, bar_license_type)
VALUES (400603001, 400603001, 'Maitri Restaurant', 'maitri restaurant', 'veg_and_nonveg', FALSE, 'none');
INSERT INTO source_record (source_id, source_type_code, external_reference)
VALUES (400603001, 'ai_menu_extraction', 'Maitri_Restaurant_Menu_OCR.json');
INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at,
                                   status_code, overall_confidence)
VALUES ((:base_batch + 1), 400603001, 400603001, (clock_timestamp() AT TIME ZONE 'UTC'),
        (clock_timestamp() AT TIME ZONE 'UTC'), 'completed', 0.94212);
-- overall_confidence = mean of the menu_item_source confidences below

-- ----------------------------------------------------------------------------
-- 3. PHONES / HOURS / TAGS / SERVICE MODES
-- ----------------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (:base_phone + 1, 400603001, '7304390358', TRUE),
    (:base_phone + 2, 400603001, '9930853152', FALSE);
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (:base_hours + 1, 400603001, 1, 1, TIME '11:00', TIME '23:59'),
    (:base_hours + 2, 400603001, 2, 1, TIME '11:00', TIME '23:59'),
    (:base_hours + 3, 400603001, 3, 1, TIME '11:00', TIME '23:59'),
    (:base_hours + 4, 400603001, 4, 1, TIME '11:00', TIME '23:59'),
    (:base_hours + 5, 400603001, 5, 1, TIME '11:00', TIME '23:59'),
    (:base_hours + 6, 400603001, 6, 1, TIME '11:00', TIME '23:59'),
    (:base_hours + 7, 400603001, 7, 1, TIME '11:00', TIME '23:59');
INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT 400603001, m.service_mode_id, TRUE, v.notes
FROM (VALUES
    ('takeaway', 'JSON: "TAKE AWAY"'),
    ('delivery', 'JSON: "FOR HOME DELIVERY CALL 7304390358, 9930853152"'),
    ('bulk_catering', 'JSON: "Bulk Biryani" and "Bulk Gravy" lines; orders at least 6 hrs before delivery')
) AS v(code, notes)
JOIN service_mode m ON m.code = v.code;

-- ----------------------------------------------------------------------------
-- 4. CANONICAL DISHES - 216 keys; inserted only where no exact normalized-name match exists
-- ----------------------------------------------------------------------------
WITH src (seq, canonical_name, normalized_name, food_classification_code, protein_code,
          is_jain, is_vegan, is_eggless) AS (
    VALUES
    (1, 'Chi. Shorba', 'chi. shorba', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (2, 'Chi. Manchow Soup', 'chi. manchow soup', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (3, 'Sweet Corn Chi. Soup', 'sweet corn chi. soup', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (4, 'Palak Shorba', 'palak shorba', 'veg', NULL, NULL, NULL, TRUE),
    (5, 'Sweet Corn Veg. Soup', 'sweet corn veg. soup', 'veg', NULL, NULL, NULL, TRUE),
    (6, 'Tomato Shorba', 'tomato shorba', 'veg', NULL, NULL, NULL, TRUE),
    (7, 'Veg. Manchow Soup', 'veg. manchow soup', 'veg', NULL, NULL, NULL, TRUE),
    (8, 'Paplet Masala', 'paplet masala', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (9, 'Surmai Masala', 'surmai masala', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (10, 'Prawns Masala', 'prawns masala', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (11, 'Bangda Masala', 'bangda masala', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (12, 'Rawas Masala', 'rawas masala', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (13, 'Chi. Aftab', 'chi. aftab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (14, 'Chi. Afghani', 'chi. afghani', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (15, 'Chi. Handi', 'chi. handi', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (16, 'Chi. Kolhapuri', 'chi. kolhapuri', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (17, 'Chi. Maharaja', 'chi. maharaja', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (18, 'Chi. Makhanwala', 'chi. makhanwala', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (19, 'Chi. Masala', 'chi. masala', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (20, 'Chi. Moghlai', 'chi. moghlai', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (21, 'Chi. Kangda', 'chi. kangda', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (22, 'Chi. Hyderabadi', 'chi. hyderabadi', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (23, 'Murg Masalam', 'murg masalam', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (24, 'Liver Masala', 'liver masala', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (25, 'Chi. Tikka Masala', 'chi. tikka masala', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (26, 'Chicken Sukka (S.I.)', 'chicken sukka (s.i.)', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (27, 'Chicken Tawa', 'chicken tawa', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (28, 'Chicken Bhoona Masala', 'chicken bhoona masala', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (29, 'Mutton Rogan Josh', 'mutton rogan josh', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (30, 'Mutton Handi', 'mutton handi', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (31, 'Mutton Kadai', 'mutton kadai', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (32, 'Mutton Kheema', 'mutton kheema', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (33, 'Mutton Kolhapuri', 'mutton kolhapuri', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (34, 'Mutton Masala', 'mutton masala', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (35, 'Mutton Sukka (S.I.)', 'mutton sukka (s.i.)', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (36, 'Paneer Kadai', 'paneer kadai', 'veg', NULL, NULL, FALSE, TRUE),
    (37, 'Paneer Handi', 'paneer handi', 'veg', NULL, NULL, FALSE, TRUE),
    (38, 'Paneer Kolhapuri', 'paneer kolhapuri', 'veg', NULL, NULL, FALSE, TRUE),
    (39, 'Veg. Kurma', 'veg. kurma', 'veg', NULL, NULL, NULL, TRUE),
    (40, 'Veg. Maharaja', 'veg. maharaja', 'veg', NULL, NULL, NULL, TRUE),
    (41, 'Alu Gobi Masala', 'alu gobi masala', 'veg', NULL, FALSE, NULL, TRUE),
    (42, 'Methi Malai Mutter', 'methi malai mutter', 'veg', NULL, NULL, FALSE, TRUE),
    (43, 'Mix Vegetable', 'mix vegetable', 'veg', NULL, NULL, NULL, TRUE),
    (44, 'Navratna Kurma', 'navratna kurma', 'veg', NULL, NULL, NULL, TRUE),
    (45, 'Veg. Aftab', 'veg. aftab', 'veg', NULL, NULL, NULL, TRUE),
    (46, 'Veg. Handi', 'veg. handi', 'veg', NULL, NULL, NULL, TRUE),
    (47, 'Veg. Hyderabadi', 'veg. hyderabadi', 'veg', NULL, NULL, NULL, TRUE),
    (48, 'Veg. Kadai', 'veg. kadai', 'veg', NULL, NULL, NULL, TRUE),
    (49, 'Veg. Kolhapuri', 'veg. kolhapuri', 'veg', NULL, NULL, NULL, TRUE),
    (50, 'Veg. Makhanwala', 'veg. makhanwala', 'veg', NULL, NULL, FALSE, TRUE),
    (51, 'Mushroom Masala', 'mushroom masala', 'veg', NULL, FALSE, NULL, TRUE),
    (52, 'Green Peas Masala', 'green peas masala', 'veg', NULL, NULL, NULL, TRUE),
    (53, 'Channa Masala', 'channa masala', 'veg', NULL, NULL, NULL, TRUE),
    (54, 'Paneer Palak', 'paneer palak', 'veg', NULL, NULL, FALSE, TRUE),
    (55, 'Paneer Butter Masala', 'paneer butter masala', 'veg', NULL, NULL, FALSE, TRUE),
    (56, 'Babycorn Mushroom Masala', 'babycorn mushroom masala', 'veg', NULL, FALSE, NULL, TRUE),
    (57, 'Paneer Makhanwala', 'paneer makhanwala', 'veg', NULL, NULL, FALSE, TRUE),
    (58, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'veg', NULL, FALSE, FALSE, TRUE),
    (59, 'Paneer Mutter', 'paneer mutter', 'veg', NULL, NULL, FALSE, TRUE),
    (60, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL, NULL, FALSE, TRUE),
    (61, 'Veg. Afgani Handi', 'veg. afgani handi', 'veg', NULL, NULL, NULL, TRUE),
    (62, 'Dal Khichdi', 'dal khichdi', 'veg', NULL, NULL, NULL, TRUE),
    (63, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'veg', NULL, NULL, NULL, TRUE),
    (64, 'Palak Khichdi', 'palak khichdi', 'veg', NULL, NULL, NULL, TRUE),
    (65, 'Chi. Khichdi', 'chi. khichdi', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (66, 'Chi. Biryani', 'chi. biryani', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (67, 'Egg. Biryani', 'egg. biryani', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (68, 'Mutton Biryani', 'mutton biryani', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (69, 'Prawns Biryani', 'prawns biryani', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (70, 'Veg. Biryani', 'veg. biryani', 'veg', NULL, NULL, NULL, TRUE),
    (71, 'Paneer Biryani', 'paneer biryani', 'veg', NULL, NULL, FALSE, TRUE),
    (72, 'Tawa Pulav', 'tawa pulav', 'veg', NULL, NULL, NULL, TRUE),
    (73, 'Veg. Pulav', 'veg. pulav', 'veg', NULL, NULL, NULL, TRUE),
    (74, 'Green Peas Pulav', 'green peas pulav', 'veg', NULL, NULL, NULL, TRUE),
    (75, 'Jeera Rice', 'jeera rice', 'veg', NULL, NULL, NULL, TRUE),
    (76, 'Steamed Basmati Rice', 'steamed basmati rice', 'veg', NULL, NULL, TRUE, TRUE),
    (77, 'Plain Rice', 'plain rice', 'veg', NULL, NULL, TRUE, TRUE),
    (78, 'Curd Rice Tadka', 'curd rice tadka', 'veg', NULL, NULL, FALSE, TRUE),
    (79, 'Biryani Rice', 'biryani rice', 'veg', NULL, NULL, NULL, TRUE),
    (80, 'Dal Fry', 'dal fry', 'veg', NULL, NULL, NULL, TRUE),
    (81, 'Dal Tadka', 'dal tadka', 'veg', NULL, NULL, NULL, TRUE),
    (82, 'Palak Dal', 'palak dal', 'veg', NULL, NULL, NULL, TRUE),
    (83, 'Dal Kolhapuri', 'dal kolhapuri', 'veg', NULL, NULL, NULL, TRUE),
    (84, 'Neer Dosa', 'neer dosa', 'veg', NULL, NULL, TRUE, TRUE),
    (85, 'Roti (Plain / Butter)', 'roti (plain / butter)', 'veg', NULL, NULL, FALSE, TRUE),
    (86, 'Naan (Plain / Butter)', 'naan (plain / butter)', 'veg', NULL, NULL, FALSE, TRUE),
    (87, 'Paratha (Plain / Butter)', 'paratha (plain / butter)', 'veg', NULL, NULL, FALSE, TRUE),
    (88, 'Stuffed Paratha', 'stuffed paratha', 'veg', NULL, NULL, NULL, TRUE),
    (89, 'Garlic Butter Naan', 'garlic butter naan', 'veg', NULL, FALSE, FALSE, TRUE),
    (90, 'Methi Butter Paratha', 'methi butter paratha', 'veg', NULL, NULL, FALSE, TRUE),
    (91, 'Alu Butter Paratha', 'alu butter paratha', 'veg', NULL, FALSE, FALSE, TRUE),
    (92, 'Cheese Paratha', 'cheese paratha', 'veg', NULL, NULL, FALSE, TRUE),
    (93, 'Chi. Stuffed Paratha', 'chi. stuffed paratha', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (94, 'Cheese Garlic Naan', 'cheese garlic naan', 'veg', NULL, FALSE, FALSE, TRUE),
    (95, 'Chi. Fried Rice', 'chi. fried rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (96, 'Mix Fried Rice', 'mix fried rice', NULL, NULL, NULL, NULL, NULL),
    (97, 'Prawns Fried Rice', 'prawns fried rice', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (98, 'Egg. Fried Rice', 'egg. fried rice', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (99, 'Veg. Fried Rice', 'veg. fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (100, 'Jeera Fried Rice', 'jeera fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (101, 'Chi. Triple Sz. Fried Rice', 'chi. triple sz. fried rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (102, 'Chi Manchurian Rice', 'chi manchurian rice', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (103, 'Veg. Triple Sz. Fried Rice', 'veg. triple sz. fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (104, 'Veg. Manchurian Rice', 'veg. manchurian rice', 'veg', NULL, NULL, NULL, TRUE),
    (105, 'Chi. Hakka Noodles', 'chi. hakka noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (106, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'veg', NULL, NULL, NULL, TRUE),
    (107, 'Prawns Hakka Noodles', 'prawns hakka noodles', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (108, 'Veg. Triples Sz. Noodles', 'veg. triples sz. noodles', 'veg', NULL, NULL, NULL, TRUE),
    (109, 'Chi. Triple Sz. Noodles', 'chi. triple sz. noodles', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (110, 'Green Salad', 'green salad', 'veg', NULL, NULL, TRUE, TRUE),
    (111, 'Boondi Raita', 'boondi raita', 'veg', NULL, NULL, FALSE, TRUE),
    (112, 'Veg. Raita', 'veg. raita', 'veg', NULL, NULL, FALSE, TRUE),
    (113, 'Plain Curd', 'plain curd', 'veg', NULL, NULL, FALSE, TRUE),
    (114, 'Pineapple Raita', 'pineapple raita', 'veg', NULL, NULL, FALSE, TRUE),
    (115, 'Cheese Cherry Pineapple', 'cheese cherry pineapple', 'veg', NULL, NULL, FALSE, TRUE),
    (116, 'Tandoori Salad', 'tandoori salad', 'veg', NULL, NULL, NULL, TRUE),
    (117, 'Paplet Tawa Fry', 'paplet tawa fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (118, 'Paplet Tandoori', 'paplet tandoori', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (119, 'Rawas Finger', 'rawas finger', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (120, 'Rawas Chilly', 'rawas chilly', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (121, 'Surmai Tawa Fry With Garlic', 'surmai tawa fry with garlic', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (122, 'Bangda Tawa Fry', 'bangda tawa fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (123, 'Bangda Oil Fry', 'bangda oil fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (124, 'Mandeli Rawa Fry', 'mandeli rawa fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (125, 'Prawns Chilly', 'prawns chilly', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (126, 'Prawns Koliwada', 'prawns koliwada', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (127, 'Prawns Masala Dry', 'prawns masala dry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (128, 'Prawns Manchurian', 'prawns manchurian', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (129, 'Bombil Fry', 'bombil fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (130, 'Bombil Tawa Fry', 'bombil tawa fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (131, 'Rawas Tawa', 'rawas tawa', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (132, 'Rawas Schezwan', 'rawas schezwan', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (133, 'Rawas Tikka', 'rawas tikka', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (134, 'Surmai Oil Fry', 'surmai oil fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (135, 'Surmai Rawa Fry', 'surmai rawa fry', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (136, 'Prawns 65', 'prawns 65', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (137, 'Prawns Butter Garlic', 'prawns butter garlic', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (138, 'Prawns Garlic Sauce', 'prawns garlic sauce', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (139, 'Prawns Schezwan', 'prawns schezwan', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (140, 'Prawns Salt Pepper', 'prawns salt pepper', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (141, 'Rawas Hariyali Tikka', 'rawas hariyali tikka', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (142, 'Rawas Nizamuddin Tikka', 'rawas nizamuddin tikka', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL),
    (143, 'Chi. 65', 'chi. 65', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (144, 'Chi. Chatpata', 'chi. chatpata', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (145, 'Chi. Mangolian', 'chi. mangolian', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (146, 'Chi. Malesian', 'chi. malesian', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (147, 'Chi. Chilly', 'chi. chilly', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (148, 'Chi. Crunchy', 'chi. crunchy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (149, 'Chi. Garlic', 'chi. garlic', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (150, 'Chi. Manchurian', 'chi. manchurian', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (151, 'Chi. Crispy', 'chi. crispy', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (152, 'Chi. Stic', 'chi. stic', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (153, 'Chi. Schezwan', 'chi. schezwan', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (154, 'Chi. Lollypop Oil Fry', 'chi. lollypop oil fry', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (155, 'Chi. Liver & Potat Oil Fry', 'chi. liver & potat oil fry', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (156, 'Liver Burji', 'liver burji', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (157, 'Chi. Reshmi Kebab', 'chi. reshmi kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (158, 'Chi. Malwani Kebab', 'chi. malwani kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (159, 'Chi. Jabuli Kebab', 'chi. jabuli kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (160, 'Chi. Banjara Kebab', 'chi. banjara kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (161, 'Chi. Pahadi Kebab', 'chi. pahadi kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (162, 'Chi. Pudina Kebab', 'chi. pudina kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (163, 'Chi. Seekh Kebab', 'chi. seekh kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (164, 'Chi. Tandoori', 'chi. tandoori', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (165, 'Chi. Tikka', 'chi. tikka', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (166, 'Chi. Tandoori Karkhana', 'chi. tandoori karkhana', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (167, 'Chi. Tangdi Kebab', 'chi. tangdi kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (168, 'Chi. Lollypop Tandoori', 'chi. lollypop tandoori', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (169, 'Liver Tandoori', 'liver tandoori', 'non_veg', NULL, FALSE, FALSE, NULL),
    (170, 'Chi. Malai Kebab', 'chi. malai kebab', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL),
    (171, 'Mutton Seekh Kebab', 'mutton seekh kebab', 'non_veg', 'MUTTON', FALSE, FALSE, NULL),
    (172, 'Egg Boiled', 'egg boiled', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (173, 'Egg Half Fry', 'egg half fry', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (174, 'Boiled Egg Burji', 'boiled egg burji', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (175, 'Egg Oil Fry', 'egg oil fry', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (176, 'Egg Omlet', 'egg omlet', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (177, 'Egg Pakoda', 'egg pakoda', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (178, 'Omelet Cheese', 'omelet cheese', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (179, 'Egg. Burji', 'egg. burji', 'egg', 'EGG', FALSE, FALSE, FALSE),
    (180, 'Paneer Chilly', 'paneer chilly', 'veg', NULL, NULL, FALSE, TRUE),
    (181, 'Paneer Manchurian', 'paneer manchurian', 'veg', NULL, NULL, FALSE, TRUE),
    (182, 'Paneer Stic', 'paneer stic', 'veg', NULL, NULL, FALSE, TRUE),
    (183, 'Paneer Schezwan', 'paneer schezwan', 'veg', NULL, NULL, FALSE, TRUE),
    (184, 'Paneer Tikka', 'paneer tikka', 'veg', NULL, NULL, FALSE, TRUE),
    (185, 'Stuffed Mushroom Tikka', 'stuffed mushroom tikka', 'veg', NULL, FALSE, NULL, TRUE),
    (186, 'Veg. Moti Seekh Kebab', 'veg. moti seekh kebab', 'veg', NULL, NULL, NULL, TRUE),
    (187, 'Alu Tandoori', 'alu tandoori', 'veg', NULL, FALSE, NULL, TRUE),
    (188, 'Gobi Tandoori', 'gobi tandoori', 'veg', NULL, NULL, NULL, TRUE),
    (189, 'Boiled Makai With Butter', 'boiled makai with butter', 'veg', NULL, NULL, FALSE, TRUE),
    (190, 'Boiled Veg. With Butter', 'boiled veg. with butter', 'veg', NULL, NULL, FALSE, TRUE),
    (191, 'Hara Bhara Kebab', 'hara bhara kebab', 'veg', NULL, NULL, NULL, TRUE),
    (192, 'Veg. Chatpata', 'veg. chatpata', 'veg', NULL, NULL, NULL, TRUE),
    (193, 'Veg. Pakoda', 'veg. pakoda', 'veg', NULL, NULL, NULL, TRUE),
    (194, 'Babycorn Chilly', 'babycorn chilly', 'veg', NULL, NULL, NULL, TRUE),
    (195, 'Gobi Manchurian', 'gobi manchurian', 'veg', NULL, NULL, NULL, TRUE),
    (196, 'Makai Tawan', 'makai tawan', 'veg', NULL, NULL, NULL, TRUE),
    (197, 'Veg. 65', 'veg. 65', 'veg', NULL, NULL, NULL, TRUE),
    (198, 'Veg. Chilly', 'veg. chilly', 'veg', NULL, NULL, NULL, TRUE),
    (199, 'Veg. Crispy', 'veg. crispy', 'veg', NULL, NULL, NULL, TRUE),
    (200, 'Veg. Crunchy', 'veg. crunchy', 'veg', NULL, NULL, NULL, TRUE),
    (201, 'Veg. Lollypop', 'veg. lollypop', 'veg', NULL, NULL, NULL, TRUE),
    (202, 'Veg. Manchurian', 'veg. manchurian', 'veg', NULL, NULL, NULL, TRUE),
    (203, 'Veg. Seekh Kebab', 'veg. seekh kebab', 'veg', NULL, NULL, NULL, TRUE),
    (204, 'Soyabean Chilly', 'soyabean chilly', 'veg', NULL, NULL, NULL, TRUE),
    (205, 'Soyabean Manchurian', 'soyabean manchurian', 'veg', NULL, NULL, NULL, TRUE),
    (206, 'Soyabean Schezwan', 'soyabean schezwan', 'veg', NULL, NULL, NULL, TRUE),
    (207, 'Mushroom Manchurian', 'mushroom manchurian', 'veg', NULL, FALSE, NULL, TRUE),
    (208, 'Mushroom Chilly', 'mushroom chilly', 'veg', NULL, FALSE, NULL, TRUE),
    (209, 'Mushroom Tikka', 'mushroom tikka', 'veg', NULL, FALSE, NULL, TRUE),
    (210, 'Channa Chatpata', 'channa chatpata', 'veg', NULL, NULL, NULL, TRUE),
    (211, 'Channa Oil Fry With Garlic', 'channa oil fry with garlic', 'veg', NULL, FALSE, NULL, TRUE),
    (212, 'Green Peas, Jeera Butter Fry', 'green peas, jeera butter fry', 'veg', NULL, NULL, FALSE, TRUE),
    (213, 'Garlic Fry', 'garlic fry', 'veg', NULL, FALSE, NULL, TRUE),
    (214, 'Finger Chips', 'finger chips', 'veg', NULL, NULL, NULL, TRUE),
    (215, 'Bisleri Packaged Water', 'bisleri packaged water', 'veg', NULL, NULL, TRUE, TRUE),
    (216, 'Soft Drinks', 'soft drinks', 'veg', NULL, NULL, TRUE, TRUE)
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
VALUES (400603001001, 400603001, 'A La Carte', 'a_la_carte', 1);
-- board name is a structural label (the JSON names no board); the JSON describes one overall menu
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence, is_active)
VALUES
    -- pages[0].sections[0] (Maitri1.jpg, column 1)
    (400603001001, 400603001, 'FRESH SOUPS', 1, TRUE),
    -- pages[0].sections[1] (Maitri1.jpg, column 1)
    (400603001002, 400603001, 'SEA FOOD IN GRAVY', 2, TRUE),
    -- pages[0].sections[2] (Maitri1.jpg, column 1)
    (400603001003, 400603001, 'CHICKEN IN GRAVY', 3, TRUE),
    -- pages[0].sections[3] (Maitri1.jpg, column 2)
    (400603001004, 400603001, 'MUTTON IN GRAVY', 4, TRUE),
    -- pages[0].sections[4] (Maitri1.jpg, column 2)
    (400603001005, 400603001, 'VEGETABLES IN GRAVY', 5, TRUE),
    -- pages[0].sections[5] (Maitri1.jpg, column 2)
    (400603001006, 400603001, 'KHICHDI', 6, TRUE),
    -- pages[0].sections[6] (Maitri1.jpg, column 2)
    (400603001007, 400603001, 'BIRYANI', 7, TRUE),
    -- pages[0].sections[7] (Maitri1.jpg, column 2)
    (400603001008, 400603001, 'PULAV', 8, TRUE),
    -- pages[0].sections[8] (Maitri1.jpg, column 2)
    (400603001009, 400603001, 'RICE INDIAN', 9, TRUE),
    -- pages[0].sections[9] (Maitri1.jpg, column 2)
    (400603001010, 400603001, 'INDIAN DAL', 10, TRUE),
    -- pages[0].sections[10] (Maitri1.jpg, column 2)
    (400603001011, 400603001, 'INDIAN BREAD', 11, TRUE),
    -- pages[0].sections[11] (Maitri1.jpg, column 3)
    (400603001012, 400603001, 'FRIED RICE', 12, TRUE),
    -- pages[0].sections[12] (Maitri1.jpg, column 3)
    (400603001013, 400603001, 'COMBINATION RICE', 13, TRUE),
    -- pages[0].sections[13] (Maitri1.jpg, column 3)
    (400603001014, 400603001, 'NOODLES', 14, TRUE),
    -- pages[0].sections[14] (Maitri1.jpg, column 4)
    (400603001015, 400603001, 'SALADS & RAITA', 15, TRUE),
    -- pages[1].sections[0] (Maitri2.jpg, column 1)
    (400603001016, 400603001, 'SEA FOOD', 16, TRUE),
    -- pages[1].sections[1] (Maitri2.jpg, column 1)
    (400603001017, 400603001, 'CHICKEN', 17, TRUE),
    -- pages[1].sections[2] (Maitri2.jpg, column 1)
    (400603001018, 400603001, 'KEBAB & TANDOOR', 18, TRUE),
    -- pages[1].sections[3] (Maitri2.jpg, column 1)
    (400603001019, 400603001, 'MUTTON', 19, TRUE),
    -- pages[1].sections[4] (Maitri2.jpg, column 1)
    (400603001020, 400603001, 'EGG', 20, TRUE),
    -- pages[1].sections[5] (Maitri2.jpg, column 2)
    (400603001021, 400603001, 'PANEER', 21, TRUE),
    -- pages[1].sections[6] (Maitri2.jpg, column 2)
    (400603001022, 400603001, 'VEGETABLES', 22, TRUE),
    -- pages[1].sections[7] (Maitri2.jpg, column 2)
    (400603001023, 400603001, 'SPRING ROLL', 23, TRUE),
    -- pages[1].sections[8] (Maitri2.jpg, column 3)
    (400603001024, 400603001, 'CHAKNA', 24, TRUE),
    -- pages[1].sections[9] (Maitri2.jpg, column 3)
    (400603001025, 400603001, 'BEVERAGES', 25, TRUE);

-- ----------------------------------------------------------------------------
-- 6. MENU ITEMS, VARIANTS, PRICES (one block per JSON section)
-- ----------------------------------------------------------------------------

-- [1/25] FRESH SOUPS  |  JSON: pages[0].sections[0]  (Maitri1.jpg, column 1; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Shorba
    (400603001001, 400603001001, 'Chi. Shorba', 'chi. shorba', NULL, 'FRESH SOUPS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. shorba'),
    -- items[1] Chi. Manchow Soup
    (400603001002, 400603001001, 'Chi. Manchow Soup', 'chi. manchow soup', NULL, 'FRESH SOUPS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. manchow soup'),
    -- items[2] Sweet Corn Chi. Soup
    (400603001003, 400603001001, 'Sweet Corn Chi. Soup', 'sweet corn chi. soup', NULL, 'FRESH SOUPS', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'sweet corn chi. soup'),
    -- items[3] Palak Shorba
    (400603001004, 400603001001, 'Palak Shorba', 'palak shorba', NULL, 'FRESH SOUPS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'palak shorba'),
    -- items[4] Sweet Corn Veg. Soup
    (400603001005, 400603001001, 'Sweet Corn Veg. Soup', 'sweet corn veg. soup', NULL, 'FRESH SOUPS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sweet corn veg. soup'),
    -- items[5] Tomato Shorba
    (400603001006, 400603001001, 'Tomato Shorba', 'tomato shorba', NULL, 'FRESH SOUPS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tomato shorba'),
    -- items[6] Veg. Manchow Soup
    (400603001007, 400603001001, 'Veg. Manchow Soup', 'veg. manchow soup', NULL, 'FRESH SOUPS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. manchow soup')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001001, 400603001001, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001002, 400603001002, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001003, 400603001003, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001004, 400603001004, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001005, 400603001005, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001006, 400603001006, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001007, 400603001007, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001001, 400603001001, 147.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001002, 400603001002, 147.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001003, 400603001003, 147.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001004, 400603001004, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001005, 400603001005, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001006, 400603001006, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001007, 400603001007, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [2/25] SEA FOOD IN GRAVY  |  JSON: pages[0].sections[1]  (Maitri1.jpg, column 1; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paplet Masala
    (400603001008, 400603001002, 'Paplet Masala', 'paplet masala', NULL, 'SEA FOOD IN GRAVY', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'paplet masala'),
    -- items[1] Surmai Masala
    (400603001009, 400603001002, 'Surmai Masala', 'surmai masala', NULL, 'SEA FOOD IN GRAVY', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'surmai masala'),
    -- items[2] Prawns Masala
    (400603001010, 400603001002, 'Prawns Masala', 'prawns masala', NULL, 'SEA FOOD IN GRAVY', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns masala'),
    -- items[3] Bangda Masala
    (400603001011, 400603001002, 'Bangda Masala', 'bangda masala', NULL, 'SEA FOOD IN GRAVY', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'bangda masala'),
    -- items[4] Rawas Masala
    (400603001012, 400603001002, 'Rawas Masala', 'rawas masala', NULL, 'SEA FOOD IN GRAVY', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas masala')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001008, 400603001008, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001009, 400603001009, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001010, 400603001010, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001011, 400603001011, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001012, 400603001012, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001008, 400603001008, 451.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001009, 400603001009, 345.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001010, 400603001010, 325.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001011, 400603001011, 241.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001012, 400603001012, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [3/25] CHICKEN IN GRAVY  |  JSON: pages[0].sections[2]  (Maitri1.jpg, column 1; 16 JSON line(s) -> 16 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Aftab
    (400603001013, 400603001003, 'Chi. Aftab', 'chi. aftab', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. aftab'),
    -- items[1] Chi. Afghani
    (400603001014, 400603001003, 'Chi. Afghani', 'chi. afghani', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. afghani'),
    -- items[2] Chi. Handi
    (400603001015, 400603001003, 'Chi. Handi', 'chi. handi', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. handi'),
    -- items[3] Chi. Kolhapuri
    (400603001016, 400603001003, 'Chi. Kolhapuri', 'chi. kolhapuri', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. kolhapuri'),
    -- items[4] Chi. Maharaja
    (400603001017, 400603001003, 'Chi. Maharaja', 'chi. maharaja', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. maharaja'),
    -- items[5] Chi. Makhanwala
    (400603001018, 400603001003, 'Chi. Makhanwala', 'chi. makhanwala', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. makhanwala'),
    -- items[6] Chi. Masala
    (400603001019, 400603001003, 'Chi. Masala', 'chi. masala', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. masala'),
    -- items[7] Chi. Moghlai
    (400603001020, 400603001003, 'Chi. Moghlai', 'chi. moghlai', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. moghlai'),
    -- items[8] Chi. Kangda
    (400603001021, 400603001003, 'Chi. Kangda', 'chi. kangda', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. kangda'),
    -- items[9] Chi. Hyderabadi
    (400603001022, 400603001003, 'Chi. Hyderabadi', 'chi. hyderabadi', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. hyderabadi'),
    -- items[10] Murg Masalam
    (400603001023, 400603001003, 'Murg Masalam', 'murg masalam', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'murg masalam'),
    -- items[11] Liver Masala
    (400603001024, 400603001003, 'Liver Masala', 'liver masala', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'liver masala'),
    -- items[12] Chi. Tikka Masala
    (400603001025, 400603001003, 'Chi. Tikka Masala', 'chi. tikka masala', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. tikka masala'),
    -- items[13] Chicken Sukka (S.I.)
    (400603001026, 400603001003, 'Chicken Sukka (S.I.)', 'chicken sukka (s.i.)', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken sukka (s.i.)'),
    -- items[14] Chicken Tawa
    (400603001027, 400603001003, 'Chicken Tawa', 'chicken tawa', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken tawa'),
    -- items[15] Chicken Bhoona Masala
    (400603001028, 400603001003, 'Chicken Bhoona Masala', 'chicken bhoona masala', NULL, 'CHICKEN IN GRAVY', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chicken bhoona masala')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001013, 400603001013, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001014, 400603001014, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001015, 400603001015, 'Half', 'H', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400603001016, 400603001015, 'Full', 'F', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400603001017, 400603001016, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001018, 400603001017, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001019, 400603001018, 'Half', 'H', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400603001020, 400603001018, 'Full', 'F', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400603001021, 400603001019, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001022, 400603001020, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001023, 400603001021, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001024, 400603001022, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001025, 400603001023, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001026, 400603001024, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001027, 400603001025, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001028, 400603001026, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001029, 400603001027, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001030, 400603001028, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001013, 400603001013, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001014, 400603001014, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001015, 400603001015, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001016, 400603001016, 419.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001017, 400603001017, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001018, 400603001018, 366.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001019, 400603001019, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001020, 400603001020, 461.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001021, 400603001021, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001022, 400603001022, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001023, 400603001023, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001024, 400603001024, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001025, 400603001025, 785.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001026, 400603001026, 252.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001027, 400603001027, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001028, 400603001028, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001029, 400603001029, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001030, 400603001030, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [4/25] MUTTON IN GRAVY  |  JSON: pages[0].sections[3]  (Maitri1.jpg, column 2; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Mutton Rogan Josh
    (400603001029, 400603001004, 'Mutton Rogan Josh', 'mutton rogan josh', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton rogan josh'),
    -- items[1] Mutton Handi
    (400603001030, 400603001004, 'Mutton Handi', 'mutton handi', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton handi'),
    -- items[2] Mutton Kadai
    (400603001031, 400603001004, 'Mutton Kadai', 'mutton kadai', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton kadai'),
    -- items[3] Mutton Kheema
    (400603001032, 400603001004, 'Mutton Kheema', 'mutton kheema', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton kheema'),
    -- items[4] Mutton Kolhapuri
    (400603001033, 400603001004, 'Mutton Kolhapuri', 'mutton kolhapuri', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton kolhapuri'),
    -- items[5] Mutton Masala
    (400603001034, 400603001004, 'Mutton Masala', 'mutton masala', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton masala'),
    -- items[6] Mutton Sukka (S.I.)
    (400603001035, 400603001004, 'Mutton Sukka (S.I.)', 'mutton sukka (s.i.)', NULL, 'MUTTON IN GRAVY', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton sukka (s.i.)')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001031, 400603001029, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001032, 400603001030, 'Half', 'H', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400603001033, 400603001030, 'Full', 'F', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400603001034, 400603001031, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001035, 400603001032, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001036, 400603001033, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001037, 400603001034, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001038, 400603001035, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001031, 400603001031, 451.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001032, 400603001032, 440.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001033, 400603001033, 545.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001034, 400603001034, 440.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001035, 400603001035, 472.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001036, 400603001036, 440.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001037, 400603001037, 440.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001038, 400603001038, 472.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [5/25] VEGETABLES IN GRAVY  |  JSON: pages[0].sections[4]  (Maitri1.jpg, column 2; 26 JSON line(s) -> 26 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paneer Kadai
    (400603001036, 400603001005, 'Paneer Kadai', 'paneer kadai', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer kadai'),
    -- items[1] Paneer Handi
    (400603001037, 400603001005, 'Paneer Handi', 'paneer handi', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer handi'),
    -- items[2] Paneer Kolhapuri
    (400603001038, 400603001005, 'Paneer Kolhapuri', 'paneer kolhapuri', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer kolhapuri'),
    -- items[3] Veg. Kurma
    (400603001039, 400603001005, 'Veg. Kurma', 'veg. kurma', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. kurma'),
    -- items[4] Veg. Maharaja
    (400603001040, 400603001005, 'Veg. Maharaja', 'veg. maharaja', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. maharaja'),
    -- items[5] Alu Gobi Masala
    (400603001041, 400603001005, 'Alu Gobi Masala', 'alu gobi masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'alu gobi masala'),
    -- items[6] Methi Malai Mutter
    (400603001042, 400603001005, 'Methi Malai Mutter', 'methi malai mutter', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'methi malai mutter'),
    -- items[7] Mix Vegetable
    (400603001043, 400603001005, 'Mix Vegetable', 'mix vegetable', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mix vegetable'),
    -- items[8] Navratna Kurma
    (400603001044, 400603001005, 'Navratna Kurma', 'navratna kurma', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'navratna kurma'),
    -- items[9] Veg. Aftab
    (400603001045, 400603001005, 'Veg. Aftab', 'veg. aftab', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. aftab'),
    -- items[10] Veg. Handi
    (400603001046, 400603001005, 'Veg. Handi', 'veg. handi', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. handi'),
    -- items[11] Veg. Hyderabadi
    (400603001047, 400603001005, 'Veg. Hyderabadi', 'veg. hyderabadi', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. hyderabadi'),
    -- items[12] Veg. Kadai
    (400603001048, 400603001005, 'Veg. Kadai', 'veg. kadai', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. kadai'),
    -- items[13] Veg. Kolhapuri
    (400603001049, 400603001005, 'Veg. Kolhapuri', 'veg. kolhapuri', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. kolhapuri'),
    -- items[14] Veg. Makhanwala
    (400603001050, 400603001005, 'Veg. Makhanwala', 'veg. makhanwala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg. makhanwala'),
    -- items[15] Mushroom Masala
    (400603001051, 400603001005, 'Mushroom Masala', 'mushroom masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom masala'),
    -- items[16] Green Peas Masala
    (400603001052, 400603001005, 'Green Peas Masala', 'green peas masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'green peas masala'),
    -- items[17] Channa Masala
    (400603001053, 400603001005, 'Channa Masala', 'channa masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'channa masala'),
    -- items[18] Paneer Palak
    (400603001054, 400603001005, 'Paneer Palak', 'paneer palak', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer palak'),
    -- items[19] Paneer Butter Masala
    (400603001055, 400603001005, 'Paneer Butter Masala', 'paneer butter masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer butter masala'),
    -- items[20] Babycorn Mushroom Masala
    (400603001056, 400603001005, 'Babycorn Mushroom Masala', 'babycorn mushroom masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'babycorn mushroom masala'),
    -- items[21] Paneer Makhanwala
    (400603001057, 400603001005, 'Paneer Makhanwala', 'paneer makhanwala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer makhanwala'),
    -- items[22] Paneer Mushroom Masala
    (400603001058, 400603001005, 'Paneer Mushroom Masala', 'paneer mushroom masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'paneer mushroom masala'),
    -- items[23] Paneer Mutter
    (400603001059, 400603001005, 'Paneer Mutter', 'paneer mutter', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer mutter'),
    -- items[24] Paneer Tikka Masala
    (400603001060, 400603001005, 'Paneer Tikka Masala', 'paneer tikka masala', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka masala'),
    -- items[25] Veg. Afgani Handi
    (400603001061, 400603001005, 'Veg. Afgani Handi', 'veg. afgani handi', NULL, 'VEGETABLES IN GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. afgani handi')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001039, 400603001036, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001040, 400603001037, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001041, 400603001038, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001042, 400603001039, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001043, 400603001040, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001044, 400603001041, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001045, 400603001042, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001046, 400603001043, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001047, 400603001044, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001048, 400603001045, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001049, 400603001046, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001050, 400603001047, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001051, 400603001048, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001052, 400603001049, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001053, 400603001050, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001054, 400603001051, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001055, 400603001052, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001056, 400603001053, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001057, 400603001054, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001058, 400603001055, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001059, 400603001056, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001060, 400603001057, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001061, 400603001058, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001062, 400603001059, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001063, 400603001060, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001064, 400603001061, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001039, 400603001039, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001040, 400603001040, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001041, 400603001041, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001042, 400603001042, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001043, 400603001043, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001044, 400603001044, 252.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001045, 400603001045, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001046, 400603001046, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001047, 400603001047, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001048, 400603001048, 283.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001049, 400603001049, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001050, 400603001050, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001051, 400603001051, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001052, 400603001052, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001053, 400603001053, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001054, 400603001054, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001055, 400603001055, 209.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001056, 400603001056, 210.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001057, 400603001057, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001058, 400603001058, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001059, 400603001059, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001060, 400603001060, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001061, 400603001061, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001062, 400603001062, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001063, 400603001063, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001064, 400603001064, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [6/25] KHICHDI  |  JSON: pages[0].sections[5]  (Maitri1.jpg, column 2; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Dal Khichdi
    (400603001062, 400603001006, 'Dal Khichdi', 'dal khichdi', NULL, 'KHICHDI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal khichdi'),
    -- items[1] Dal Khichdi Tadka
    (400603001063, 400603001006, 'Dal Khichdi Tadka', 'dal khichdi tadka', NULL, 'KHICHDI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal khichdi tadka'),
    -- items[2] Palak Khichdi
    (400603001064, 400603001006, 'Palak Khichdi', 'palak khichdi', NULL, 'KHICHDI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'palak khichdi'),
    -- items[3] Chi. Khichdi
    (400603001065, 400603001006, 'Chi. Khichdi', 'chi. khichdi', NULL, 'KHICHDI', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. khichdi')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001065, 400603001062, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001066, 400603001063, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001067, 400603001064, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001068, 400603001065, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001065, 400603001065, 231.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001066, 400603001066, 231.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001067, 400603001067, 252.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001068, 400603001068, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [7/25] BIRYANI  |  JSON: pages[0].sections[6]  (Maitri1.jpg, column 2; 6 JSON line(s) -> 6 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Biryani
    (400603001066, 400603001007, 'Chi. Biryani', 'chi. biryani', NULL, 'BIRYANI', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. biryani'),
    -- items[1] Egg. Biryani
    (400603001067, 400603001007, 'Egg. Biryani', 'egg. biryani', NULL, 'BIRYANI', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg. biryani'),
    -- items[2] Mutton Biryani
    (400603001068, 400603001007, 'Mutton Biryani', 'mutton biryani', NULL, 'BIRYANI', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton biryani'),
    -- items[3] Prawns Biryani
    (400603001069, 400603001007, 'Prawns Biryani', 'prawns biryani', NULL, 'BIRYANI', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns biryani'),
    -- items[4] Veg. Biryani
    (400603001070, 400603001007, 'Veg. Biryani', 'veg. biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. biryani'),
    -- items[5] Paneer Biryani
    (400603001071, 400603001007, 'Paneer Biryani', 'paneer biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer biryani')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001069, 400603001066, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001070, 400603001067, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001071, 400603001068, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001072, 400603001069, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001073, 400603001070, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001074, 400603001071, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001069, 400603001069, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001070, 400603001070, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001071, 400603001071, 398.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001072, 400603001072, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001073, 400603001073, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001074, 400603001074, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [8/25] PULAV  |  JSON: pages[0].sections[7]  (Maitri1.jpg, column 2; 3 JSON line(s) -> 3 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Tawa Pulav
    (400603001072, 400603001008, 'Tawa Pulav', 'tawa pulav', NULL, 'PULAV', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tawa pulav'),
    -- items[1] Veg. Pulav
    (400603001073, 400603001008, 'Veg. Pulav', 'veg. pulav', NULL, 'PULAV', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. pulav'),
    -- items[2] Green Peas Pulav
    (400603001074, 400603001008, 'Green Peas Pulav', 'green peas pulav', NULL, 'PULAV', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'green peas pulav')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001075, 400603001072, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001076, 400603001073, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001077, 400603001074, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001075, 400603001075, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001076, 400603001076, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001077, 400603001077, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [9/25] RICE INDIAN  |  JSON: pages[0].sections[8]  (Maitri1.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Jeera Rice
    (400603001075, 400603001009, 'Jeera Rice', 'jeera rice', NULL, 'RICE INDIAN', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'jeera rice'),
    -- items[1] Steamed Basmati Rice
    (400603001076, 400603001009, 'Steamed Basmati Rice', 'steamed basmati rice', NULL, 'RICE INDIAN', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'steamed basmati rice'),
    -- items[2] Plain Rice
    (400603001077, 400603001009, 'Plain Rice', 'plain rice', NULL, 'RICE INDIAN', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'plain rice'),
    -- items[3] Curd Rice Tadka
    (400603001078, 400603001009, 'Curd Rice Tadka', 'curd rice tadka', NULL, 'RICE INDIAN', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'curd rice tadka'),
    -- items[4] Biryani Rice
    (400603001079, 400603001009, 'Biryani Rice', 'biryani rice', NULL, 'RICE INDIAN', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'biryani rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001078, 400603001075, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001079, 400603001076, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001080, 400603001077, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001081, 400603001078, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001082, 400603001079, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001078, 400603001078, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001079, 400603001079, 146.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001080, 400603001080, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001081, 400603001081, 200.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001082, 400603001082, 146.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [10/25] INDIAN DAL  |  JSON: pages[0].sections[9]  (Maitri1.jpg, column 2; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Dal Fry
    (400603001080, 400603001010, 'Dal Fry', 'dal fry', NULL, 'INDIAN DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal fry'),
    -- items[1] Dal Tadka
    (400603001081, 400603001010, 'Dal Tadka', 'dal tadka', NULL, 'INDIAN DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal tadka'),
    -- items[2] Palak Dal
    (400603001082, 400603001010, 'Palak Dal', 'palak dal', NULL, 'INDIAN DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'palak dal'),
    -- items[3] Dal Kolhapuri
    (400603001083, 400603001010, 'Dal Kolhapuri', 'dal kolhapuri', NULL, 'INDIAN DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal kolhapuri')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001083, 400603001080, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001084, 400603001081, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001085, 400603001082, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001086, 400603001083, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001083, 400603001083, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001084, 400603001084, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001085, 400603001085, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001086, 400603001086, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [11/25] INDIAN BREAD  |  JSON: pages[0].sections[10]  (Maitri1.jpg, column 2; 11 JSON line(s) -> 11 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Neer Dosa
    (400603001084, 400603001011, 'Neer Dosa', 'neer dosa', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'neer dosa'),
    -- items[1] Roti (Plain / Butter)
    (400603001085, 400603001011, 'Roti (Plain / Butter)', 'roti (plain / butter)', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'roti (plain / butter)'),
    -- items[2] Naan (Plain / Butter)
    (400603001086, 400603001011, 'Naan (Plain / Butter)', 'naan (plain / butter)', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'naan (plain / butter)'),
    -- items[3] Paratha (Plain / Butter)
    (400603001087, 400603001011, 'Paratha (Plain / Butter)', 'paratha (plain / butter)', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paratha (plain / butter)'),
    -- items[4] Stuffed Paratha
    (400603001088, 400603001011, 'Stuffed Paratha', 'stuffed paratha', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'needs_review', 'stuffed paratha'),
    -- items[5] Garlic Butter Naan
    (400603001089, 400603001011, 'Garlic Butter Naan', 'garlic butter naan', NULL, 'INDIAN BREAD', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'garlic butter naan'),
    -- items[6] Methi Butter Paratha
    (400603001090, 400603001011, 'Methi Butter Paratha', 'methi butter paratha', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'methi butter paratha'),
    -- items[7] Alu Butter Paratha
    (400603001091, 400603001011, 'Alu Butter Paratha', 'alu butter paratha', NULL, 'INDIAN BREAD', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'alu butter paratha'),
    -- items[8] Cheese Paratha
    (400603001092, 400603001011, 'Cheese Paratha', 'cheese paratha', NULL, 'INDIAN BREAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese paratha'),
    -- items[9] Chi. Stuffed Paratha
    (400603001093, 400603001011, 'Chi. Stuffed Paratha', 'chi. stuffed paratha', NULL, 'INDIAN BREAD', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. stuffed paratha'),
    -- items[10] Cheese Garlic Naan
    (400603001094, 400603001011, 'Cheese Garlic Naan', 'cheese garlic naan', NULL, 'INDIAN BREAD', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'cheese garlic naan')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001087, 400603001084, '1 pc', NULL, 'per_piece', 1, 'pieces', 1, TRUE, TRUE),
    (400603001088, 400603001085, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001089, 400603001086, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001090, 400603001087, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001091, 400603001088, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001092, 400603001089, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001093, 400603001090, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001094, 400603001091, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001095, 400603001092, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001096, 400603001093, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001097, 400603001094, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001087, 400603001087, 10.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001088, 400603001088, 21.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'needs_review', 400603001),
    (400603001089, 400603001089, 42.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'needs_review', 400603001),
    (400603001090, 400603001090, 42.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'needs_review', 400603001),
    (400603001091, 400603001091, 157.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001092, 400603001092, 95.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001093, 400603001093, 63.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001094, 400603001094, 116.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001095, 400603001095, 116.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001096, 400603001096, 136.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001097, 400603001097, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [12/25] FRIED RICE  |  JSON: pages[0].sections[11]  (Maitri1.jpg, column 3; 6 JSON line(s) -> 6 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Fried Rice
    (400603001095, 400603001012, 'Chi. Fried Rice', 'chi. fried rice', NULL, 'FRIED RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. fried rice'),
    -- items[1] Mix Fried Rice
    (400603001096, 400603001012, 'Mix Fried Rice', 'mix fried rice', NULL, 'FRIED RICE', NULL, NULL, NULL, NULL, NULL, NULL, 'needs_review', 'mix fried rice'),
    -- items[2] Prawns Fried Rice
    (400603001097, 400603001012, 'Prawns Fried Rice', 'prawns fried rice', NULL, 'FRIED RICE', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns fried rice'),
    -- items[3] Egg. Fried Rice
    (400603001098, 400603001012, 'Egg. Fried Rice', 'egg. fried rice', NULL, 'FRIED RICE', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg. fried rice'),
    -- items[4] Veg. Fried Rice
    (400603001099, 400603001012, 'Veg. Fried Rice', 'veg. fried rice', NULL, 'FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. fried rice'),
    -- items[5] Jeera Fried Rice
    (400603001100, 400603001012, 'Jeera Fried Rice', 'jeera fried rice', NULL, 'FRIED RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'jeera fried rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001098, 400603001095, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001099, 400603001096, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001100, 400603001097, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001101, 400603001098, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001102, 400603001099, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001103, 400603001100, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001098, 400603001098, 284.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001099, 400603001099, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001100, 400603001100, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001101, 400603001101, 262.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001102, 400603001102, 273.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001103, 400603001103, 188.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [13/25] COMBINATION RICE  |  JSON: pages[0].sections[12]  (Maitri1.jpg, column 3; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Triple Sz. Fried Rice
    (400603001101, 400603001013, 'Chi. Triple Sz. Fried Rice', 'chi. triple sz. fried rice', NULL, 'COMBINATION RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. triple sz. fried rice'),
    -- items[1] Chi Manchurian Rice
    (400603001102, 400603001013, 'Chi Manchurian Rice', 'chi manchurian rice', NULL, 'COMBINATION RICE', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi manchurian rice'),
    -- items[2] Veg. Triple Sz. Fried Rice
    (400603001103, 400603001013, 'Veg. Triple Sz. Fried Rice', 'veg. triple sz. fried rice', NULL, 'COMBINATION RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. triple sz. fried rice'),
    -- items[3] Veg. Manchurian Rice
    (400603001104, 400603001013, 'Veg. Manchurian Rice', 'veg. manchurian rice', NULL, 'COMBINATION RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. manchurian rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001104, 400603001101, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001105, 400603001102, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001106, 400603001103, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001107, 400603001104, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001104, 400603001104, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001105, 400603001105, 334.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001106, 400603001106, 334.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001107, 400603001107, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [14/25] NOODLES  |  JSON: pages[0].sections[13]  (Maitri1.jpg, column 3; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Hakka Noodles
    (400603001105, 400603001014, 'Chi. Hakka Noodles', 'chi. hakka noodles', NULL, 'NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. hakka noodles'),
    -- items[1] Veg. Hakka Noodles
    (400603001106, 400603001014, 'Veg. Hakka Noodles', 'veg. hakka noodles', NULL, 'NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. hakka noodles'),
    -- items[2] Prawns Hakka Noodles
    (400603001107, 400603001014, 'Prawns Hakka Noodles', 'prawns hakka noodles', NULL, 'NOODLES', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns hakka noodles'),
    -- items[3] Veg. Triples Sz. Noodles
    (400603001108, 400603001014, 'Veg. Triples Sz. Noodles', 'veg. triples sz. noodles', NULL, 'NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. triples sz. noodles'),
    -- items[4] Chi. Triple Sz. Noodles
    (400603001109, 400603001014, 'Chi. Triple Sz. Noodles', 'chi. triple sz. noodles', NULL, 'NOODLES', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. triple sz. noodles')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001108, 400603001105, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001109, 400603001106, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001110, 400603001107, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001111, 400603001108, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001112, 400603001109, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001108, 400603001108, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001109, 400603001109, 273.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001110, 400603001110, 325.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001111, 400603001111, 345.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001112, 400603001112, 367.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [15/25] SALADS & RAITA  |  JSON: pages[0].sections[14]  (Maitri1.jpg, column 4; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Green Salad
    (400603001110, 400603001015, 'Green Salad', 'green salad', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'green salad'),
    -- items[1] Boondi Raita
    (400603001111, 400603001015, 'Boondi Raita', 'boondi raita', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'boondi raita'),
    -- items[2] Veg. Raita
    (400603001112, 400603001015, 'Veg. Raita', 'veg. raita', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg. raita'),
    -- items[3] Plain Curd
    (400603001113, 400603001015, 'Plain Curd', 'plain curd', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'plain curd'),
    -- items[4] Pineapple Raita
    (400603001114, 400603001015, 'Pineapple Raita', 'pineapple raita', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'pineapple raita'),
    -- items[5] Cheese Cherry Pineapple
    (400603001115, 400603001015, 'Cheese Cherry Pineapple', 'cheese cherry pineapple', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese cherry pineapple'),
    -- items[6] Tandoori Salad
    (400603001116, 400603001015, 'Tandoori Salad', 'tandoori salad', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tandoori salad')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001113, 400603001110, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001114, 400603001111, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001115, 400603001112, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001116, 400603001113, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001117, 400603001114, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001118, 400603001115, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001119, 400603001116, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001113, 400603001113, 63.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001114, 400603001114, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001115, 400603001115, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001116, 400603001116, 67.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001117, 400603001117, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001118, 400603001118, 86.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001119, 400603001119, 74.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [16/25] SEA FOOD  |  JSON: pages[1].sections[0]  (Maitri2.jpg, column 1; 26 JSON line(s) -> 26 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paplet Tawa Fry
    (400603001117, 400603001016, 'Paplet Tawa Fry', 'paplet tawa fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'paplet tawa fry'),
    -- items[1] Paplet Tandoori
    (400603001118, 400603001016, 'Paplet Tandoori', 'paplet tandoori', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'paplet tandoori'),
    -- items[2] Rawas Finger
    (400603001119, 400603001016, 'Rawas Finger', 'rawas finger', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas finger'),
    -- items[3] Rawas Chilly
    (400603001120, 400603001016, 'Rawas Chilly', 'rawas chilly', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas chilly'),
    -- items[4] Surmai Tawa Fry With Garlic
    (400603001121, 400603001016, 'Surmai Tawa Fry With Garlic', 'surmai tawa fry with garlic', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'surmai tawa fry with garlic'),
    -- items[5] Bangda Tawa Fry
    (400603001122, 400603001016, 'Bangda Tawa Fry', 'bangda tawa fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'bangda tawa fry'),
    -- items[6] Bangda Oil Fry
    (400603001123, 400603001016, 'Bangda Oil Fry', 'bangda oil fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'bangda oil fry'),
    -- items[7] Mandeli Rawa Fry
    (400603001124, 400603001016, 'Mandeli Rawa Fry', 'mandeli rawa fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'mandeli rawa fry'),
    -- items[8] Prawns Chilly
    (400603001125, 400603001016, 'Prawns Chilly', 'prawns chilly', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns chilly'),
    -- items[9] Prawns Koliwada
    (400603001126, 400603001016, 'Prawns Koliwada', 'prawns koliwada', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns koliwada'),
    -- items[10] Prawns Masala Dry
    (400603001127, 400603001016, 'Prawns Masala Dry', 'prawns masala dry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns masala dry'),
    -- items[11] Prawns Manchurian
    (400603001128, 400603001016, 'Prawns Manchurian', 'prawns manchurian', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns manchurian'),
    -- items[12] Bombil Fry
    (400603001129, 400603001016, 'Bombil Fry', 'bombil fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'bombil fry'),
    -- items[13] Bombil Tawa Fry
    (400603001130, 400603001016, 'Bombil Tawa Fry', 'bombil tawa fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'bombil tawa fry'),
    -- items[14] Rawas Tawa
    (400603001131, 400603001016, 'Rawas Tawa', 'rawas tawa', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas tawa'),
    -- items[15] Rawas Schezwan
    (400603001132, 400603001016, 'Rawas Schezwan', 'rawas schezwan', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas schezwan'),
    -- items[16] Rawas Tikka
    (400603001133, 400603001016, 'Rawas Tikka', 'rawas tikka', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas tikka'),
    -- items[17] Surmai Oil Fry
    (400603001134, 400603001016, 'Surmai Oil Fry', 'surmai oil fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'surmai oil fry'),
    -- items[18] Surmai Rawa Fry
    (400603001135, 400603001016, 'Surmai Rawa Fry', 'surmai rawa fry', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'surmai rawa fry'),
    -- items[19] Prawns 65
    (400603001136, 400603001016, 'Prawns 65', 'prawns 65', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns 65'),
    -- items[20] Prawns Butter Garlic
    (400603001137, 400603001016, 'Prawns Butter Garlic', 'prawns butter garlic', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns butter garlic'),
    -- items[21] Prawns Garlic Sauce
    (400603001138, 400603001016, 'Prawns Garlic Sauce', 'prawns garlic sauce', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns garlic sauce'),
    -- items[22] Prawns Schezwan
    (400603001139, 400603001016, 'Prawns Schezwan', 'prawns schezwan', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns schezwan'),
    -- items[23] Prawns Salt Pepper
    (400603001140, 400603001016, 'Prawns Salt Pepper', 'prawns salt pepper', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'prawns salt pepper'),
    -- items[24] Rawas Hariyali Tikka
    (400603001141, 400603001016, 'Rawas Hariyali Tikka', 'rawas hariyali tikka', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas hariyali tikka'),
    -- items[25] Rawas Nizamuddin Tikka
    (400603001142, 400603001016, 'Rawas Nizamuddin Tikka', 'rawas nizamuddin tikka', NULL, 'SEA FOOD', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', 'rawas nizamuddin tikka')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001120, 400603001117, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001121, 400603001118, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001122, 400603001119, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001123, 400603001120, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001124, 400603001121, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001125, 400603001122, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001126, 400603001123, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001127, 400603001124, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001128, 400603001125, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001129, 400603001126, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001130, 400603001127, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001131, 400603001128, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001132, 400603001129, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001133, 400603001130, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001134, 400603001131, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001135, 400603001132, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001136, 400603001133, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001137, 400603001134, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001138, 400603001135, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001139, 400603001136, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001140, 400603001137, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001141, 400603001138, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001142, 400603001139, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001143, 400603001140, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001144, 400603001141, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001145, 400603001142, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001120, 400603001120, 451.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001121, 400603001121, 451.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001122, 400603001122, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001123, 400603001123, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001124, 400603001124, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001125, 400603001125, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001126, 400603001126, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001127, 400603001127, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001128, 400603001128, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001129, 400603001129, 325.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001130, 400603001130, 325.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001131, 400603001131, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001132, 400603001132, 167.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001133, 400603001133, 167.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001134, 400603001134, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001135, 400603001135, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001136, 400603001136, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001137, 400603001137, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001138, 400603001138, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001139, 400603001139, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001140, 400603001140, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001141, 400603001141, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001142, 400603001142, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001143, 400603001143, 336.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001144, 400603001144, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001145, 400603001145, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [17/25] CHICKEN  |  JSON: pages[1].sections[1]  (Maitri2.jpg, column 1; 14 JSON line(s) -> 14 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. 65
    (400603001143, 400603001017, 'Chi. 65', 'chi. 65', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. 65'),
    -- items[1] Chi. Chatpata
    (400603001144, 400603001017, 'Chi. Chatpata', 'chi. chatpata', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. chatpata'),
    -- items[2] Chi. Mangolian
    (400603001145, 400603001017, 'Chi. Mangolian', 'chi. mangolian', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. mangolian'),
    -- items[3] Chi. Malesian
    (400603001146, 400603001017, 'Chi. Malesian', 'chi. malesian', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. malesian'),
    -- items[4] Chi. Chilly
    (400603001147, 400603001017, 'Chi. Chilly', 'chi. chilly', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. chilly'),
    -- items[5] Chi. Crunchy
    (400603001148, 400603001017, 'Chi. Crunchy', 'chi. crunchy', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. crunchy'),
    -- items[6] Chi. Garlic
    (400603001149, 400603001017, 'Chi. Garlic', 'chi. garlic', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. garlic'),
    -- items[7] Chi. Manchurian
    (400603001150, 400603001017, 'Chi. Manchurian', 'chi. manchurian', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. manchurian'),
    -- items[8] Chi. Crispy
    (400603001151, 400603001017, 'Chi. Crispy', 'chi. crispy', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. crispy'),
    -- items[9] Chi. Stic
    (400603001152, 400603001017, 'Chi. Stic', 'chi. stic', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. stic'),
    -- items[10] Chi. Schezwan
    (400603001153, 400603001017, 'Chi. Schezwan', 'chi. schezwan', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. schezwan'),
    -- items[11] Chi. Lollypop Oil Fry
    (400603001154, 400603001017, 'Chi. Lollypop Oil Fry', 'chi. lollypop oil fry', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. lollypop oil fry'),
    -- items[12] Chi. Liver & Potat Oil Fry
    (400603001155, 400603001017, 'Chi. Liver & Potat Oil Fry', 'chi. liver & potat oil fry', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. liver & potat oil fry'),
    -- items[13] Liver Burji
    (400603001156, 400603001017, 'Liver Burji', 'liver burji', NULL, 'CHICKEN', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'liver burji')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001146, 400603001143, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001147, 400603001144, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001148, 400603001145, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001149, 400603001146, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001150, 400603001147, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001151, 400603001148, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001152, 400603001149, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001153, 400603001150, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001154, 400603001151, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001155, 400603001152, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001156, 400603001153, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001157, 400603001154, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001158, 400603001155, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001159, 400603001156, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001146, 400603001146, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001147, 400603001147, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001148, 400603001148, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001149, 400603001149, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001150, 400603001150, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001151, 400603001151, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001152, 400603001152, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001153, 400603001153, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001154, 400603001154, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001155, 400603001155, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001156, 400603001156, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001157, 400603001157, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001158, 400603001158, 136.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001159, 400603001159, 252.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [18/25] KEBAB & TANDOOR  |  JSON: pages[1].sections[2]  (Maitri2.jpg, column 1; 14 JSON line(s) -> 14 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chi. Reshmi Kebab
    (400603001157, 400603001018, 'Chi. Reshmi Kebab', 'chi. reshmi kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. reshmi kebab'),
    -- items[1] Chi. Malwani Kebab
    (400603001158, 400603001018, 'Chi. Malwani Kebab', 'chi. malwani kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. malwani kebab'),
    -- items[2] Chi. Jabuli Kebab
    (400603001159, 400603001018, 'Chi. Jabuli Kebab', 'chi. jabuli kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. jabuli kebab'),
    -- items[3] Chi. Banjara Kebab
    (400603001160, 400603001018, 'Chi. Banjara Kebab', 'chi. banjara kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. banjara kebab'),
    -- items[4] Chi. Pahadi Kebab
    (400603001161, 400603001018, 'Chi. Pahadi Kebab', 'chi. pahadi kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. pahadi kebab'),
    -- items[5] Chi. Pudina Kebab
    (400603001162, 400603001018, 'Chi. Pudina Kebab', 'chi. pudina kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. pudina kebab'),
    -- items[6] Chi. Seekh Kebab
    (400603001163, 400603001018, 'Chi. Seekh Kebab', 'chi. seekh kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. seekh kebab'),
    -- items[7] Chi. Tandoori
    (400603001164, 400603001018, 'Chi. Tandoori', 'chi. tandoori', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. tandoori'),
    -- items[8] Chi. Tikka
    (400603001165, 400603001018, 'Chi. Tikka', 'chi. tikka', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. tikka'),
    -- items[9] Chi. Tandoori Karkhana
    (400603001166, 400603001018, 'Chi. Tandoori Karkhana', 'chi. tandoori karkhana', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. tandoori karkhana'),
    -- items[10] Chi. Tangdi Kebab
    (400603001167, 400603001018, 'Chi. Tangdi Kebab', 'chi. tangdi kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. tangdi kebab'),
    -- items[11] Chi. Lollypop Tandoori
    (400603001168, 400603001018, 'Chi. Lollypop Tandoori', 'chi. lollypop tandoori', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. lollypop tandoori'),
    -- items[12] Liver Tandoori
    (400603001169, 400603001018, 'Liver Tandoori', 'liver tandoori', NULL, 'KEBAB & TANDOOR', 'non_veg', NULL, FALSE, FALSE, NULL, NULL, 'needs_review', 'liver tandoori'),
    -- items[13] Chi. Malai Kebab
    (400603001170, 400603001018, 'Chi. Malai Kebab', 'chi. malai kebab', NULL, 'KEBAB & TANDOOR', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', 'chi. malai kebab')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001160, 400603001157, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001161, 400603001158, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001162, 400603001159, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001163, 400603001160, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001164, 400603001161, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001165, 400603001162, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001166, 400603001163, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001167, 400603001164, 'Half', 'H', 'fixed', NULL, NULL, 1, FALSE, TRUE),
    (400603001168, 400603001164, 'Full', 'F', 'fixed', NULL, NULL, 2, TRUE, TRUE),
    (400603001169, 400603001165, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001170, 400603001166, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001171, 400603001167, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001172, 400603001168, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001173, 400603001169, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001174, 400603001170, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001160, 400603001160, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001161, 400603001161, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001162, 400603001162, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001163, 400603001163, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001164, 400603001164, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001165, 400603001165, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001166, 400603001166, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001167, 400603001167, 200.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001168, 400603001168, 387.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001169, 400603001169, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001170, 400603001170, 755.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001171, 400603001171, 157.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001172, 400603001172, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001173, 400603001173, 210.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001174, 400603001174, 356.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [19/25] MUTTON  |  JSON: pages[1].sections[3]  (Maitri2.jpg, column 1; 2 JSON line(s) -> 2 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Mutton Seekh Kebab
    (400603001171, 400603001019, 'Mutton Seekh Kebab', 'mutton seekh kebab', NULL, 'MUTTON', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton seekh kebab'),
    -- items[1] Mutton Kheema
    (400603001172, 400603001019, 'Mutton Kheema', 'mutton kheema', NULL, 'MUTTON', 'non_veg', 'MUTTON', FALSE, FALSE, NULL, NULL, 'unverified', 'mutton kheema')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001175, 400603001171, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001176, 400603001172, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001175, 400603001175, 429.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001176, 400603001176, 472.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [20/25] EGG  |  JSON: pages[1].sections[4]  (Maitri2.jpg, column 1; 8 JSON line(s) -> 8 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Egg Boiled
    (400603001173, 400603001020, 'Egg Boiled', 'egg boiled', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg boiled'),
    -- items[1] Egg Half Fry
    (400603001174, 400603001020, 'Egg Half Fry', 'egg half fry', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg half fry'),
    -- items[2] Boiled Egg Burji
    (400603001175, 400603001020, 'Boiled Egg Burji', 'boiled egg burji', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'boiled egg burji'),
    -- items[3] Egg Oil Fry
    (400603001176, 400603001020, 'Egg Oil Fry', 'egg oil fry', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg oil fry'),
    -- items[4] Egg Omlet
    (400603001177, 400603001020, 'Egg Omlet', 'egg omlet', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg omlet'),
    -- items[5] Egg Pakoda
    (400603001178, 400603001020, 'Egg Pakoda', 'egg pakoda', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg pakoda'),
    -- items[6] Omelet Cheese
    (400603001179, 400603001020, 'Omelet Cheese', 'omelet cheese', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'omelet cheese'),
    -- items[7] Egg. Burji
    (400603001180, 400603001020, 'Egg. Burji', 'egg. burji', NULL, 'EGG', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', 'egg. burji')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001177, 400603001173, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001178, 400603001174, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001179, 400603001175, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001180, 400603001176, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001181, 400603001177, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001182, 400603001178, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001183, 400603001179, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001184, 400603001180, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001177, 400603001177, 63.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001178, 400603001178, 63.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001179, 400603001179, 116.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001180, 400603001180, 74.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001181, 400603001181, 95.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001182, 400603001182, 74.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001183, 400603001183, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001184, 400603001184, 116.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [21/25] PANEER  |  JSON: pages[1].sections[5]  (Maitri2.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paneer Chilly
    (400603001181, 400603001021, 'Paneer Chilly', 'paneer chilly', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilly'),
    -- items[1] Paneer Manchurian
    (400603001182, 400603001021, 'Paneer Manchurian', 'paneer manchurian', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer manchurian'),
    -- items[2] Paneer Stic
    (400603001183, 400603001021, 'Paneer Stic', 'paneer stic', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer stic'),
    -- items[3] Paneer Schezwan
    (400603001184, 400603001021, 'Paneer Schezwan', 'paneer schezwan', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer schezwan'),
    -- items[4] Paneer Tikka
    (400603001185, 400603001021, 'Paneer Tikka', 'paneer tikka', NULL, 'PANEER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001185, 400603001181, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001186, 400603001182, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001187, 400603001183, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001188, 400603001184, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001189, 400603001185, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001185, 400603001185, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001186, 400603001186, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001187, 400603001187, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001188, 400603001188, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001189, 400603001189, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [22/25] VEGETABLES  |  JSON: pages[1].sections[6]  (Maitri2.jpg, column 2; 25 JSON line(s) -> 25 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Stuffed Mushroom Tikka
    (400603001186, 400603001022, 'Stuffed Mushroom Tikka', 'stuffed mushroom tikka', NULL, 'VEGETABLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'stuffed mushroom tikka'),
    -- items[1] Veg. Moti Seekh Kebab
    (400603001187, 400603001022, 'Veg. Moti Seekh Kebab', 'veg. moti seekh kebab', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. moti seekh kebab'),
    -- items[2] Alu Tandoori
    (400603001188, 400603001022, 'Alu Tandoori', 'alu tandoori', NULL, 'VEGETABLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'alu tandoori'),
    -- items[3] Gobi Tandoori
    (400603001189, 400603001022, 'Gobi Tandoori', 'gobi tandoori', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'gobi tandoori'),
    -- items[4] Boiled Makai With Butter
    (400603001190, 400603001022, 'Boiled Makai With Butter', 'boiled makai with butter', NULL, 'VEGETABLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'boiled makai with butter'),
    -- items[5] Boiled Veg. With Butter
    (400603001191, 400603001022, 'Boiled Veg. With Butter', 'boiled veg. with butter', NULL, 'VEGETABLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'boiled veg. with butter'),
    -- items[6] Hara Bhara Kebab
    (400603001192, 400603001022, 'Hara Bhara Kebab', 'hara bhara kebab', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'hara bhara kebab'),
    -- items[7] Veg. Chatpata
    (400603001193, 400603001022, 'Veg. Chatpata', 'veg. chatpata', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. chatpata'),
    -- items[8] Veg. Pakoda
    (400603001194, 400603001022, 'Veg. Pakoda', 'veg. pakoda', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. pakoda'),
    -- items[9] Babycorn Chilly
    (400603001195, 400603001022, 'Babycorn Chilly', 'babycorn chilly', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'babycorn chilly'),
    -- items[10] Gobi Manchurian
    (400603001196, 400603001022, 'Gobi Manchurian', 'gobi manchurian', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'gobi manchurian'),
    -- items[11] Makai Tawan
    (400603001197, 400603001022, 'Makai Tawan', 'makai tawan', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'makai tawan'),
    -- items[12] Veg. 65
    (400603001198, 400603001022, 'Veg. 65', 'veg. 65', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. 65'),
    -- items[13] Veg. Chilly
    (400603001199, 400603001022, 'Veg. Chilly', 'veg. chilly', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. chilly'),
    -- items[14] Veg. Crispy
    (400603001200, 400603001022, 'Veg. Crispy', 'veg. crispy', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. crispy'),
    -- items[15] Veg. Crunchy
    (400603001201, 400603001022, 'Veg. Crunchy', 'veg. crunchy', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. crunchy'),
    -- items[16] Veg. Lollypop
    (400603001202, 400603001022, 'Veg. Lollypop', 'veg. lollypop', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. lollypop'),
    -- items[17] Veg. Manchurian
    (400603001203, 400603001022, 'Veg. Manchurian', 'veg. manchurian', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. manchurian'),
    -- items[18] Veg. Seekh Kebab
    (400603001204, 400603001022, 'Veg. Seekh Kebab', 'veg. seekh kebab', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg. seekh kebab'),
    -- items[19] Soyabean Chilly
    (400603001205, 400603001022, 'Soyabean Chilly', 'soyabean chilly', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'soyabean chilly'),
    -- items[20] Soyabean Manchurian
    (400603001206, 400603001022, 'Soyabean Manchurian', 'soyabean manchurian', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'soyabean manchurian'),
    -- items[21] Soyabean Schezwan
    (400603001207, 400603001022, 'Soyabean Schezwan', 'soyabean schezwan', NULL, 'VEGETABLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'soyabean schezwan'),
    -- items[22] Mushroom Manchurian
    (400603001208, 400603001022, 'Mushroom Manchurian', 'mushroom manchurian', NULL, 'VEGETABLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom manchurian'),
    -- items[23] Mushroom Chilly
    (400603001209, 400603001022, 'Mushroom Chilly', 'mushroom chilly', NULL, 'VEGETABLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom chilly'),
    -- items[24] Mushroom Tikka
    (400603001210, 400603001022, 'Mushroom Tikka', 'mushroom tikka', NULL, 'VEGETABLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom tikka')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001190, 400603001186, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001191, 400603001187, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001192, 400603001188, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001193, 400603001189, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001194, 400603001190, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001195, 400603001191, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001196, 400603001192, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001197, 400603001193, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001198, 400603001194, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001199, 400603001195, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001200, 400603001196, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001201, 400603001197, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001202, 400603001198, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001203, 400603001199, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001204, 400603001200, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001205, 400603001201, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001206, 400603001202, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001207, 400603001203, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001208, 400603001204, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001209, 400603001205, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001210, 400603001206, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001211, 400603001207, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001212, 400603001208, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001213, 400603001209, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001214, 400603001210, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001190, 400603001190, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001191, 400603001191, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001192, 400603001192, 231.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001193, 400603001193, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001194, 400603001194, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001195, 400603001195, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001196, 400603001196, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001197, 400603001197, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001198, 400603001198, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001199, 400603001199, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001200, 400603001200, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001201, 400603001201, 273.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001202, 400603001202, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001203, 400603001203, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001204, 400603001204, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001205, 400603001205, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001206, 400603001206, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001207, 400603001207, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001208, 400603001208, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001209, 400603001209, 157.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001210, 400603001210, 157.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001211, 400603001211, 188.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001212, 400603001212, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001213, 400603001213, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001214, 400603001214, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [23/25] SPRING ROLL  |  JSON: pages[1].sections[7]  (Maitri2.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Chicken
    (400603001211, 400603001023, 'Chicken', 'chicken', NULL, 'SPRING ROLL', 'non_veg', 'CHICKEN', FALSE, FALSE, NULL, NULL, 'unverified', NULL),
    -- items[1] Egg
    (400603001212, 400603001023, 'Egg', 'egg', NULL, 'SPRING ROLL', 'egg', 'EGG', FALSE, FALSE, FALSE, NULL, 'unverified', NULL),
    -- items[2] Mushroom
    (400603001213, 400603001023, 'Mushroom', 'mushroom', NULL, 'SPRING ROLL', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', NULL),
    -- items[3] Fish
    (400603001214, 400603001023, 'Fish', 'fish', NULL, 'SPRING ROLL', 'non_veg', 'SEAFOOD', FALSE, FALSE, NULL, NULL, 'unverified', NULL),
    -- items[4] Veg.
    (400603001215, 400603001023, 'Veg.', 'veg.', NULL, 'SPRING ROLL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', NULL)
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001215, 400603001211, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001216, 400603001212, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001217, 400603001213, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001218, 400603001214, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001219, 400603001215, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001215, 400603001215, 330.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001216, 400603001216, 315.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001217, 400603001217, 304.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001218, 400603001218, 377.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001219, 400603001219, 294.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [24/25] CHAKNA  |  JSON: pages[1].sections[8]  (Maitri2.jpg, column 3; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Channa Chatpata
    (400603001216, 400603001024, 'Channa Chatpata', 'channa chatpata', NULL, 'CHAKNA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'channa chatpata'),
    -- items[1] Channa Oil Fry With Garlic
    (400603001217, 400603001024, 'Channa Oil Fry With Garlic', 'channa oil fry with garlic', NULL, 'CHAKNA', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'channa oil fry with garlic'),
    -- items[2] Green Peas, Jeera Butter Fry
    (400603001218, 400603001024, 'Green Peas, Jeera Butter Fry', 'green peas, jeera butter fry', NULL, 'CHAKNA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'green peas, jeera butter fry'),
    -- items[3] Garlic Fry
    (400603001219, 400603001024, 'Garlic Fry', 'garlic fry', NULL, 'CHAKNA', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'garlic fry'),
    -- items[4] Finger Chips
    (400603001220, 400603001024, 'Finger Chips', 'finger chips', NULL, 'CHAKNA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'finger chips')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001220, 400603001216, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001221, 400603001217, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001222, 400603001218, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001223, 400603001219, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400603001224, 400603001220, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001220, 400603001220, 178.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001221, 400603001221, 105.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001222, 400603001222, 125.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001223, 400603001223, 116.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001224, 400603001224, 84.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- [25/25] BEVERAGES  |  JSON: pages[1].sections[9]  (Maitri2.jpg, column 3; 3 JSON line(s) -> 2 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400603001, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Bisleri Packaged Water
    (400603001221, 400603001025, 'Bisleri Packaged Water', 'bisleri packaged water', NULL, 'BEVERAGES', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'bisleri packaged water'),
    -- items[2] Soft Drinks
    (400603001222, 400603001025, 'Soft Drinks', 'soft drinks', NULL, 'BEVERAGES', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'soft drinks')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400603001225, 400603001221, '1 Ltr', NULL, 'fixed', 1, 'l', 1, TRUE, TRUE),
    (400603001226, 400603001221, '500 ml', NULL, 'fixed', 500, 'ml', 2, FALSE, TRUE),
    (400603001227, 400603001222, '600 ml', NULL, 'fixed', 600, 'ml', 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400603001225, 400603001225, 20.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001226, 400603001226, 10.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001),
    (400603001227, 400603001227, 40.00, 'GST', 'exclusive', 5.0000, TIMESTAMP '2026-05-06 00:00:00', 'unverified', 400603001);

-- ----------------------------------------------------------------------------
-- 7. PROVENANCE LINKS (menu_item_source, menu_item_price_source)
-- ----------------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400603001001, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001002, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001003, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001004, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001005, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001006, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001007, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001008, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001009, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001010, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001011, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001012, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001013, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001014, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001015, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001016, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001017, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001018, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001019, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001020, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001021, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001022, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001023, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001024, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001025, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001026, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001027, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001028, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001029, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001030, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001031, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001032, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001033, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001034, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001035, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001036, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001037, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001038, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001039, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001040, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001041, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001042, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001043, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001044, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001045, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001046, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001047, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001048, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001049, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001050, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001051, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001052, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001053, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001054, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001055, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001056, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001057, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001058, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001059, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001060, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001061, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001062, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001063, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001064, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001065, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001066, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001067, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001068, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001069, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001070, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001071, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001072, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001073, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001074, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001075, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001076, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001077, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001078, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001079, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001080, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001081, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001082, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001083, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001084, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001085, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001086, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001087, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001088, 400603001, (:base_batch + 1), 0.70000, 'needs_review'),
    (400603001089, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001090, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001091, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001092, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001093, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001094, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001095, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001096, 400603001, (:base_batch + 1), 0.50000, 'needs_review'),
    (400603001097, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001098, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001099, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001100, 400603001, (:base_batch + 1), 0.90000, 'unverified'),
    (400603001101, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001102, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001103, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001104, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001105, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001106, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001107, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001108, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001109, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001110, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001111, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001112, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001113, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001114, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001115, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001116, 400603001, (:base_batch + 1), 0.85000, 'unverified'),
    (400603001117, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001118, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001119, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001120, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001121, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001122, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001123, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001124, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001125, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001126, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001127, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001128, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001129, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001130, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001131, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001132, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001133, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001134, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001135, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001136, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001137, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001138, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001139, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001140, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001141, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001142, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001143, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001144, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001145, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001146, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001147, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001148, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001149, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001150, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001151, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001152, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001153, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001154, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001155, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001156, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001157, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001158, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001159, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001160, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001161, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001162, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001163, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001164, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001165, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001166, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001167, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001168, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001169, 400603001, (:base_batch + 1), 0.70000, 'needs_review'),
    (400603001170, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001171, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001172, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001173, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001174, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001175, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001176, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001177, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001178, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001179, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001180, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001181, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001182, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001183, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001184, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001185, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001186, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001187, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001188, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001189, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001190, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001191, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001192, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001193, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001194, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001195, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001196, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001197, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001198, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001199, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001200, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001201, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001202, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001203, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001204, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001205, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001206, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001207, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001208, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001209, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001210, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001211, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001212, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001213, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001214, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001215, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001216, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001217, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001218, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001219, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001220, 400603001, (:base_batch + 1), 0.95000, 'unverified'),
    (400603001221, 400603001, (:base_batch + 1), 0.85000, 'unverified'),
    (400603001222, 400603001, (:base_batch + 1), 0.85000, 'unverified');
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400603001001, 400603001, (:base_batch + 1), 0.95000),
    (400603001002, 400603001, (:base_batch + 1), 0.95000),
    (400603001003, 400603001, (:base_batch + 1), 0.95000),
    (400603001004, 400603001, (:base_batch + 1), 0.95000),
    (400603001005, 400603001, (:base_batch + 1), 0.95000),
    (400603001006, 400603001, (:base_batch + 1), 0.95000),
    (400603001007, 400603001, (:base_batch + 1), 0.95000),
    (400603001008, 400603001, (:base_batch + 1), 0.95000),
    (400603001009, 400603001, (:base_batch + 1), 0.95000),
    (400603001010, 400603001, (:base_batch + 1), 0.95000),
    (400603001011, 400603001, (:base_batch + 1), 0.95000),
    (400603001012, 400603001, (:base_batch + 1), 0.95000),
    (400603001013, 400603001, (:base_batch + 1), 0.95000),
    (400603001014, 400603001, (:base_batch + 1), 0.95000),
    (400603001015, 400603001, (:base_batch + 1), 0.90000),
    (400603001016, 400603001, (:base_batch + 1), 0.90000),
    (400603001017, 400603001, (:base_batch + 1), 0.95000),
    (400603001018, 400603001, (:base_batch + 1), 0.95000),
    (400603001019, 400603001, (:base_batch + 1), 0.90000),
    (400603001020, 400603001, (:base_batch + 1), 0.90000),
    (400603001021, 400603001, (:base_batch + 1), 0.95000),
    (400603001022, 400603001, (:base_batch + 1), 0.95000),
    (400603001023, 400603001, (:base_batch + 1), 0.95000),
    (400603001024, 400603001, (:base_batch + 1), 0.95000),
    (400603001025, 400603001, (:base_batch + 1), 0.95000),
    (400603001026, 400603001, (:base_batch + 1), 0.95000),
    (400603001027, 400603001, (:base_batch + 1), 0.95000),
    (400603001028, 400603001, (:base_batch + 1), 0.95000),
    (400603001029, 400603001, (:base_batch + 1), 0.95000),
    (400603001030, 400603001, (:base_batch + 1), 0.95000),
    (400603001031, 400603001, (:base_batch + 1), 0.95000),
    (400603001032, 400603001, (:base_batch + 1), 0.90000),
    (400603001033, 400603001, (:base_batch + 1), 0.90000),
    (400603001034, 400603001, (:base_batch + 1), 0.95000),
    (400603001035, 400603001, (:base_batch + 1), 0.95000),
    (400603001036, 400603001, (:base_batch + 1), 0.95000),
    (400603001037, 400603001, (:base_batch + 1), 0.95000),
    (400603001038, 400603001, (:base_batch + 1), 0.95000),
    (400603001039, 400603001, (:base_batch + 1), 0.95000),
    (400603001040, 400603001, (:base_batch + 1), 0.95000),
    (400603001041, 400603001, (:base_batch + 1), 0.95000),
    (400603001042, 400603001, (:base_batch + 1), 0.95000),
    (400603001043, 400603001, (:base_batch + 1), 0.95000),
    (400603001044, 400603001, (:base_batch + 1), 0.95000),
    (400603001045, 400603001, (:base_batch + 1), 0.95000),
    (400603001046, 400603001, (:base_batch + 1), 0.95000),
    (400603001047, 400603001, (:base_batch + 1), 0.95000),
    (400603001048, 400603001, (:base_batch + 1), 0.95000),
    (400603001049, 400603001, (:base_batch + 1), 0.95000),
    (400603001050, 400603001, (:base_batch + 1), 0.95000),
    (400603001051, 400603001, (:base_batch + 1), 0.95000),
    (400603001052, 400603001, (:base_batch + 1), 0.95000),
    (400603001053, 400603001, (:base_batch + 1), 0.95000),
    (400603001054, 400603001, (:base_batch + 1), 0.95000),
    (400603001055, 400603001, (:base_batch + 1), 0.95000),
    (400603001056, 400603001, (:base_batch + 1), 0.95000),
    (400603001057, 400603001, (:base_batch + 1), 0.95000),
    (400603001058, 400603001, (:base_batch + 1), 0.95000),
    (400603001059, 400603001, (:base_batch + 1), 0.95000),
    (400603001060, 400603001, (:base_batch + 1), 0.95000),
    (400603001061, 400603001, (:base_batch + 1), 0.95000),
    (400603001062, 400603001, (:base_batch + 1), 0.95000),
    (400603001063, 400603001, (:base_batch + 1), 0.95000),
    (400603001064, 400603001, (:base_batch + 1), 0.95000),
    (400603001065, 400603001, (:base_batch + 1), 0.95000),
    (400603001066, 400603001, (:base_batch + 1), 0.95000),
    (400603001067, 400603001, (:base_batch + 1), 0.95000),
    (400603001068, 400603001, (:base_batch + 1), 0.95000),
    (400603001069, 400603001, (:base_batch + 1), 0.95000),
    (400603001070, 400603001, (:base_batch + 1), 0.95000),
    (400603001071, 400603001, (:base_batch + 1), 0.95000),
    (400603001072, 400603001, (:base_batch + 1), 0.95000),
    (400603001073, 400603001, (:base_batch + 1), 0.95000),
    (400603001074, 400603001, (:base_batch + 1), 0.95000),
    (400603001075, 400603001, (:base_batch + 1), 0.95000),
    (400603001076, 400603001, (:base_batch + 1), 0.95000),
    (400603001077, 400603001, (:base_batch + 1), 0.95000),
    (400603001078, 400603001, (:base_batch + 1), 0.95000),
    (400603001079, 400603001, (:base_batch + 1), 0.95000),
    (400603001080, 400603001, (:base_batch + 1), 0.95000),
    (400603001081, 400603001, (:base_batch + 1), 0.95000),
    (400603001082, 400603001, (:base_batch + 1), 0.95000),
    (400603001083, 400603001, (:base_batch + 1), 0.95000),
    (400603001084, 400603001, (:base_batch + 1), 0.95000),
    (400603001085, 400603001, (:base_batch + 1), 0.95000),
    (400603001086, 400603001, (:base_batch + 1), 0.95000),
    (400603001087, 400603001, (:base_batch + 1), 0.95000),
    (400603001088, 400603001, (:base_batch + 1), 0.75000),
    (400603001089, 400603001, (:base_batch + 1), 0.75000),
    (400603001090, 400603001, (:base_batch + 1), 0.75000),
    (400603001091, 400603001, (:base_batch + 1), 0.95000),
    (400603001092, 400603001, (:base_batch + 1), 0.95000),
    (400603001093, 400603001, (:base_batch + 1), 0.95000),
    (400603001094, 400603001, (:base_batch + 1), 0.95000),
    (400603001095, 400603001, (:base_batch + 1), 0.95000),
    (400603001096, 400603001, (:base_batch + 1), 0.95000),
    (400603001097, 400603001, (:base_batch + 1), 0.95000),
    (400603001098, 400603001, (:base_batch + 1), 0.95000),
    (400603001099, 400603001, (:base_batch + 1), 0.95000),
    (400603001100, 400603001, (:base_batch + 1), 0.95000),
    (400603001101, 400603001, (:base_batch + 1), 0.95000),
    (400603001102, 400603001, (:base_batch + 1), 0.95000),
    (400603001103, 400603001, (:base_batch + 1), 0.95000),
    (400603001104, 400603001, (:base_batch + 1), 0.95000),
    (400603001105, 400603001, (:base_batch + 1), 0.95000),
    (400603001106, 400603001, (:base_batch + 1), 0.95000),
    (400603001107, 400603001, (:base_batch + 1), 0.95000),
    (400603001108, 400603001, (:base_batch + 1), 0.95000),
    (400603001109, 400603001, (:base_batch + 1), 0.95000),
    (400603001110, 400603001, (:base_batch + 1), 0.95000),
    (400603001111, 400603001, (:base_batch + 1), 0.95000),
    (400603001112, 400603001, (:base_batch + 1), 0.95000),
    (400603001113, 400603001, (:base_batch + 1), 0.95000),
    (400603001114, 400603001, (:base_batch + 1), 0.95000),
    (400603001115, 400603001, (:base_batch + 1), 0.95000),
    (400603001116, 400603001, (:base_batch + 1), 0.95000),
    (400603001117, 400603001, (:base_batch + 1), 0.95000),
    (400603001118, 400603001, (:base_batch + 1), 0.95000),
    (400603001119, 400603001, (:base_batch + 1), 0.95000),
    (400603001120, 400603001, (:base_batch + 1), 0.95000),
    (400603001121, 400603001, (:base_batch + 1), 0.95000),
    (400603001122, 400603001, (:base_batch + 1), 0.95000),
    (400603001123, 400603001, (:base_batch + 1), 0.95000),
    (400603001124, 400603001, (:base_batch + 1), 0.95000),
    (400603001125, 400603001, (:base_batch + 1), 0.95000),
    (400603001126, 400603001, (:base_batch + 1), 0.95000),
    (400603001127, 400603001, (:base_batch + 1), 0.95000),
    (400603001128, 400603001, (:base_batch + 1), 0.95000),
    (400603001129, 400603001, (:base_batch + 1), 0.95000),
    (400603001130, 400603001, (:base_batch + 1), 0.95000),
    (400603001131, 400603001, (:base_batch + 1), 0.95000),
    (400603001132, 400603001, (:base_batch + 1), 0.95000),
    (400603001133, 400603001, (:base_batch + 1), 0.95000),
    (400603001134, 400603001, (:base_batch + 1), 0.95000),
    (400603001135, 400603001, (:base_batch + 1), 0.95000),
    (400603001136, 400603001, (:base_batch + 1), 0.95000),
    (400603001137, 400603001, (:base_batch + 1), 0.95000),
    (400603001138, 400603001, (:base_batch + 1), 0.95000),
    (400603001139, 400603001, (:base_batch + 1), 0.95000),
    (400603001140, 400603001, (:base_batch + 1), 0.95000),
    (400603001141, 400603001, (:base_batch + 1), 0.95000),
    (400603001142, 400603001, (:base_batch + 1), 0.95000),
    (400603001143, 400603001, (:base_batch + 1), 0.95000),
    (400603001144, 400603001, (:base_batch + 1), 0.95000),
    (400603001145, 400603001, (:base_batch + 1), 0.95000),
    (400603001146, 400603001, (:base_batch + 1), 0.95000),
    (400603001147, 400603001, (:base_batch + 1), 0.95000),
    (400603001148, 400603001, (:base_batch + 1), 0.95000),
    (400603001149, 400603001, (:base_batch + 1), 0.95000),
    (400603001150, 400603001, (:base_batch + 1), 0.95000),
    (400603001151, 400603001, (:base_batch + 1), 0.95000),
    (400603001152, 400603001, (:base_batch + 1), 0.95000),
    (400603001153, 400603001, (:base_batch + 1), 0.95000),
    (400603001154, 400603001, (:base_batch + 1), 0.95000),
    (400603001155, 400603001, (:base_batch + 1), 0.95000),
    (400603001156, 400603001, (:base_batch + 1), 0.95000),
    (400603001157, 400603001, (:base_batch + 1), 0.95000),
    (400603001158, 400603001, (:base_batch + 1), 0.95000),
    (400603001159, 400603001, (:base_batch + 1), 0.95000),
    (400603001160, 400603001, (:base_batch + 1), 0.95000),
    (400603001161, 400603001, (:base_batch + 1), 0.95000),
    (400603001162, 400603001, (:base_batch + 1), 0.95000),
    (400603001163, 400603001, (:base_batch + 1), 0.95000),
    (400603001164, 400603001, (:base_batch + 1), 0.95000),
    (400603001165, 400603001, (:base_batch + 1), 0.95000),
    (400603001166, 400603001, (:base_batch + 1), 0.95000),
    (400603001167, 400603001, (:base_batch + 1), 0.90000),
    (400603001168, 400603001, (:base_batch + 1), 0.90000),
    (400603001169, 400603001, (:base_batch + 1), 0.95000),
    (400603001170, 400603001, (:base_batch + 1), 0.95000),
    (400603001171, 400603001, (:base_batch + 1), 0.95000),
    (400603001172, 400603001, (:base_batch + 1), 0.95000),
    (400603001173, 400603001, (:base_batch + 1), 0.95000),
    (400603001174, 400603001, (:base_batch + 1), 0.95000),
    (400603001175, 400603001, (:base_batch + 1), 0.95000),
    (400603001176, 400603001, (:base_batch + 1), 0.95000),
    (400603001177, 400603001, (:base_batch + 1), 0.95000),
    (400603001178, 400603001, (:base_batch + 1), 0.95000),
    (400603001179, 400603001, (:base_batch + 1), 0.95000),
    (400603001180, 400603001, (:base_batch + 1), 0.95000),
    (400603001181, 400603001, (:base_batch + 1), 0.95000),
    (400603001182, 400603001, (:base_batch + 1), 0.95000),
    (400603001183, 400603001, (:base_batch + 1), 0.95000),
    (400603001184, 400603001, (:base_batch + 1), 0.95000),
    (400603001185, 400603001, (:base_batch + 1), 0.95000),
    (400603001186, 400603001, (:base_batch + 1), 0.95000),
    (400603001187, 400603001, (:base_batch + 1), 0.95000),
    (400603001188, 400603001, (:base_batch + 1), 0.95000),
    (400603001189, 400603001, (:base_batch + 1), 0.95000),
    (400603001190, 400603001, (:base_batch + 1), 0.95000),
    (400603001191, 400603001, (:base_batch + 1), 0.95000),
    (400603001192, 400603001, (:base_batch + 1), 0.95000),
    (400603001193, 400603001, (:base_batch + 1), 0.95000),
    (400603001194, 400603001, (:base_batch + 1), 0.95000),
    (400603001195, 400603001, (:base_batch + 1), 0.95000),
    (400603001196, 400603001, (:base_batch + 1), 0.95000),
    (400603001197, 400603001, (:base_batch + 1), 0.95000),
    (400603001198, 400603001, (:base_batch + 1), 0.95000),
    (400603001199, 400603001, (:base_batch + 1), 0.95000),
    (400603001200, 400603001, (:base_batch + 1), 0.95000),
    (400603001201, 400603001, (:base_batch + 1), 0.95000),
    (400603001202, 400603001, (:base_batch + 1), 0.95000),
    (400603001203, 400603001, (:base_batch + 1), 0.95000),
    (400603001204, 400603001, (:base_batch + 1), 0.95000),
    (400603001205, 400603001, (:base_batch + 1), 0.95000),
    (400603001206, 400603001, (:base_batch + 1), 0.95000),
    (400603001207, 400603001, (:base_batch + 1), 0.95000),
    (400603001208, 400603001, (:base_batch + 1), 0.95000),
    (400603001209, 400603001, (:base_batch + 1), 0.95000),
    (400603001210, 400603001, (:base_batch + 1), 0.95000),
    (400603001211, 400603001, (:base_batch + 1), 0.95000),
    (400603001212, 400603001, (:base_batch + 1), 0.95000),
    (400603001213, 400603001, (:base_batch + 1), 0.95000),
    (400603001214, 400603001, (:base_batch + 1), 0.95000),
    (400603001215, 400603001, (:base_batch + 1), 0.95000),
    (400603001216, 400603001, (:base_batch + 1), 0.95000),
    (400603001217, 400603001, (:base_batch + 1), 0.95000),
    (400603001218, 400603001, (:base_batch + 1), 0.95000),
    (400603001219, 400603001, (:base_batch + 1), 0.95000),
    (400603001220, 400603001, (:base_batch + 1), 0.95000),
    (400603001221, 400603001, (:base_batch + 1), 0.95000),
    (400603001222, 400603001, (:base_batch + 1), 0.95000),
    (400603001223, 400603001, (:base_batch + 1), 0.95000),
    (400603001224, 400603001, (:base_batch + 1), 0.95000),
    (400603001225, 400603001, (:base_batch + 1), 0.95000),
    (400603001226, 400603001, (:base_batch + 1), 0.95000),
    (400603001227, 400603001, (:base_batch + 1), 0.95000);

-- ----------------------------------------------------------------------------
-- 8. DELIVERY CAPABILITY
-- ----------------------------------------------------------------------------
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available)
VALUES (400603001, TRUE, TRUE);
-- JSON: "FOR HOME DELIVERY CALL 7304390358, 9930853152" names no delivery partner; self delivery inferred

-- ----------------------------------------------------------------------------
-- 9. BOARD MAPPINGS (board <- categories <- items, JSON order)
-- ----------------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400603001, 400603001001, 400603001001, 1),
    (400603001, 400603001001, 400603001002, 2),
    (400603001, 400603001001, 400603001003, 3),
    (400603001, 400603001001, 400603001004, 4),
    (400603001, 400603001001, 400603001005, 5),
    (400603001, 400603001001, 400603001006, 6),
    (400603001, 400603001001, 400603001007, 7),
    (400603001, 400603001001, 400603001008, 8),
    (400603001, 400603001001, 400603001009, 9),
    (400603001, 400603001001, 400603001010, 10),
    (400603001, 400603001001, 400603001011, 11),
    (400603001, 400603001001, 400603001012, 12),
    (400603001, 400603001001, 400603001013, 13),
    (400603001, 400603001001, 400603001014, 14),
    (400603001, 400603001001, 400603001015, 15),
    (400603001, 400603001001, 400603001016, 16),
    (400603001, 400603001001, 400603001017, 17),
    (400603001, 400603001001, 400603001018, 18),
    (400603001, 400603001001, 400603001019, 19),
    (400603001, 400603001001, 400603001020, 20),
    (400603001, 400603001001, 400603001021, 21),
    (400603001, 400603001001, 400603001022, 22),
    (400603001, 400603001001, 400603001023, 23),
    (400603001, 400603001001, 400603001024, 24),
    (400603001, 400603001001, 400603001025, 25);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id,
                             display_sequence)
VALUES
    (400603001001, 400603001, 400603001001, 400603001001, 400603001001, 1),
    (400603001002, 400603001, 400603001001, 400603001002, 400603001001, 2),
    (400603001003, 400603001, 400603001001, 400603001003, 400603001001, 3),
    (400603001004, 400603001, 400603001001, 400603001004, 400603001001, 4),
    (400603001005, 400603001, 400603001001, 400603001005, 400603001001, 5),
    (400603001006, 400603001, 400603001001, 400603001006, 400603001001, 6),
    (400603001007, 400603001, 400603001001, 400603001007, 400603001001, 7),
    (400603001008, 400603001, 400603001001, 400603001008, 400603001002, 8),
    (400603001009, 400603001, 400603001001, 400603001009, 400603001002, 9),
    (400603001010, 400603001, 400603001001, 400603001010, 400603001002, 10),
    (400603001011, 400603001, 400603001001, 400603001011, 400603001002, 11),
    (400603001012, 400603001, 400603001001, 400603001012, 400603001002, 12),
    (400603001013, 400603001, 400603001001, 400603001013, 400603001003, 13),
    (400603001014, 400603001, 400603001001, 400603001014, 400603001003, 14),
    (400603001015, 400603001, 400603001001, 400603001015, 400603001003, 15),
    (400603001016, 400603001, 400603001001, 400603001016, 400603001003, 16),
    (400603001017, 400603001, 400603001001, 400603001017, 400603001003, 17),
    (400603001018, 400603001, 400603001001, 400603001018, 400603001003, 18),
    (400603001019, 400603001, 400603001001, 400603001019, 400603001003, 19),
    (400603001020, 400603001, 400603001001, 400603001020, 400603001003, 20),
    (400603001021, 400603001, 400603001001, 400603001021, 400603001003, 21),
    (400603001022, 400603001, 400603001001, 400603001022, 400603001003, 22),
    (400603001023, 400603001, 400603001001, 400603001023, 400603001003, 23),
    (400603001024, 400603001, 400603001001, 400603001024, 400603001003, 24),
    (400603001025, 400603001, 400603001001, 400603001025, 400603001003, 25),
    (400603001026, 400603001, 400603001001, 400603001026, 400603001003, 26),
    (400603001027, 400603001, 400603001001, 400603001027, 400603001003, 27),
    (400603001028, 400603001, 400603001001, 400603001028, 400603001003, 28),
    (400603001029, 400603001, 400603001001, 400603001029, 400603001004, 29),
    (400603001030, 400603001, 400603001001, 400603001030, 400603001004, 30),
    (400603001031, 400603001, 400603001001, 400603001031, 400603001004, 31),
    (400603001032, 400603001, 400603001001, 400603001032, 400603001004, 32),
    (400603001033, 400603001, 400603001001, 400603001033, 400603001004, 33),
    (400603001034, 400603001, 400603001001, 400603001034, 400603001004, 34),
    (400603001035, 400603001, 400603001001, 400603001035, 400603001004, 35),
    (400603001036, 400603001, 400603001001, 400603001036, 400603001005, 36),
    (400603001037, 400603001, 400603001001, 400603001037, 400603001005, 37),
    (400603001038, 400603001, 400603001001, 400603001038, 400603001005, 38),
    (400603001039, 400603001, 400603001001, 400603001039, 400603001005, 39),
    (400603001040, 400603001, 400603001001, 400603001040, 400603001005, 40),
    (400603001041, 400603001, 400603001001, 400603001041, 400603001005, 41),
    (400603001042, 400603001, 400603001001, 400603001042, 400603001005, 42),
    (400603001043, 400603001, 400603001001, 400603001043, 400603001005, 43),
    (400603001044, 400603001, 400603001001, 400603001044, 400603001005, 44),
    (400603001045, 400603001, 400603001001, 400603001045, 400603001005, 45),
    (400603001046, 400603001, 400603001001, 400603001046, 400603001005, 46),
    (400603001047, 400603001, 400603001001, 400603001047, 400603001005, 47),
    (400603001048, 400603001, 400603001001, 400603001048, 400603001005, 48),
    (400603001049, 400603001, 400603001001, 400603001049, 400603001005, 49),
    (400603001050, 400603001, 400603001001, 400603001050, 400603001005, 50),
    (400603001051, 400603001, 400603001001, 400603001051, 400603001005, 51),
    (400603001052, 400603001, 400603001001, 400603001052, 400603001005, 52),
    (400603001053, 400603001, 400603001001, 400603001053, 400603001005, 53),
    (400603001054, 400603001, 400603001001, 400603001054, 400603001005, 54),
    (400603001055, 400603001, 400603001001, 400603001055, 400603001005, 55),
    (400603001056, 400603001, 400603001001, 400603001056, 400603001005, 56),
    (400603001057, 400603001, 400603001001, 400603001057, 400603001005, 57),
    (400603001058, 400603001, 400603001001, 400603001058, 400603001005, 58),
    (400603001059, 400603001, 400603001001, 400603001059, 400603001005, 59),
    (400603001060, 400603001, 400603001001, 400603001060, 400603001005, 60),
    (400603001061, 400603001, 400603001001, 400603001061, 400603001005, 61),
    (400603001062, 400603001, 400603001001, 400603001062, 400603001006, 62),
    (400603001063, 400603001, 400603001001, 400603001063, 400603001006, 63),
    (400603001064, 400603001, 400603001001, 400603001064, 400603001006, 64),
    (400603001065, 400603001, 400603001001, 400603001065, 400603001006, 65),
    (400603001066, 400603001, 400603001001, 400603001066, 400603001007, 66),
    (400603001067, 400603001, 400603001001, 400603001067, 400603001007, 67),
    (400603001068, 400603001, 400603001001, 400603001068, 400603001007, 68),
    (400603001069, 400603001, 400603001001, 400603001069, 400603001007, 69),
    (400603001070, 400603001, 400603001001, 400603001070, 400603001007, 70),
    (400603001071, 400603001, 400603001001, 400603001071, 400603001007, 71),
    (400603001072, 400603001, 400603001001, 400603001072, 400603001008, 72),
    (400603001073, 400603001, 400603001001, 400603001073, 400603001008, 73),
    (400603001074, 400603001, 400603001001, 400603001074, 400603001008, 74),
    (400603001075, 400603001, 400603001001, 400603001075, 400603001009, 75),
    (400603001076, 400603001, 400603001001, 400603001076, 400603001009, 76),
    (400603001077, 400603001, 400603001001, 400603001077, 400603001009, 77),
    (400603001078, 400603001, 400603001001, 400603001078, 400603001009, 78),
    (400603001079, 400603001, 400603001001, 400603001079, 400603001009, 79),
    (400603001080, 400603001, 400603001001, 400603001080, 400603001010, 80),
    (400603001081, 400603001, 400603001001, 400603001081, 400603001010, 81),
    (400603001082, 400603001, 400603001001, 400603001082, 400603001010, 82),
    (400603001083, 400603001, 400603001001, 400603001083, 400603001010, 83),
    (400603001084, 400603001, 400603001001, 400603001084, 400603001011, 84),
    (400603001085, 400603001, 400603001001, 400603001085, 400603001011, 85),
    (400603001086, 400603001, 400603001001, 400603001086, 400603001011, 86),
    (400603001087, 400603001, 400603001001, 400603001087, 400603001011, 87),
    (400603001088, 400603001, 400603001001, 400603001088, 400603001011, 88),
    (400603001089, 400603001, 400603001001, 400603001089, 400603001011, 89),
    (400603001090, 400603001, 400603001001, 400603001090, 400603001011, 90),
    (400603001091, 400603001, 400603001001, 400603001091, 400603001011, 91),
    (400603001092, 400603001, 400603001001, 400603001092, 400603001011, 92),
    (400603001093, 400603001, 400603001001, 400603001093, 400603001011, 93),
    (400603001094, 400603001, 400603001001, 400603001094, 400603001011, 94),
    (400603001095, 400603001, 400603001001, 400603001095, 400603001012, 95),
    (400603001096, 400603001, 400603001001, 400603001096, 400603001012, 96),
    (400603001097, 400603001, 400603001001, 400603001097, 400603001012, 97),
    (400603001098, 400603001, 400603001001, 400603001098, 400603001012, 98),
    (400603001099, 400603001, 400603001001, 400603001099, 400603001012, 99),
    (400603001100, 400603001, 400603001001, 400603001100, 400603001012, 100),
    (400603001101, 400603001, 400603001001, 400603001101, 400603001013, 101),
    (400603001102, 400603001, 400603001001, 400603001102, 400603001013, 102),
    (400603001103, 400603001, 400603001001, 400603001103, 400603001013, 103),
    (400603001104, 400603001, 400603001001, 400603001104, 400603001013, 104),
    (400603001105, 400603001, 400603001001, 400603001105, 400603001014, 105),
    (400603001106, 400603001, 400603001001, 400603001106, 400603001014, 106),
    (400603001107, 400603001, 400603001001, 400603001107, 400603001014, 107),
    (400603001108, 400603001, 400603001001, 400603001108, 400603001014, 108),
    (400603001109, 400603001, 400603001001, 400603001109, 400603001014, 109),
    (400603001110, 400603001, 400603001001, 400603001110, 400603001015, 110),
    (400603001111, 400603001, 400603001001, 400603001111, 400603001015, 111),
    (400603001112, 400603001, 400603001001, 400603001112, 400603001015, 112),
    (400603001113, 400603001, 400603001001, 400603001113, 400603001015, 113),
    (400603001114, 400603001, 400603001001, 400603001114, 400603001015, 114),
    (400603001115, 400603001, 400603001001, 400603001115, 400603001015, 115),
    (400603001116, 400603001, 400603001001, 400603001116, 400603001015, 116),
    (400603001117, 400603001, 400603001001, 400603001117, 400603001016, 117),
    (400603001118, 400603001, 400603001001, 400603001118, 400603001016, 118),
    (400603001119, 400603001, 400603001001, 400603001119, 400603001016, 119),
    (400603001120, 400603001, 400603001001, 400603001120, 400603001016, 120),
    (400603001121, 400603001, 400603001001, 400603001121, 400603001016, 121),
    (400603001122, 400603001, 400603001001, 400603001122, 400603001016, 122),
    (400603001123, 400603001, 400603001001, 400603001123, 400603001016, 123),
    (400603001124, 400603001, 400603001001, 400603001124, 400603001016, 124),
    (400603001125, 400603001, 400603001001, 400603001125, 400603001016, 125),
    (400603001126, 400603001, 400603001001, 400603001126, 400603001016, 126),
    (400603001127, 400603001, 400603001001, 400603001127, 400603001016, 127),
    (400603001128, 400603001, 400603001001, 400603001128, 400603001016, 128),
    (400603001129, 400603001, 400603001001, 400603001129, 400603001016, 129),
    (400603001130, 400603001, 400603001001, 400603001130, 400603001016, 130),
    (400603001131, 400603001, 400603001001, 400603001131, 400603001016, 131),
    (400603001132, 400603001, 400603001001, 400603001132, 400603001016, 132),
    (400603001133, 400603001, 400603001001, 400603001133, 400603001016, 133),
    (400603001134, 400603001, 400603001001, 400603001134, 400603001016, 134),
    (400603001135, 400603001, 400603001001, 400603001135, 400603001016, 135),
    (400603001136, 400603001, 400603001001, 400603001136, 400603001016, 136),
    (400603001137, 400603001, 400603001001, 400603001137, 400603001016, 137),
    (400603001138, 400603001, 400603001001, 400603001138, 400603001016, 138),
    (400603001139, 400603001, 400603001001, 400603001139, 400603001016, 139),
    (400603001140, 400603001, 400603001001, 400603001140, 400603001016, 140),
    (400603001141, 400603001, 400603001001, 400603001141, 400603001016, 141),
    (400603001142, 400603001, 400603001001, 400603001142, 400603001016, 142),
    (400603001143, 400603001, 400603001001, 400603001143, 400603001017, 143),
    (400603001144, 400603001, 400603001001, 400603001144, 400603001017, 144),
    (400603001145, 400603001, 400603001001, 400603001145, 400603001017, 145),
    (400603001146, 400603001, 400603001001, 400603001146, 400603001017, 146),
    (400603001147, 400603001, 400603001001, 400603001147, 400603001017, 147),
    (400603001148, 400603001, 400603001001, 400603001148, 400603001017, 148),
    (400603001149, 400603001, 400603001001, 400603001149, 400603001017, 149),
    (400603001150, 400603001, 400603001001, 400603001150, 400603001017, 150),
    (400603001151, 400603001, 400603001001, 400603001151, 400603001017, 151),
    (400603001152, 400603001, 400603001001, 400603001152, 400603001017, 152),
    (400603001153, 400603001, 400603001001, 400603001153, 400603001017, 153),
    (400603001154, 400603001, 400603001001, 400603001154, 400603001017, 154),
    (400603001155, 400603001, 400603001001, 400603001155, 400603001017, 155),
    (400603001156, 400603001, 400603001001, 400603001156, 400603001017, 156),
    (400603001157, 400603001, 400603001001, 400603001157, 400603001018, 157),
    (400603001158, 400603001, 400603001001, 400603001158, 400603001018, 158),
    (400603001159, 400603001, 400603001001, 400603001159, 400603001018, 159),
    (400603001160, 400603001, 400603001001, 400603001160, 400603001018, 160),
    (400603001161, 400603001, 400603001001, 400603001161, 400603001018, 161),
    (400603001162, 400603001, 400603001001, 400603001162, 400603001018, 162),
    (400603001163, 400603001, 400603001001, 400603001163, 400603001018, 163),
    (400603001164, 400603001, 400603001001, 400603001164, 400603001018, 164),
    (400603001165, 400603001, 400603001001, 400603001165, 400603001018, 165),
    (400603001166, 400603001, 400603001001, 400603001166, 400603001018, 166),
    (400603001167, 400603001, 400603001001, 400603001167, 400603001018, 167),
    (400603001168, 400603001, 400603001001, 400603001168, 400603001018, 168),
    (400603001169, 400603001, 400603001001, 400603001169, 400603001018, 169),
    (400603001170, 400603001, 400603001001, 400603001170, 400603001018, 170),
    (400603001171, 400603001, 400603001001, 400603001171, 400603001019, 171),
    (400603001172, 400603001, 400603001001, 400603001172, 400603001019, 172),
    (400603001173, 400603001, 400603001001, 400603001173, 400603001020, 173),
    (400603001174, 400603001, 400603001001, 400603001174, 400603001020, 174),
    (400603001175, 400603001, 400603001001, 400603001175, 400603001020, 175),
    (400603001176, 400603001, 400603001001, 400603001176, 400603001020, 176),
    (400603001177, 400603001, 400603001001, 400603001177, 400603001020, 177),
    (400603001178, 400603001, 400603001001, 400603001178, 400603001020, 178),
    (400603001179, 400603001, 400603001001, 400603001179, 400603001020, 179),
    (400603001180, 400603001, 400603001001, 400603001180, 400603001020, 180),
    (400603001181, 400603001, 400603001001, 400603001181, 400603001021, 181),
    (400603001182, 400603001, 400603001001, 400603001182, 400603001021, 182),
    (400603001183, 400603001, 400603001001, 400603001183, 400603001021, 183),
    (400603001184, 400603001, 400603001001, 400603001184, 400603001021, 184),
    (400603001185, 400603001, 400603001001, 400603001185, 400603001021, 185),
    (400603001186, 400603001, 400603001001, 400603001186, 400603001022, 186),
    (400603001187, 400603001, 400603001001, 400603001187, 400603001022, 187),
    (400603001188, 400603001, 400603001001, 400603001188, 400603001022, 188),
    (400603001189, 400603001, 400603001001, 400603001189, 400603001022, 189),
    (400603001190, 400603001, 400603001001, 400603001190, 400603001022, 190),
    (400603001191, 400603001, 400603001001, 400603001191, 400603001022, 191),
    (400603001192, 400603001, 400603001001, 400603001192, 400603001022, 192),
    (400603001193, 400603001, 400603001001, 400603001193, 400603001022, 193),
    (400603001194, 400603001, 400603001001, 400603001194, 400603001022, 194),
    (400603001195, 400603001, 400603001001, 400603001195, 400603001022, 195),
    (400603001196, 400603001, 400603001001, 400603001196, 400603001022, 196),
    (400603001197, 400603001, 400603001001, 400603001197, 400603001022, 197),
    (400603001198, 400603001, 400603001001, 400603001198, 400603001022, 198),
    (400603001199, 400603001, 400603001001, 400603001199, 400603001022, 199),
    (400603001200, 400603001, 400603001001, 400603001200, 400603001022, 200),
    (400603001201, 400603001, 400603001001, 400603001201, 400603001022, 201),
    (400603001202, 400603001, 400603001001, 400603001202, 400603001022, 202),
    (400603001203, 400603001, 400603001001, 400603001203, 400603001022, 203),
    (400603001204, 400603001, 400603001001, 400603001204, 400603001022, 204),
    (400603001205, 400603001, 400603001001, 400603001205, 400603001022, 205),
    (400603001206, 400603001, 400603001001, 400603001206, 400603001022, 206),
    (400603001207, 400603001, 400603001001, 400603001207, 400603001022, 207),
    (400603001208, 400603001, 400603001001, 400603001208, 400603001022, 208),
    (400603001209, 400603001, 400603001001, 400603001209, 400603001022, 209),
    (400603001210, 400603001, 400603001001, 400603001210, 400603001022, 210),
    (400603001211, 400603001, 400603001001, 400603001211, 400603001023, 211),
    (400603001212, 400603001, 400603001001, 400603001212, 400603001023, 212),
    (400603001213, 400603001, 400603001001, 400603001213, 400603001023, 213),
    (400603001214, 400603001, 400603001001, 400603001214, 400603001023, 214),
    (400603001215, 400603001, 400603001001, 400603001215, 400603001023, 215),
    (400603001216, 400603001, 400603001001, 400603001216, 400603001024, 216),
    (400603001217, 400603001, 400603001001, 400603001217, 400603001024, 217),
    (400603001218, 400603001, 400603001001, 400603001218, 400603001024, 218),
    (400603001219, 400603001, 400603001001, 400603001219, 400603001024, 219),
    (400603001220, 400603001, 400603001001, 400603001220, 400603001024, 220),
    (400603001221, 400603001, 400603001001, 400603001221, 400603001025, 221),
    (400603001222, 400603001, 400603001001, 400603001222, 400603001025, 222);

-- ----------------------------------------------------------------------------
-- 10. LOAD SUMMARY (printed by psql before COMMIT)
-- ----------------------------------------------------------------------------
SELECT 'menu_category' AS table_name, count(*) AS rows_loaded FROM menu_category WHERE restaurant_id = 400603001
UNION ALL SELECT 'menu_item', count(*) FROM menu_item WHERE restaurant_id = 400603001
UNION ALL SELECT 'menu_item_variant', count(*) FROM menu_item_variant v JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 400603001
UNION ALL SELECT 'menu_item_price', count(*) FROM menu_item_price p JOIN menu_item_variant v USING (variant_id) JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 400603001
UNION ALL SELECT 'menu_board_item', count(*) FROM menu_board_item WHERE restaurant_id = 400603001
UNION ALL SELECT 'items linked to a canonical dish', count(*) FROM menu_item WHERE restaurant_id = 400603001 AND canonical_dish_id IS NOT NULL
UNION ALL SELECT 'items needing review', count(*) FROM menu_item WHERE restaurant_id = 400603001 AND verification_status_code = 'needs_review';

COMMIT;

-- ============================================================================
-- BLOCK 1 - ROWS NEEDING REVIEW OR WITH CONFIDENCE < 0.80
-- ============================================================================
-- menu_item rows (3):
--   - item 400603001088  Stuffed Paratha  [pages[0].sections[10].columns[0].items[4]]  conf 0.70: filling not stated; veg assumed because a non-veg 'Chi. Stuffed Paratha' is listed separately
--   - item 400603001096  Mix Fried Rice  [pages[0].sections[11].columns[0].items[1]]  conf 0.50: 'Mix' is not defined in the JSON (mixed non-veg, priced like Prawns Fried Rice at 336, or mixed veg); classification and protein left NULL
--   - item 400603001169  Liver Tandoori  [pages[1].sections[2].columns[0].items[12]]  conf 0.70: which animal's liver is not stated; protein left NULL (every other item in this section is chicken)
-- menu_item_price rows (3):
--   - price 400603001088  Roti (Plain / Butter) / Regular = 21.00  [pages[0].sections[10].columns[0].items[1]]  conf 0.75: name offers 'Plain / Butter' but only one price is printed; unclear whether it applies to both options (single Regular variant kept)
--   - price 400603001089  Naan (Plain / Butter) / Regular = 42.00  [pages[0].sections[10].columns[0].items[2]]  conf 0.75: name offers 'Plain / Butter' but only one price is printed; unclear whether it applies to both options (single Regular variant kept)
--   - price 400603001090  Paratha (Plain / Butter) / Regular = 42.00  [pages[0].sections[10].columns[0].items[3]]  conf 0.75: name offers 'Plain / Butter' but only one price is printed; unclear whether it applies to both options (single Regular variant kept)

-- ============================================================================
-- BLOCK 2 - JSON CONTENT WITH NO SCHEMA COLUMN (kept here, not dropped)
-- ============================================================================
--   - GSTIN printed on page 2: "GST No.: 27AABFM7666K1ZY" (no column for it).
--   - Bulk Biryani lines (page 2): Chicken Biryani (1Kg) 1143, Mutton Biryani (1Kg) 1667, Veg. Pulav (1Kg) 905, Veg. Biryani (1Kg) 1048, Paneer Biryani (1Kg) 1095. Bulk Gravy list (page 2): Chicken 476, Mutton 667, Prawns 600, Veg 467, Paneer 467, Egg 238 (unit not stated). "All Bulk order must be placed. Atleast 6 hrs. before delivery Time". Not loaded as variants or items; say if they should be.
--   - "Gravy Items Also Prepared in South Indian Style, Malvani Style, Punjabi Style" - not modelled as tags or add-ons.
--   - "# Indicates Mini Portion Available." - the # marks did not survive OCR in any item name, so mini-portion items cannot be identified.
--   - "We levy no service charge."; "If you have any concerns regarding food allergies, Please alert the Waiter / Manager prior to ordering."; "Order Once Placed Will Not Be Cancelled."; "All foods prepared in Refined Oil."; "All Prices Are In Indian Rupees."
--   - JSON header timing "11 am-12:30 am" was superseded by the owner-supplied 11:00 AM to 11:59 PM.
--   - Page images Maitri1.jpg, Maitri2.jpg: no media storage URIs, so media_asset / menu_extraction_image are not populated.
--   - change_event_outbox is not written by this script.
