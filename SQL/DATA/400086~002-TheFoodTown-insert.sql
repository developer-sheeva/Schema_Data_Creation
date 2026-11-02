-- ============================================================================
-- KHAUSTAN.COM - KhaustanRestaurantMenu - DATA LOAD FOR THE FOOD TOWN - GHATKOPAR BRANCH
-- Source JSON : The_Food_Town_Menu_OCR.json
-- Namespace   : establishment_id = restaurant_id = source_id = 400086002   (all child IDs are 400086002NNN, NNN = 001..999)
-- Target      : PostgreSQL, run with psql (uses \connect, \set, \encoding, \gset)
-- ============================================================================
--
-- WHAT THIS SCRIPT LOADS
--   43 categories | 366 menu items | 409 variants | 409 prices | 1 a_la_carte board
--   340 distinct canonical-dish keys (new rows only where no exact normalized-name match already exists)
--
-- ID RULES
--   Deterministic: menu_board / menu_category / menu_item / menu_item_variant / menu_item_price / menu_board_item = 400086002NNN.
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
--   - Address (Shop 4, Neelkanth Corporate It Park, Kirol Rd, Vidyavihar West, Ghatkopar, Mumbai, Maharashtra 400086) and phone 8433843335 were supplied by the owner for the Ghatkopar branch; the JSON address is empty and its header lists three outlet phones.
--   - brand_id 100002 comes from the JSON. The brand row is inserted only if absent (name and website from the JSON). Items are loaded standalone (template_item_id NULL) - confirm whether a brand_menu_template exists for this brand.
--   - JSON timing "11:30 am-11:30 pm" has no day qualifier: applied to all 7 days.
--   - JSON free_delivery "2km, minimum order 250": stored as delivery_available + self_delivery_available (self delivery inferred from "free delivery") with self_delivery_min_order_amount 250.
--   - Owner rule: a variant price that is not printed takes the maximum price among that item's variants (affected lines are in Block 1).
--   - JSON pure_veg = Yes (and "PURE VEG" on the cover): every item is food_classification veg; restaurant tags PURE_VEG and JAIN_AVAILABLE ("Jain food is available here!") applied.
--   - Tax: the JSON only says "*Government Taxes as Applicable" (no rate, no inclusive/exclusive statement) - tax columns left NULL.
--   - cost_for_two_amount left NULL: JSON "price range 600-800" does not say whether it is per person or for two.
--   - is_personal_number left at its FALSE default.
--
-- INFERRED LEGENDS / STRUCTURE
--   - 'Hot Garlic Gravy': 2 options (Veg / Paneer) vs 2 printed price(s) 290.00 / 320.00
--   - 'Kung Pao Gravy': 3 options (Veg / Veg Ball / Paneer) vs 2 printed price(s) 300.00 / 340.00; missing price(s) filled with max 340.00
--   - 'Pudina Paratha / Naan / Kulcha': 3 options (Paratha / Naan / Kulcha) vs 2 printed price(s) 100.00 / 120.00; missing price(s) filled with max 120.00
--   - 'Ajwain Paratha / Naan / Kulcha': 3 options (Paratha / Naan / Kulcha) vs 2 printed price(s) 100.00 / 120.00; missing price(s) filled with max 120.00
--   - 'Methi Paratha / Naan / Kulcha': 3 options (Paratha / Naan / Kulcha) vs 2 printed price(s) 100.00 / 120.00; missing price(s) filled with max 120.00
--   - 'Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg.': 4 options (Aloo / Gobi / Onion / Mix Veg.) vs 2 printed price(s) 150.00 / 160.00; missing price(s) filled with max 160.00
--   - 'Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg.': 4 options (Aloo / Gobi / Onion / Mix Veg.) vs 2 printed price(s) 150.00 / 160.00; missing price(s) filled with max 160.00
--   - 'Makai Roti / Bajra Roti / Missi Roti / Garlic Roti': 4 options (Makai Roti / Bajra Roti / Missi Roti / Garlic Roti) vs 2 printed price(s) 80.00 / 90.00; missing price(s) filled with max 90.00
--   - 'Plain Rumali Roti / Butter Rumali Roti': 2 options (Plain / Butter) vs 2 printed price(s) 130.00 / 150.00
--   - W / B (category 'GRILL SANDWICH W / B') read as White Bread / Brown Bread; raw label kept in variant_code
--   - R / L (SIZZLER prices) read as Regular / Large; raw label kept in variant_code
--
-- Rows needing review / confidence < 0.80 are listed in the first trailing comment block (0 item row(s), 21 price row(s)); restaurant-level notes with no schema column are in the second block.

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
    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400086002)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400086002)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 400086002)
       OR EXISTS (SELECT 1 FROM menu_item WHERE restaurant_id = 400086002)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400086002 AND source_id = 400086002) THEN
        RAISE EXCEPTION 'Restaurant 400086002 is already loaded; aborting so menu items are not duplicated.';
    END IF;
    SELECT string_agg(n.code, ', ') INTO v_missing
    FROM (VALUES ('PURE_VEG'), ('JAIN_AVAILABLE')) AS n(code)
    WHERE NOT EXISTS (SELECT 1 FROM platform_tag t WHERE t.tag_code = n.code);
    IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'Missing platform_tag lookup row(s): %', v_missing; END IF;
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
SELECT COALESCE(MAX(restaurant_tag_id), 0) AS base_rtag FROM restaurant_tag \gset

-- ----------------------------------------------------------------------------
-- 2. BRAND / ESTABLISHMENT / RESTAURANT / SOURCE / EXTRACTION BATCH
-- ----------------------------------------------------------------------------
-- brand 100002 is given in the JSON; created only if absent (name and website from the JSON, nothing else invented)
INSERT INTO brand (brand_id, name, normalized_name, website_url)
SELECT 100002, 'THE FOOD TOWN', 'the food town', 'www.thefoodtown.in'
WHERE NOT EXISTS (SELECT 1 FROM brand WHERE brand_id = 100002);

INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2, locality, city, state,
                           postal_code, website_url, instagram_handle, facebook_handle, latitude, longitude)
VALUES (400086002, 'THE FOOD TOWN', 'the food town', 'Shop 4, Neelkanth Corporate It Park, Kirol Rd', 'Vidyavihar West',
        'Ghatkopar', 'Mumbai', 'Maharashtra', '400086', 'www.thefoodtown.in', 'the_food_town', '@thefoodtown21',
        19.08216215321913, 72.89545093358028);

INSERT INTO restaurant (restaurant_id, establishment_id, brand_id, display_name, normalized_name, veg_nonveg_status,
                        has_bar, bar_license_type)
VALUES (400086002, 400086002, 100002, 'THE FOOD TOWN', 'the food town', 'pure_veg', FALSE, 'none');
INSERT INTO source_record (source_id, source_type_code, external_reference)
VALUES (400086002, 'ai_menu_extraction', 'The_Food_Town_Menu_OCR.json');
INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at,
                                   status_code, overall_confidence)
VALUES ((:base_batch + 1), 400086002, 400086002, (clock_timestamp() AT TIME ZONE 'UTC'),
        (clock_timestamp() AT TIME ZONE 'UTC'), 'completed', 0.95000);
-- overall_confidence = mean of the menu_item_source confidences below

-- ----------------------------------------------------------------------------
-- 3. PHONES / HOURS / TAGS / SERVICE MODES
-- ----------------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (:base_phone + 1, 400086002, '8433843335', TRUE);
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (:base_hours + 1, 400086002, 1, 1, TIME '11:30', TIME '23:30'),
    (:base_hours + 2, 400086002, 2, 1, TIME '11:30', TIME '23:30'),
    (:base_hours + 3, 400086002, 3, 1, TIME '11:30', TIME '23:30'),
    (:base_hours + 4, 400086002, 4, 1, TIME '11:30', TIME '23:30'),
    (:base_hours + 5, 400086002, 5, 1, TIME '11:30', TIME '23:30'),
    (:base_hours + 6, 400086002, 6, 1, TIME '11:30', TIME '23:30'),
    (:base_hours + 7, 400086002, 7, 1, TIME '11:30', TIME '23:30');
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
SELECT :base_rtag + row_number() OVER (ORDER BY t.tag_id), 400086002, t.tag_id, TRUE
FROM platform_tag t WHERE t.tag_code IN ('PURE_VEG', 'JAIN_AVAILABLE');
INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT 400086002, m.service_mode_id, TRUE, v.notes
FROM (VALUES
    ('delivery', 'JSON free_delivery: "2km, minimum order 250"')
) AS v(code, notes)
JOIN service_mode m ON m.code = v.code;

-- ----------------------------------------------------------------------------
-- 4. CANONICAL DISHES - 340 keys; inserted only where no exact normalized-name match exists
-- ----------------------------------------------------------------------------
WITH src (seq, canonical_name, normalized_name, food_classification_code, protein_code,
          is_jain, is_vegan, is_eggless) AS (
    VALUES
    (1, 'Manchow Soup', 'manchow soup', 'veg', NULL, NULL, NULL, TRUE),
    (2, 'Lemon Coriander Soup', 'lemon coriander soup', 'veg', NULL, NULL, NULL, TRUE),
    (3, 'Xiaolong Dumpling Soup', 'xiaolong dumpling soup', 'veg', NULL, NULL, NULL, TRUE),
    (4, 'Burn Garlic Soup', 'burn garlic soup', 'veg', NULL, FALSE, NULL, TRUE),
    (5, 'Ministrone Soup', 'ministrone soup', 'veg', NULL, NULL, NULL, TRUE),
    (6, 'Veg Talumain Soup', 'veg talumain soup', 'veg', NULL, NULL, NULL, TRUE),
    (7, 'TFT Spl. Soup', 'tft spl. soup', 'veg', NULL, NULL, NULL, TRUE),
    (8, 'Mexican Tacos Soup', 'mexican tacos soup', 'veg', NULL, NULL, NULL, TRUE),
    (9, 'Tom Yum Soup', 'tom yum soup', 'veg', NULL, NULL, NULL, TRUE),
    (10, 'Roasted Corn Soup', 'roasted corn soup', 'veg', NULL, NULL, NULL, TRUE),
    (11, 'Baby Corn Broccoli Soup', 'baby corn broccoli soup', 'veg', NULL, NULL, NULL, TRUE),
    (12, 'Cream of Mushroom Soup', 'cream of mushroom soup', 'veg', NULL, FALSE, FALSE, TRUE),
    (13, 'Roasted Almond Broccoli Soup', 'roasted almond broccoli soup', 'veg', NULL, NULL, NULL, TRUE),
    (14, 'Cream of Tomato Soup', 'cream of tomato soup', 'veg', NULL, NULL, FALSE, TRUE),
    (15, 'Crunchy Corn Soup', 'crunchy corn soup', 'veg', NULL, NULL, NULL, TRUE),
    (16, 'Tomato Shorba', 'tomato shorba', 'veg', NULL, NULL, NULL, TRUE),
    (17, 'Broccoli Shorba', 'broccoli shorba', 'veg', NULL, NULL, NULL, TRUE),
    (18, 'Green Garden Salad', 'green garden salad', 'veg', NULL, NULL, TRUE, TRUE),
    (19, 'Hot Saute Salad', 'hot saute salad', 'veg', NULL, NULL, NULL, TRUE),
    (20, 'Ceaser Salad', 'ceaser salad', 'veg', NULL, NULL, NULL, TRUE),
    (21, 'Chef Spl Salad', 'chef spl salad', 'veg', NULL, NULL, NULL, TRUE),
    (22, 'Tandoori Potato Honey Mustard Salad', 'tandoori potato honey mustard salad', 'veg', NULL, FALSE, NULL, TRUE),
    (23, 'French Fries', 'french fries', 'veg', NULL, NULL, NULL, TRUE),
    (24, 'Cheese French', 'cheese french', 'veg', NULL, NULL, FALSE, TRUE),
    (25, 'Peri Peri Fries', 'peri peri fries', 'veg', NULL, NULL, NULL, TRUE),
    (26, 'Mexican French Fries', 'mexican french fries', 'veg', NULL, NULL, NULL, TRUE),
    (27, 'Chilli French Fries', 'chilli french fries', 'veg', NULL, NULL, NULL, TRUE),
    (28, 'Cheese Nachos', 'cheese nachos', 'veg', NULL, NULL, FALSE, TRUE),
    (29, 'Nachos Corn Queso', 'nachos corn queso', 'veg', NULL, NULL, NULL, TRUE),
    (30, 'Loaded U.S Nachos', 'loaded u.s nachos', 'veg', NULL, NULL, NULL, TRUE),
    (31, 'Mexican Nachos', 'mexican nachos', 'veg', NULL, NULL, NULL, TRUE),
    (32, 'Paneer Chilli Bao', 'paneer chilli bao', 'veg', NULL, NULL, FALSE, TRUE),
    (33, 'Celandtro Cottage Cheese Bao', 'celandtro cottage cheese bao', 'veg', NULL, NULL, FALSE, TRUE),
    (34, 'Kung - Pao Mushroom Bao', 'kung - pao mushroom bao', 'veg', NULL, FALSE, NULL, TRUE),
    (35, 'Mexican Bao', 'mexican bao', 'veg', NULL, NULL, NULL, TRUE),
    (36, 'Paneer, Thai Basil', 'paneer, thai basil', 'veg', NULL, NULL, FALSE, TRUE),
    (37, 'Cheese Garlic Bread', 'cheese garlic bread', 'veg', NULL, FALSE, FALSE, TRUE),
    (38, 'Corn Cheese Garlic', 'corn cheese garlic', 'veg', NULL, FALSE, FALSE, TRUE),
    (39, 'Chilli Cheese Garlic', 'chilli cheese garlic', 'veg', NULL, FALSE, FALSE, TRUE),
    (40, 'Schezwan Paneer Garlic', 'schezwan paneer garlic', 'veg', NULL, FALSE, FALSE, TRUE),
    (41, 'Melting Chilli Garlic', 'melting chilli garlic', 'veg', NULL, FALSE, NULL, TRUE),
    (42, 'Stuff Garlic Bread', 'stuff garlic bread', 'veg', NULL, FALSE, NULL, TRUE),
    (43, 'Assorted Garlic Bread', 'assorted garlic bread', 'veg', NULL, FALSE, NULL, TRUE),
    (44, 'Cheese Montezza', 'cheese montezza', 'veg', NULL, NULL, FALSE, TRUE),
    (45, 'French Masala Roll', 'french masala roll', 'veg', NULL, NULL, NULL, TRUE),
    (46, 'Cheese Chilly Toast', 'cheese chilly toast', 'veg', NULL, NULL, FALSE, TRUE),
    (47, 'Bruschetta', 'bruschetta', 'veg', NULL, NULL, NULL, TRUE),
    (48, 'Cheezo Blast', 'cheezo blast', 'veg', NULL, NULL, FALSE, TRUE),
    (49, 'Garlic Avacado Toast', 'garlic avacado toast', 'veg', NULL, FALSE, NULL, TRUE),
    (50, 'Melting Grill', 'melting grill', 'veg', NULL, NULL, NULL, TRUE),
    (51, 'TFT Spl. Grill', 'tft spl. grill', 'veg', NULL, NULL, NULL, TRUE),
    (52, 'Paneer Chilli Grill', 'paneer chilli grill', 'veg', NULL, NULL, FALSE, TRUE),
    (53, 'Veg Cheese Grill', 'veg cheese grill', 'veg', NULL, NULL, FALSE, TRUE),
    (54, 'Bombay Grill', 'bombay grill', 'veg', NULL, NULL, NULL, TRUE),
    (55, 'Paneer Tikka Grill', 'paneer tikka grill', 'veg', NULL, NULL, FALSE, TRUE),
    (56, 'Marina Grill', 'marina grill', 'veg', NULL, NULL, NULL, TRUE),
    (57, 'Super Grill', 'super grill', 'veg', NULL, NULL, NULL, TRUE),
    (58, 'Cheese Burst Pizza', 'cheese burst pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (59, 'Peppy Paneer Pizza', 'peppy paneer pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (60, 'Garden Pizza', 'garden pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (61, 'Farmer Pizza', 'farmer pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (62, 'Mexican Pizza', 'mexican pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (63, 'Aioli Pizza', 'aioli pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (64, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (65, 'Bombay Pizza', 'bombay pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (66, 'Paneer Basil Pizza', 'paneer basil pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (67, '4 in 1 Pizza', '4 in 1 pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (68, 'Margherita Pizza', 'margherita pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (69, 'Smoky BBQ Pizza', 'smoky bbq pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (70, 'Oriental Paneer Pizza', 'oriental paneer pizza', 'veg', NULL, NULL, FALSE, TRUE),
    (71, 'Alfredo Pasta', 'alfredo pasta', 'veg', NULL, NULL, FALSE, TRUE),
    (72, 'Arrabiata Pasta', 'arrabiata pasta', 'veg', NULL, NULL, NULL, TRUE),
    (73, 'Pink Tango Pasta', 'pink tango pasta', 'veg', NULL, NULL, FALSE, TRUE),
    (74, '4 Cheese Pasta', '4 cheese pasta', 'veg', NULL, NULL, FALSE, TRUE),
    (75, 'Creamy Pesto Pasta', 'creamy pesto pasta', 'veg', NULL, NULL, FALSE, TRUE),
    (76, 'Creamy Fungi Pasta', 'creamy fungi pasta', 'veg', NULL, FALSE, FALSE, TRUE),
    (77, 'Aglio Olio Spaghetti', 'aglio olio spaghetti', 'veg', NULL, NULL, NULL, TRUE),
    (78, 'Ravioli Pasta', 'ravioli pasta', 'veg', NULL, NULL, NULL, TRUE),
    (79, 'Tortellini Pasta', 'tortellini pasta', 'veg', NULL, NULL, NULL, TRUE),
    (80, 'Cheese Fondue', 'cheese fondue', 'veg', NULL, NULL, FALSE, TRUE),
    (81, 'Veg Cheese Fondue', 'veg cheese fondue', 'veg', NULL, NULL, FALSE, TRUE),
    (82, 'Pav Bhaji Fondue', 'pav bhaji fondue', 'veg', NULL, FALSE, FALSE, TRUE),
    (83, 'Thai Fondue', 'thai fondue', 'veg', NULL, NULL, FALSE, TRUE),
    (84, 'Extra Fondue Bread', 'extra fondue bread', 'veg', NULL, NULL, FALSE, TRUE),
    (85, 'Hummus Dip Platter', 'hummus dip platter', 'veg', NULL, FALSE, NULL, TRUE),
    (86, 'Falafel Bites', 'falafel bites', 'veg', NULL, NULL, NULL, TRUE),
    (87, 'Assorted Lebanese Platter', 'assorted lebanese platter', 'veg', NULL, NULL, NULL, TRUE),
    (88, 'Falafel Sandwich', 'falafel sandwich', 'veg', NULL, NULL, NULL, TRUE),
    (89, 'Asparagus Tempura Sushi', 'asparagus tempura sushi', 'veg', NULL, NULL, FALSE, TRUE),
    (90, 'California Veg.Roll Sushi', 'california veg.roll sushi', 'veg', NULL, NULL, FALSE, TRUE),
    (91, 'Maki Roll', 'maki roll', 'veg', NULL, NULL, FALSE, TRUE),
    (92, 'Babycorn Tempura Roll', 'babycorn tempura roll', 'veg', NULL, NULL, FALSE, TRUE),
    (93, 'Avocado & Cream Cheese Sushi', 'avocado & cream cheese sushi', 'veg', NULL, NULL, FALSE, TRUE),
    (94, 'Asparagus Cream Cheese Sushi', 'asparagus cream cheese sushi', 'veg', NULL, NULL, FALSE, TRUE),
    (95, 'Mexican Style Sushi', 'mexican style sushi', 'veg', NULL, NULL, FALSE, TRUE),
    (96, 'Pav Bhaji', 'pav bhaji', 'veg', NULL, FALSE, NULL, TRUE),
    (97, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'veg', NULL, FALSE, FALSE, TRUE),
    (98, 'Jain Pav Bhaji', 'jain pav bhaji', 'veg', NULL, TRUE, NULL, TRUE),
    (99, 'Soya Keema Pav', 'soya keema pav', 'veg', NULL, NULL, NULL, TRUE),
    (100, 'Masala Pav', 'masala pav', 'veg', NULL, NULL, NULL, TRUE),
    (101, 'Hariyali Pav Bhaji', 'hariyali pav bhaji', 'veg', NULL, FALSE, NULL, TRUE),
    (102, 'Italian Pav Bhaji', 'italian pav bhaji', 'veg', NULL, FALSE, NULL, TRUE),
    (103, 'Extra Butter Pav', 'extra butter pav', 'veg', NULL, NULL, FALSE, TRUE),
    (104, 'Plain Pav', 'plain pav', 'veg', NULL, NULL, NULL, TRUE),
    (105, 'Medu Vada with Thai Curry', 'medu vada with thai curry', 'veg', NULL, NULL, NULL, TRUE),
    (106, 'Chole Bhature', 'chole bhature', 'veg', NULL, NULL, NULL, TRUE),
    (107, 'Chinese Bhel', 'chinese bhel', 'veg', NULL, NULL, NULL, TRUE),
    (108, 'Mexican Bhel', 'mexican bhel', 'veg', NULL, NULL, NULL, TRUE),
    (109, 'Corn Cheese Bhel', 'corn cheese bhel', 'veg', NULL, NULL, FALSE, TRUE),
    (110, 'Pav Bhaji Bunny Chow', 'pav bhaji bunny chow', 'veg', NULL, FALSE, NULL, TRUE),
    (111, 'Soya Keema Bunny Chow', 'soya keema bunny chow', 'veg', NULL, NULL, NULL, TRUE),
    (112, 'Cheese Cigar', 'cheese cigar', 'veg', NULL, NULL, FALSE, TRUE),
    (113, 'Mushroom Cheese Stuff', 'mushroom cheese stuff', 'veg', NULL, FALSE, FALSE, TRUE),
    (114, 'Paneer Pattaya', 'paneer pattaya', 'veg', NULL, NULL, FALSE, TRUE),
    (115, 'Butter Garlic Paneer', 'butter garlic paneer', 'veg', NULL, FALSE, FALSE, TRUE),
    (116, 'Cheese Marble', 'cheese marble', 'veg', NULL, NULL, FALSE, TRUE),
    (117, 'Paneer Lemon Coriander', 'paneer lemon coriander', 'veg', NULL, NULL, FALSE, TRUE),
    (118, 'Paneer Chilli Dry', 'paneer chilli dry', 'veg', NULL, NULL, FALSE, TRUE),
    (119, 'Veg Crispy', 'veg crispy', 'veg', NULL, NULL, NULL, TRUE),
    (120, 'Paneer Satay', 'paneer satay', 'veg', NULL, NULL, FALSE, TRUE),
    (121, 'Manchurian Chilli Dry', 'manchurian chilli dry', 'veg', NULL, NULL, NULL, TRUE),
    (122, 'Paneer Hot Dragon', 'paneer hot dragon', 'veg', NULL, NULL, FALSE, TRUE),
    (123, 'Kung Pao (Paneer / Mushroom)', 'kung pao (paneer / mushroom)', 'veg', NULL, NULL, FALSE, TRUE),
    (124, 'Paneer Red Pepper', 'paneer red pepper', 'veg', NULL, NULL, FALSE, TRUE),
    (125, 'Thai Basil Paneer', 'thai basil paneer', 'veg', NULL, NULL, FALSE, TRUE),
    (126, 'Paneer Shanghai', 'paneer shanghai', 'veg', NULL, NULL, FALSE, TRUE),
    (127, 'Lotus Stem Crispy', 'lotus stem crispy', 'veg', NULL, NULL, NULL, TRUE),
    (128, 'Cheese Croquettes in Siracha Sauce', 'cheese croquettes in siracha sauce', 'veg', NULL, NULL, FALSE, TRUE),
    (129, 'Mushroom Chilli Dry', 'mushroom chilli dry', 'veg', NULL, FALSE, NULL, TRUE),
    (130, 'Paneer ABC', 'paneer abc', 'veg', NULL, NULL, FALSE, TRUE),
    (131, 'Paneer Shole Tikka', 'paneer shole tikka', 'veg', NULL, NULL, FALSE, TRUE),
    (132, 'Paneer Hill Top', 'paneer hill top', 'veg', NULL, NULL, FALSE, TRUE),
    (133, 'Paneer Tikka', 'paneer tikka', 'veg', NULL, NULL, FALSE, TRUE),
    (134, 'Galouti Kebab', 'galouti kebab', 'veg', NULL, NULL, NULL, TRUE),
    (135, 'Paneer Firangi', 'paneer firangi', 'veg', NULL, NULL, FALSE, TRUE),
    (136, 'Paneer Lasooni Tikka', 'paneer lasooni tikka', 'veg', NULL, FALSE, FALSE, TRUE),
    (137, 'Paneer Afgani Tikka', 'paneer afgani tikka', 'veg', NULL, NULL, FALSE, TRUE),
    (138, 'Paneer Rangrez', 'paneer rangrez', 'veg', NULL, NULL, FALSE, TRUE),
    (139, 'Mushroom Tikka', 'mushroom tikka', 'veg', NULL, FALSE, NULL, TRUE),
    (140, 'Veg Seekh Kebab', 'veg seekh kebab', 'veg', NULL, NULL, NULL, TRUE),
    (141, 'Banjara Seekh Kebab', 'banjara seekh kebab', 'veg', NULL, NULL, NULL, TRUE),
    (142, 'TFT Spl Tikka', 'tft spl tikka', 'veg', NULL, NULL, NULL, TRUE),
    (143, 'Paneer Malai Tikka', 'paneer malai tikka', 'veg', NULL, NULL, FALSE, TRUE),
    (144, 'Paneer Achari', 'paneer achari', 'veg', NULL, NULL, FALSE, TRUE),
    (145, 'Bhatti Wale Aloo', 'bhatti wale aloo', 'veg', NULL, FALSE, NULL, TRUE),
    (146, 'Hara Bhara Kebab', 'hara bhara kebab', 'veg', NULL, NULL, NULL, TRUE),
    (147, 'Kaju Methi Roll', 'kaju methi roll', 'veg', NULL, NULL, NULL, TRUE),
    (148, 'Pahadi Aloo Kothi Wale', 'pahadi aloo kothi wale', 'veg', NULL, FALSE, NULL, TRUE),
    (149, 'Subz Kurkure Tikki', 'subz kurkure tikki', 'veg', NULL, NULL, NULL, TRUE),
    (150, 'Assorted Tandoor Platter', 'assorted tandoor platter', 'veg', NULL, NULL, NULL, TRUE),
    (151, '4 Cheese Risotto', '4 cheese risotto', 'veg', NULL, NULL, FALSE, TRUE),
    (152, 'Pesto Risotto', 'pesto risotto', 'veg', NULL, NULL, NULL, TRUE),
    (153, 'Tomato Basil Risotto', 'tomato basil risotto', 'veg', NULL, NULL, NULL, TRUE),
    (154, 'Creamy Fungi Risotto', 'creamy fungi risotto', 'veg', NULL, FALSE, FALSE, TRUE),
    (155, 'Pink Tango Risotto', 'pink tango risotto', 'veg', NULL, NULL, FALSE, TRUE),
    (156, 'Mexican Sizzler', 'mexican sizzler', 'veg', NULL, NULL, NULL, TRUE),
    (157, 'Oriental Sizzler', 'oriental sizzler', 'veg', NULL, NULL, NULL, TRUE),
    (158, 'Paneer Shashlik Sizzler', 'paneer shashlik sizzler', 'veg', NULL, NULL, FALSE, TRUE),
    (159, 'Pav Bhaji Sizzler', 'pav bhaji sizzler', 'veg', NULL, FALSE, NULL, TRUE),
    (160, 'Veg Pepper Sizzler', 'veg pepper sizzler', 'veg', NULL, NULL, NULL, TRUE),
    (161, 'Mushroom Pepper Sizzler', 'mushroom pepper sizzler', 'veg', NULL, FALSE, NULL, TRUE),
    (162, 'European Sizzler', 'european sizzler', 'veg', NULL, NULL, NULL, TRUE),
    (163, 'Paneer Chilli Sizzler', 'paneer chilli sizzler', 'veg', NULL, NULL, FALSE, TRUE),
    (164, 'Tandoori Momos Sizzler', 'tandoori momos sizzler', 'veg', NULL, NULL, NULL, TRUE),
    (165, 'Thai Sizzler', 'thai sizzler', 'veg', NULL, NULL, NULL, TRUE),
    (166, 'Garlic Coriander Sizzler', 'garlic coriander sizzler', 'veg', NULL, FALSE, NULL, TRUE),
    (167, 'Hot Garlic Sizzler', 'hot garlic sizzler', 'veg', NULL, FALSE, NULL, TRUE),
    (168, 'TFT Special Rice', 'tft special rice', 'veg', NULL, NULL, NULL, TRUE),
    (169, 'Thai Pot Rice', 'thai pot rice', 'veg', NULL, NULL, NULL, TRUE),
    (170, 'Paneer Chilli Rice', 'paneer chilli rice', 'veg', NULL, NULL, FALSE, TRUE),
    (171, 'Korean Rice', 'korean rice', 'veg', NULL, NULL, NULL, TRUE),
    (172, 'Manchurian Rice', 'manchurian rice', 'veg', NULL, NULL, NULL, TRUE),
    (173, 'Mexican Pot Rice', 'mexican pot rice', 'veg', NULL, NULL, NULL, TRUE),
    (174, 'Triple Schezwan Rice', 'triple schezwan rice', 'veg', NULL, NULL, NULL, TRUE),
    (175, 'Hot Garlic Rice', 'hot garlic rice', 'veg', NULL, FALSE, NULL, TRUE),
    (176, 'Burrito Bowl', 'burrito bowl', 'veg', NULL, NULL, NULL, TRUE),
    (177, 'Burmese Khow Suey', 'burmese khow suey', 'veg', NULL, NULL, NULL, TRUE),
    (178, 'Thousand Rice', 'thousand rice', 'veg', NULL, NULL, NULL, TRUE),
    (179, 'Fried Rice', 'fried rice', 'veg', NULL, NULL, NULL, TRUE),
    (180, 'Schezwan Rice', 'schezwan rice', 'veg', NULL, NULL, NULL, TRUE),
    (181, 'Burn Garlic Rice', 'burn garlic rice', 'veg', NULL, FALSE, NULL, TRUE),
    (182, 'Chilli Garlic Rice', 'chilli garlic rice', 'veg', NULL, FALSE, NULL, TRUE),
    (183, 'Combination Rice', 'combination rice', 'veg', NULL, NULL, NULL, TRUE),
    (184, 'Exotic Rice', 'exotic rice', 'veg', NULL, NULL, NULL, TRUE),
    (185, 'Hong Kong Rice', 'hong kong rice', 'veg', NULL, NULL, NULL, TRUE),
    (186, 'Singapuri Rice', 'singapuri rice', 'veg', NULL, NULL, NULL, TRUE),
    (187, 'Thai Basil / Oregano Rice', 'thai basil / oregano rice', 'veg', NULL, NULL, NULL, TRUE),
    (188, 'Thai Coriander / Garlic Rice', 'thai coriander / garlic rice', 'veg', NULL, NULL, NULL, TRUE),
    (189, 'Veg Hakka Noodles', 'veg hakka noodles', 'veg', NULL, NULL, NULL, TRUE),
    (190, 'Schezwan Noodles', 'schezwan noodles', 'veg', NULL, NULL, NULL, TRUE),
    (191, 'Chilli Garlic Noodles', 'chilli garlic noodles', 'veg', NULL, FALSE, NULL, TRUE),
    (192, 'Burn Garlic Noodles', 'burn garlic noodles', 'veg', NULL, FALSE, NULL, TRUE),
    (193, 'Hong Kong Noodles', 'hong kong noodles', 'veg', NULL, NULL, NULL, TRUE),
    (194, 'Singapuri Noodles', 'singapuri noodles', 'veg', NULL, NULL, NULL, TRUE),
    (195, 'Triple Schezwan Noodles', 'triple schezwan noodles', 'veg', NULL, NULL, NULL, TRUE),
    (196, 'Paneer Chilli Noodles', 'paneer chilli noodles', 'veg', NULL, NULL, FALSE, TRUE),
    (197, 'TFT Spl Noodles', 'tft spl noodles', 'veg', NULL, NULL, NULL, TRUE),
    (198, 'Thousand Noodles', 'thousand noodles', 'veg', NULL, NULL, NULL, TRUE),
    (199, 'Korean Noodles', 'korean noodles', 'veg', NULL, NULL, NULL, TRUE),
    (200, 'Hot Garlic Gravy', 'hot garlic gravy', 'veg', NULL, FALSE, FALSE, TRUE),
    (201, 'Thai Curry', 'thai curry', 'veg', NULL, NULL, NULL, TRUE),
    (202, 'Peri Peri Curry', 'peri peri curry', 'veg', NULL, NULL, NULL, TRUE),
    (203, 'Paneer Chilli Gravy', 'paneer chilli gravy', 'veg', NULL, NULL, FALSE, TRUE),
    (204, 'Manchurian Chilli Gravy', 'manchurian chilli gravy', 'veg', NULL, NULL, NULL, TRUE),
    (205, 'Basil Chilli Gravy', 'basil chilli gravy', 'veg', NULL, NULL, NULL, TRUE),
    (206, 'Kung Pao Gravy', 'kung pao gravy', 'veg', NULL, NULL, FALSE, TRUE),
    (207, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL, NULL, FALSE, TRUE),
    (208, 'Paneer Makhmali', 'paneer makhmali', 'veg', NULL, NULL, FALSE, TRUE),
    (209, 'Kadai Paneer', 'kadai paneer', 'veg', NULL, NULL, FALSE, TRUE),
    (210, 'Palak Paneer', 'palak paneer', 'veg', NULL, NULL, FALSE, TRUE),
    (211, 'Paneer Lahori', 'paneer lahori', 'veg', NULL, NULL, FALSE, TRUE),
    (212, 'Paneer Mutter Masala', 'paneer mutter masala', 'veg', NULL, NULL, FALSE, TRUE),
    (213, 'Paneer Bali Amritsari', 'paneer bali amritsari', 'veg', NULL, NULL, FALSE, TRUE),
    (214, 'Paneer Butter Masala', 'paneer butter masala', 'veg', NULL, NULL, FALSE, TRUE),
    (215, 'Paneer Malai Kofta', 'paneer malai kofta', 'veg', NULL, NULL, FALSE, TRUE),
    (216, 'Paneer Khurchan', 'paneer khurchan', 'veg', NULL, NULL, FALSE, TRUE),
    (217, 'Paneer Parat', 'paneer parat', 'veg', NULL, NULL, FALSE, TRUE),
    (218, 'Paneer Mumtaz', 'paneer mumtaz', 'veg', NULL, NULL, FALSE, TRUE),
    (219, 'Paneer Pahadi Tikka Masala', 'paneer pahadi tikka masala', 'veg', NULL, NULL, FALSE, TRUE),
    (220, 'Paneer Lababdar', 'paneer lababdar', 'veg', NULL, NULL, FALSE, TRUE),
    (221, 'Paneer Lazeez', 'paneer lazeez', 'veg', NULL, NULL, FALSE, TRUE),
    (222, 'Paneer Angaara', 'paneer angaara', 'veg', NULL, NULL, FALSE, TRUE),
    (223, 'Paneer Nawabi', 'paneer nawabi', 'veg', NULL, NULL, FALSE, TRUE),
    (224, 'Paneer Bhuna Masala', 'paneer bhuna masala', 'veg', NULL, NULL, FALSE, TRUE),
    (225, 'Kaju Paneer Masala', 'kaju paneer masala', 'veg', NULL, NULL, FALSE, TRUE),
    (226, 'Veg Kolhapuri', 'veg kolhapuri', 'veg', NULL, NULL, NULL, TRUE),
    (227, 'Veg Kadai', 'veg kadai', 'veg', NULL, NULL, NULL, TRUE),
    (228, 'Veg Keema Masala', 'veg keema masala', 'veg', NULL, NULL, NULL, TRUE),
    (229, 'Sabz Bageecha', 'sabz bageecha', 'veg', NULL, NULL, NULL, TRUE),
    (230, 'Veg Angaara', 'veg angaara', 'veg', NULL, NULL, NULL, TRUE),
    (231, 'Lal ka Sabz', 'lal ka sabz', 'veg', NULL, NULL, NULL, TRUE),
    (232, 'Sabz Makhmali', 'sabz makhmali', 'veg', NULL, NULL, FALSE, TRUE),
    (233, 'Sunehri Chandan', 'sunehri chandan', 'veg', NULL, NULL, NULL, TRUE),
    (234, 'Exotic Bhuna Masala', 'exotic bhuna masala', 'veg', NULL, NULL, NULL, TRUE),
    (235, 'Bhatti Wale Aloo Masala', 'bhatti wale aloo masala', 'veg', NULL, FALSE, NULL, TRUE),
    (236, 'Nargisi Kofta', 'nargisi kofta', 'veg', NULL, NULL, NULL, TRUE),
    (237, 'Kaju Masala', 'kaju masala', 'veg', NULL, NULL, NULL, TRUE),
    (238, 'Sabz Kasturi', 'sabz kasturi', 'veg', NULL, NULL, NULL, TRUE),
    (239, 'Banjara Seekh Masala', 'banjara seekh masala', 'veg', NULL, NULL, NULL, TRUE),
    (240, 'Sabz Chat Pata', 'sabz chat pata', 'veg', NULL, NULL, NULL, TRUE),
    (241, 'Mushroom Tikka Masala', 'mushroom tikka masala', 'veg', NULL, FALSE, NULL, TRUE),
    (242, 'Sham Savera', 'sham savera', 'veg', NULL, NULL, NULL, TRUE),
    (243, 'Veg Lasooni Masala', 'veg lasooni masala', 'veg', NULL, FALSE, NULL, TRUE),
    (244, 'Methi Mutter Malai', 'methi mutter malai', 'veg', NULL, NULL, FALSE, TRUE),
    (245, 'Veg Makhanwala', 'veg makhanwala', 'veg', NULL, NULL, FALSE, TRUE),
    (246, 'Sabz Chilli Milly', 'sabz chilli milly', 'veg', NULL, NULL, NULL, TRUE),
    (247, 'Sabz Myra', 'sabz myra', 'veg', NULL, NULL, NULL, TRUE),
    (248, 'Veg Lucknowi Kofta', 'veg lucknowi kofta', 'veg', NULL, NULL, NULL, TRUE),
    (249, 'Navratan Korma', 'navratan korma', 'veg', NULL, NULL, NULL, TRUE),
    (250, 'Aloo Mutter Methi', 'aloo mutter methi', 'veg', NULL, FALSE, NULL, TRUE),
    (251, 'Tandoori Roti / Butter Roti', 'tandoori roti / butter roti', 'veg', NULL, NULL, FALSE, TRUE),
    (252, 'Naan / Butter Naan', 'naan / butter naan', 'veg', NULL, NULL, FALSE, TRUE),
    (253, 'Garlic Naan / Garlic Butter Naan', 'garlic naan / garlic butter naan', 'veg', NULL, NULL, FALSE, TRUE),
    (254, 'Cheese Naan / Garlic Cheese Naan', 'cheese naan / garlic cheese naan', 'veg', NULL, NULL, FALSE, TRUE),
    (255, 'Pizza Naan (Spl)', 'pizza naan (spl)', 'veg', NULL, NULL, FALSE, TRUE),
    (256, 'Plain Lachha Paratha / Butter Lachha Paratha', 'plain lachha paratha / butter lachha paratha', 'veg', NULL, NULL, FALSE, TRUE),
    (257, 'Pudina Paratha / Naan / Kulcha', 'pudina paratha / naan / kulcha', 'veg', NULL, NULL, NULL, TRUE),
    (258, 'Ajwain Paratha / Naan / Kulcha', 'ajwain paratha / naan / kulcha', 'veg', NULL, NULL, NULL, TRUE),
    (259, 'Methi Paratha / Naan / Kulcha', 'methi paratha / naan / kulcha', 'veg', NULL, NULL, NULL, TRUE),
    (260, 'Kulcha / Butter Kulcha', 'kulcha / butter kulcha', 'veg', NULL, NULL, FALSE, TRUE),
    (261, 'Stuff Paneer Kulcha / Stuff Cheese Kulcha', 'stuff paneer kulcha / stuff cheese kulcha', 'veg', NULL, NULL, FALSE, TRUE),
    (262, 'Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg.', 'kulcha stuffing-: aloo, gobi, onion or mix veg.', 'veg', NULL, NULL, NULL, TRUE),
    (263, 'Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg.', 'stuffed paratha-: aloo, gobi, onion or mix veg.', 'veg', NULL, NULL, NULL, TRUE),
    (264, 'Makai Roti / Bajra Roti / Missi Roti / Garlic Roti', 'makai roti / bajra roti / missi roti / garlic roti', 'veg', NULL, NULL, NULL, TRUE),
    (265, 'Extra Bhature', 'extra bhature', 'veg', NULL, NULL, NULL, TRUE),
    (266, 'Plain Rumali Roti / Butter Rumali Roti', 'plain rumali roti / butter rumali roti', 'veg', NULL, NULL, FALSE, TRUE),
    (267, 'Roti Ki Tokri (7 Types of Roti)', 'roti ki tokri (7 types of roti)', 'veg', NULL, NULL, NULL, TRUE),
    (268, 'Steam Rice', 'steam rice', 'veg', NULL, NULL, TRUE, TRUE),
    (269, 'Jeera Rice', 'jeera rice', 'veg', NULL, NULL, NULL, TRUE),
    (270, 'Dal Khichdi', 'dal khichdi', 'veg', NULL, NULL, NULL, TRUE),
    (271, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'veg', NULL, NULL, NULL, TRUE),
    (272, 'Palak Khichdi', 'palak khichdi', 'veg', NULL, NULL, NULL, TRUE),
    (273, 'Veg Pulav', 'veg pulav', 'veg', NULL, NULL, NULL, TRUE),
    (274, 'Kashmiri Pulav', 'kashmiri pulav', 'veg', NULL, NULL, NULL, TRUE),
    (275, 'Tawa Pulav', 'tawa pulav', 'veg', NULL, NULL, NULL, TRUE),
    (276, 'Curd Rice', 'curd rice', 'veg', NULL, NULL, FALSE, TRUE),
    (277, 'Dal Fry', 'dal fry', 'veg', NULL, NULL, NULL, TRUE),
    (278, 'Dal Tadkewali', 'dal tadkewali', 'veg', NULL, NULL, NULL, TRUE),
    (279, 'Dal Makhani', 'dal makhani', 'veg', NULL, NULL, FALSE, TRUE),
    (280, 'Punjabi Kadi Pakodewali', 'punjabi kadi pakodewali', 'veg', NULL, NULL, FALSE, TRUE),
    (281, 'Dal Bukhara', 'dal bukhara', 'veg', NULL, NULL, NULL, TRUE),
    (282, 'Methi Wali Dal', 'methi wali dal', 'veg', NULL, NULL, NULL, TRUE),
    (283, 'Palak Wali Dal', 'palak wali dal', 'veg', NULL, NULL, NULL, TRUE),
    (284, 'Veg Biryani', 'veg biryani', 'veg', NULL, NULL, NULL, TRUE),
    (285, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'veg', NULL, NULL, FALSE, TRUE),
    (286, 'Afghani Tikka Biryani', 'afghani tikka biryani', 'veg', NULL, NULL, NULL, TRUE),
    (287, 'Soya Keema Biryani', 'soya keema biryani', 'veg', NULL, NULL, NULL, TRUE),
    (288, 'Kali Handi Dum Biryani', 'kali handi dum biryani', 'veg', NULL, NULL, NULL, TRUE),
    (289, 'Veg Chesse Biryani', 'veg chesse biryani', 'veg', NULL, NULL, NULL, TRUE),
    (290, 'Curd', 'curd', 'veg', NULL, NULL, FALSE, TRUE),
    (291, 'Veg Raita', 'veg raita', 'veg', NULL, NULL, FALSE, TRUE),
    (292, 'Boondi Raita', 'boondi raita', 'veg', NULL, NULL, FALSE, TRUE),
    (293, 'Pineapple Raita', 'pineapple raita', 'veg', NULL, NULL, FALSE, TRUE),
    (294, 'Fruits Raita', 'fruits raita', 'veg', NULL, NULL, FALSE, TRUE),
    (295, 'Roasted Papad', 'roasted papad', 'veg', NULL, NULL, TRUE, TRUE),
    (296, 'Fry Papad', 'fry papad', 'veg', NULL, NULL, TRUE, TRUE),
    (297, 'Masala Papad', 'masala papad', 'veg', NULL, NULL, TRUE, TRUE),
    (298, 'Khichiya Roasted Papad', 'khichiya roasted papad', 'veg', NULL, NULL, TRUE, TRUE),
    (299, 'Khichiya Masala Papad', 'khichiya masala papad', 'veg', NULL, NULL, TRUE, TRUE),
    (300, 'Rumali Masala Papad', 'rumali masala papad', 'veg', NULL, NULL, TRUE, TRUE),
    (301, 'Rumali Masala Cheese Papad', 'rumali masala cheese papad', 'veg', NULL, NULL, FALSE, TRUE),
    (302, 'Jamun Shots', 'jamun shots', 'veg', NULL, NULL, TRUE, TRUE),
    (303, 'Milanberry', 'milanberry', 'veg', NULL, NULL, TRUE, TRUE),
    (304, 'Meverick', 'meverick', 'veg', NULL, NULL, TRUE, TRUE),
    (305, 'Cindrella', 'cindrella', 'veg', NULL, NULL, TRUE, TRUE),
    (306, 'Litchi Blast', 'litchi blast', 'veg', NULL, NULL, TRUE, TRUE),
    (307, 'Bloom', 'bloom', 'veg', NULL, NULL, TRUE, TRUE),
    (308, 'Mad Mind', 'mad mind', 'veg', NULL, NULL, TRUE, TRUE),
    (309, 'Holy Affair', 'holy affair', 'veg', NULL, NULL, TRUE, TRUE),
    (310, 'Sniper', 'sniper', 'veg', NULL, NULL, TRUE, TRUE),
    (311, 'Two Berry', 'two berry', 'veg', NULL, NULL, TRUE, TRUE),
    (312, 'Sunrise', 'sunrise', 'veg', NULL, NULL, TRUE, TRUE),
    (313, 'Royal Falooda', 'royal falooda', 'veg', NULL, NULL, FALSE, TRUE),
    (314, 'Kulfi Falooda', 'kulfi falooda', 'veg', NULL, NULL, FALSE, TRUE),
    (315, 'Dryfruit Falooda', 'dryfruit falooda', 'veg', NULL, NULL, FALSE, TRUE),
    (316, 'Kesar Falooda', 'kesar falooda', 'veg', NULL, NULL, FALSE, TRUE),
    (317, 'Butter Milk Masala', 'butter milk masala', 'veg', NULL, NULL, FALSE, TRUE),
    (318, 'Butter Milk Plain', 'butter milk plain', 'veg', NULL, NULL, FALSE, TRUE),
    (319, 'Oreo Milkshake', 'oreo milkshake', 'veg', NULL, NULL, FALSE, TRUE),
    (320, 'Kulfi Milkshake', 'kulfi milkshake', 'veg', NULL, NULL, FALSE, TRUE),
    (321, 'Blueberry Milkshake', 'blueberry milkshake', 'veg', NULL, NULL, FALSE, TRUE),
    (322, 'Brownie Milkshake', 'brownie milkshake', 'veg', NULL, NULL, FALSE, TRUE),
    (323, 'Hazelnut Mocha Shake', 'hazelnut mocha shake', 'veg', NULL, NULL, FALSE, TRUE),
    (324, 'Tiramisu Mocha Shake', 'tiramisu mocha shake', 'veg', NULL, NULL, FALSE, TRUE),
    (325, 'Choco Mocha', 'choco mocha', 'veg', NULL, NULL, FALSE, TRUE),
    (326, 'Mix Fruit Cream', 'mix fruit cream', 'veg', NULL, NULL, FALSE, TRUE),
    (327, 'Sitafal Cream', 'sitafal cream', 'veg', NULL, NULL, FALSE, TRUE),
    (328, 'Caramel Custard', 'caramel custard', 'veg', NULL, NULL, FALSE, TRUE),
    (329, 'Nutella Cheese Cake', 'nutella cheese cake', 'veg', NULL, NULL, FALSE, TRUE),
    (330, 'Blueberry Cheese Cake', 'blueberry cheese cake', 'veg', NULL, NULL, FALSE, TRUE),
    (331, 'Strawberry Cheese Cake', 'strawberry cheese cake', 'veg', NULL, NULL, FALSE, TRUE),
    (332, 'Biscoff Cheese Cake', 'biscoff cheese cake', 'veg', NULL, NULL, FALSE, TRUE),
    (333, 'Brownie Waffles', 'brownie waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (334, 'Crunchy Kit-Kat Waffles', 'crunchy kit-kat waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (335, 'Nutella Waffles', 'nutella waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (336, 'Overload Chocolate Waffles', 'overload chocolate waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (337, 'Naughty Nuts Waffles', 'naughty nuts waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (338, 'Authentic Belgium Waffles', 'authentic belgium waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (339, 'Oreo Waffles', 'oreo waffles', 'veg', NULL, NULL, FALSE, TRUE),
    (340, 'Gems Magic Waffles', 'gems magic waffles', 'veg', NULL, NULL, FALSE, TRUE)
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
VALUES (400086002001, 400086002, 'A La Carte', 'a_la_carte', 1);
-- board name is a structural label (the JSON names no board); the JSON describes one overall menu
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence, is_active)
VALUES
    -- pages[1].sections[0] (TFT02.jpg, column 1)
    (400086002001, 400086002, 'SOUP', 1, TRUE),
    -- pages[1].sections[1] (TFT02.jpg, column 1)
    (400086002002, 400086002, 'INDIAN SOUP', 2, TRUE),
    -- pages[1].sections[2] (TFT02.jpg, column 1)
    (400086002003, 400086002, 'SALAD', 3, TRUE),
    -- pages[1].sections[3] (TFT02.jpg, column 2)
    (400086002004, 400086002, 'FRIES', 4, TRUE),
    -- pages[1].sections[4] (TFT02.jpg, column 2)
    (400086002005, 400086002, 'NACHOS', 5, TRUE),
    -- pages[1].sections[5] (TFT02.jpg, column 2)
    (400086002006, 400086002, 'BAO', 6, TRUE),
    -- pages[2].sections[0] (TFT03.jpg, column 1)
    (400086002007, 400086002, 'GARLIC BREADS', 7, TRUE),
    -- pages[2].sections[1] (TFT03.jpg, column 1)
    (400086002008, 400086002, 'OPEN BREAD SANDWICHES', 8, TRUE),
    -- pages[2].sections[2] (TFT03.jpg, column 1)
    (400086002009, 400086002, 'GRILL SANDWICH W / B', 9, TRUE),
    -- pages[2].sections[3] (TFT03.jpg, column 2)
    (400086002010, 400086002, 'PIZZA (7'' THIN CRUST)', 10, TRUE),
    -- pages[2].sections[4] (TFT03.jpg, column 2)
    (400086002011, 400086002, 'PASTA', 11, TRUE),
    -- pages[2].sections[5] (TFT03.jpg, column 2)
    (400086002012, 400086002, 'HOMEMADE STUFF PASTA', 12, TRUE),
    -- pages[3].sections[0] (TFT04.jpg, column 1)
    (400086002013, 400086002, 'FONDUE', 13, TRUE),
    -- pages[3].sections[1] (TFT04.jpg, column 1)
    (400086002014, 400086002, 'LEBANESE', 14, TRUE),
    -- pages[3].sections[2] (TFT04.jpg, column 1)
    (400086002015, 400086002, 'SUSHI (8 Pcs)', 15, TRUE),
    -- pages[3].sections[3] (TFT04.jpg, column 2)
    (400086002016, 400086002, 'PAV BHAJI', 16, TRUE),
    -- pages[3].sections[4] (TFT04.jpg, column 2)
    (400086002017, 400086002, 'FUSION FOOD', 17, TRUE),
    -- pages[3].sections[5] (TFT04.jpg, column 2)
    (400086002018, 400086002, 'ORIENTAL & CONTINENTAL STARTERS', 18, TRUE),
    -- pages[4].sections[0] (TFT05.jpg, column 1)
    (400086002019, 400086002, 'INDIAN & TANDOOR STARTER', 19, TRUE),
    -- pages[4].sections[1] (TFT05.jpg, column 1)
    (400086002020, 400086002, 'RISOTTO RICE', 20, TRUE),
    -- pages[4].sections[2] (TFT05.jpg, column 2)
    (400086002021, 400086002, 'SIZZLER', 21, TRUE),
    -- pages[4].sections[3] (TFT05.jpg, column 2)
    (400086002022, 400086002, 'EXTRA TOPPINGS', 22, TRUE),
    -- pages[4].sections[4] (TFT05.jpg, column 2)
    (400086002023, 400086002, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 23, TRUE),
    -- pages[5].sections[0] (TFT06.jpg, column 1)
    (400086002024, 400086002, 'ORIENTAL & THAI RICE', 24, TRUE),
    -- pages[5].sections[1] (TFT06.jpg, column 2)
    (400086002025, 400086002, 'NOODLES', 25, TRUE),
    -- pages[5].sections[2] (TFT06.jpg, column 2)
    (400086002026, 400086002, 'NOODLES WITH GRAVY', 26, TRUE),
    -- pages[5].sections[3] (TFT06.jpg, column 1)
    (400086002027, 400086002, 'ORIENTAL GRAVY & THAI CURRY', 27, TRUE),
    -- pages[5].sections[4] (TFT06.jpg, column 2)
    (400086002028, 400086002, 'INDIAN MAIN COURSE', 28, TRUE),
    -- pages[6].sections[0] (TFT07.jpg, column 1)
    (400086002029, 400086002, 'SABJI TARKARI', 29, TRUE),
    -- pages[6].sections[1] (TFT07.jpg, column 2)
    (400086002030, 400086002, 'ROTI', 30, TRUE),
    -- pages[6].sections[2] (TFT07.jpg, column 2)
    (400086002031, 400086002, 'RICE', 31, TRUE),
    -- pages[7].sections[0] (TFT08.jpg, column 1)
    (400086002032, 400086002, 'DAL', 32, TRUE),
    -- pages[7].sections[1] (TFT08.jpg, column 1)
    (400086002033, 400086002, 'BIRYANI', 33, TRUE),
    -- pages[7].sections[2] (TFT08.jpg, column 1)
    (400086002034, 400086002, 'RAITA/PAPAD', 34, TRUE),
    -- pages[7].sections[3] (TFT08.jpg, column 2)
    (400086002035, 400086002, 'FRESH JUICE', 35, TRUE),
    -- pages[7].sections[4] (TFT08.jpg, column 2)
    (400086002036, 400086002, 'MIXOLOGY', 36, TRUE),
    -- pages[7].sections[5] (TFT08.jpg, column 2)
    (400086002037, 400086002, 'FALOODA', 37, TRUE),
    -- pages[8].sections[0] (TFT09.jpg, column 1)
    (400086002038, 400086002, 'MILK SHAKES - CLASSIC SHAKES', 38, TRUE),
    -- pages[8].sections[1] (TFT09.jpg, column 1)
    (400086002039, 400086002, 'BUTTER MILK', 39, TRUE),
    -- pages[8].sections[2] (TFT09.jpg, column 1)
    (400086002040, 400086002, 'PREMIUM MILKSHAKES', 40, TRUE),
    -- pages[8].sections[3] (TFT09.jpg, column 1)
    (400086002041, 400086002, 'FRUIT WITH CREAM', 41, TRUE),
    -- pages[8].sections[4] (TFT09.jpg, column 2)
    (400086002042, 400086002, 'PASTRY', 42, TRUE),
    -- pages[8].sections[5] (TFT09.jpg, column 2)
    (400086002043, 400086002, 'WAFFLES', 43, TRUE);

-- ----------------------------------------------------------------------------
-- 6. MENU ITEMS, VARIANTS, PRICES (one block per JSON section)
-- ----------------------------------------------------------------------------

-- [1/43] SOUP  |  JSON: pages[1].sections[0]  (TFT02.jpg, column 1; 15 JSON line(s) -> 15 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Manchow Soup
    (400086002001, 400086002001, 'Manchow Soup', 'manchow soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'manchow soup'),
    -- items[1] Lemon Coriander Soup
    (400086002002, 400086002001, 'Lemon Coriander Soup', 'lemon coriander soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'lemon coriander soup'),
    -- items[2] Xiaolong Dumpling Soup
    (400086002003, 400086002001, 'Xiaolong Dumpling Soup', 'xiaolong dumpling soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'xiaolong dumpling soup'),
    -- items[3] Burn Garlic Soup
    (400086002004, 400086002001, 'Burn Garlic Soup', 'burn garlic soup', NULL, 'SOUP', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'burn garlic soup'),
    -- items[4] Ministrone Soup
    (400086002005, 400086002001, 'Ministrone Soup', 'ministrone soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'ministrone soup'),
    -- items[5] Veg Talumain Soup
    (400086002006, 400086002001, 'Veg Talumain Soup', 'veg talumain soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg talumain soup'),
    -- items[6] TFT Spl. Soup
    (400086002007, 400086002001, 'TFT Spl. Soup', 'tft spl. soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tft spl. soup'),
    -- items[7] Mexican Tacos Soup
    (400086002008, 400086002001, 'Mexican Tacos Soup', 'mexican tacos soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican tacos soup'),
    -- items[8] Tom Yum Soup
    (400086002009, 400086002001, 'Tom Yum Soup', 'tom yum soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tom yum soup'),
    -- items[9] Roasted Corn Soup
    (400086002010, 400086002001, 'Roasted Corn Soup', 'roasted corn soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'roasted corn soup'),
    -- items[10] Baby Corn Broccoli Soup
    (400086002011, 400086002001, 'Baby Corn Broccoli Soup', 'baby corn broccoli soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'baby corn broccoli soup'),
    -- items[11] Cream of Mushroom Soup
    (400086002012, 400086002001, 'Cream of Mushroom Soup', 'cream of mushroom soup', NULL, 'SOUP', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'cream of mushroom soup'),
    -- items[12] Roasted Almond Broccoli Soup
    (400086002013, 400086002001, 'Roasted Almond Broccoli Soup', 'roasted almond broccoli soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'roasted almond broccoli soup'),
    -- items[13] Cream of Tomato Soup
    (400086002014, 400086002001, 'Cream of Tomato Soup', 'cream of tomato soup', NULL, 'SOUP', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cream of tomato soup'),
    -- items[14] Crunchy Corn Soup
    (400086002015, 400086002001, 'Crunchy Corn Soup', 'crunchy corn soup', NULL, 'SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'crunchy corn soup')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002001, 400086002001, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002002, 400086002002, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002003, 400086002003, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002004, 400086002004, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002005, 400086002005, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002006, 400086002006, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002007, 400086002007, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002008, 400086002008, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002009, 400086002009, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002010, 400086002010, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002011, 400086002011, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002012, 400086002012, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002013, 400086002013, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002014, 400086002014, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002015, 400086002015, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002001, 400086002001, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002002, 400086002002, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002003, 400086002003, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002004, 400086002004, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002005, 400086002005, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002006, 400086002006, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002007, 400086002007, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002008, 400086002008, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002009, 400086002009, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002010, 400086002010, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002011, 400086002011, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002012, 400086002012, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002013, 400086002013, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002014, 400086002014, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002015, 400086002015, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [2/43] INDIAN SOUP  |  JSON: pages[1].sections[1]  (TFT02.jpg, column 1; 2 JSON line(s) -> 2 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Tomato Shorba
    (400086002016, 400086002002, 'Tomato Shorba', 'tomato shorba', NULL, 'INDIAN SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tomato shorba'),
    -- items[1] Broccoli Shorba
    (400086002017, 400086002002, 'Broccoli Shorba', 'broccoli shorba', NULL, 'INDIAN SOUP', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'broccoli shorba')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002016, 400086002016, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002017, 400086002017, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002016, 400086002016, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002017, 400086002017, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [3/43] SALAD  |  JSON: pages[1].sections[2]  (TFT02.jpg, column 1; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Green Garden Salad
    (400086002018, 400086002003, 'Green Garden Salad', 'green garden salad', NULL, 'SALAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'green garden salad'),
    -- items[1] Hot Saute Salad
    (400086002019, 400086002003, 'Hot Saute Salad', 'hot saute salad', NULL, 'SALAD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'hot saute salad'),
    -- items[2] Ceaser Salad
    (400086002020, 400086002003, 'Ceaser Salad', 'ceaser salad', NULL, 'SALAD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'ceaser salad'),
    -- items[3] Chef Spl Salad
    (400086002021, 400086002003, 'Chef Spl Salad', 'chef spl salad', NULL, 'SALAD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'chef spl salad'),
    -- items[4] Tandoori Potato Honey Mustard Salad
    (400086002022, 400086002003, 'Tandoori Potato Honey Mustard Salad', 'tandoori potato honey mustard salad', NULL, 'SALAD', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'tandoori potato honey mustard salad')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002018, 400086002018, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002019, 400086002019, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002020, 400086002020, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002021, 400086002021, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002022, 400086002022, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002018, 400086002018, 170.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002019, 400086002019, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002020, 400086002020, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002021, 400086002021, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002022, 400086002022, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [4/43] FRIES  |  JSON: pages[1].sections[3]  (TFT02.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] French Fries
    (400086002023, 400086002004, 'French Fries', 'french fries', NULL, 'FRIES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'french fries'),
    -- items[1] Cheese French
    (400086002024, 400086002004, 'Cheese French', 'cheese french', NULL, 'FRIES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese french'),
    -- items[2] Peri Peri Fries
    (400086002025, 400086002004, 'Peri Peri Fries', 'peri peri fries', NULL, 'FRIES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'peri peri fries'),
    -- items[3] Mexican French Fries
    (400086002026, 400086002004, 'Mexican French Fries', 'mexican french fries', NULL, 'FRIES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican french fries'),
    -- items[4] Chilli French Fries
    (400086002027, 400086002004, 'Chilli French Fries', 'chilli french fries', NULL, 'FRIES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'chilli french fries')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002023, 400086002023, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002024, 400086002024, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002025, 400086002025, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002026, 400086002026, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002027, 400086002027, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002023, 400086002023, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002024, 400086002024, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002025, 400086002025, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002026, 400086002026, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002027, 400086002027, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [5/43] NACHOS  |  JSON: pages[1].sections[4]  (TFT02.jpg, column 2; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Cheese Nachos
    (400086002028, 400086002005, 'Cheese Nachos', 'cheese nachos', NULL, 'NACHOS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese nachos'),
    -- items[1] Nachos Corn Queso
    (400086002029, 400086002005, 'Nachos Corn Queso', 'nachos corn queso', NULL, 'NACHOS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'nachos corn queso'),
    -- items[2] Loaded U.S Nachos
    (400086002030, 400086002005, 'Loaded U.S Nachos', 'loaded u.s nachos', NULL, 'NACHOS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'loaded u.s nachos'),
    -- items[3] Mexican Nachos
    (400086002031, 400086002005, 'Mexican Nachos', 'mexican nachos', NULL, 'NACHOS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican nachos')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002028, 400086002028, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002029, 400086002029, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002030, 400086002030, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002031, 400086002031, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002028, 400086002028, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002029, 400086002029, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002030, 400086002030, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002031, 400086002031, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [6/43] BAO  |  JSON: pages[1].sections[5]  (TFT02.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paneer Chilli Bao
    (400086002032, 400086002006, 'Paneer Chilli Bao', 'paneer chilli bao', '(Paneer, Veg, Soya Sauce)', 'BAO', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli bao'),
    -- items[1] Celandtro Cottage Cheese Bao
    (400086002033, 400086002006, 'Celandtro Cottage Cheese Bao', 'celandtro cottage cheese bao', '(Paneer, Veg, Celantro Sauce)', 'BAO', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'celandtro cottage cheese bao'),
    -- items[2] Kung - Pao Mushroom Bao
    (400086002034, 400086002006, 'Kung - Pao Mushroom Bao', 'kung - pao mushroom bao', '(Mushroom, Veg, Soya Sauce)', 'BAO', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'kung - pao mushroom bao'),
    -- items[3] Mexican Bao
    (400086002035, 400086002006, 'Mexican Bao', 'mexican bao', '(Refried Beans, Salsa, Veg)', 'BAO', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican bao'),
    -- items[4] Paneer, Thai Basil
    (400086002036, 400086002006, 'Paneer, Thai Basil', 'paneer, thai basil', NULL, 'BAO', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer, thai basil')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002032, 400086002032, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002033, 400086002033, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002034, 400086002034, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002035, 400086002035, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002036, 400086002036, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002032, 400086002032, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002033, 400086002033, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002034, 400086002034, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002035, 400086002035, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002036, 400086002036, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [7/43] GARLIC BREADS  |  JSON: pages[2].sections[0]  (TFT03.jpg, column 1; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Cheese Garlic Bread
    (400086002037, 400086002007, 'Cheese Garlic Bread', 'cheese garlic bread', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'cheese garlic bread'),
    -- items[1] Corn Cheese Garlic
    (400086002038, 400086002007, 'Corn Cheese Garlic', 'corn cheese garlic', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'corn cheese garlic'),
    -- items[2] Chilli Cheese Garlic
    (400086002039, 400086002007, 'Chilli Cheese Garlic', 'chilli cheese garlic', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'chilli cheese garlic'),
    -- items[3] Schezwan Paneer Garlic
    (400086002040, 400086002007, 'Schezwan Paneer Garlic', 'schezwan paneer garlic', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'schezwan paneer garlic'),
    -- items[4] Melting Chilli Garlic
    (400086002041, 400086002007, 'Melting Chilli Garlic', 'melting chilli garlic', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'melting chilli garlic'),
    -- items[5] Stuff Garlic Bread
    (400086002042, 400086002007, 'Stuff Garlic Bread', 'stuff garlic bread', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'stuff garlic bread'),
    -- items[6] Assorted Garlic Bread
    (400086002043, 400086002007, 'Assorted Garlic Bread', 'assorted garlic bread', NULL, 'GARLIC BREADS', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'assorted garlic bread')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002037, 400086002037, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002038, 400086002038, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002039, 400086002039, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002040, 400086002040, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002041, 400086002041, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002042, 400086002042, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002043, 400086002043, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002037, 400086002037, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002038, 400086002038, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002039, 400086002039, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002040, 400086002040, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002041, 400086002041, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002042, 400086002042, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002043, 400086002043, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [8/43] OPEN BREAD SANDWICHES  |  JSON: pages[2].sections[1]  (TFT03.jpg, column 1; 6 JSON line(s) -> 6 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Cheese Montezza
    (400086002044, 400086002008, 'Cheese Montezza', 'cheese montezza', NULL, 'OPEN BREAD SANDWICHES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese montezza'),
    -- items[1] French Masala Roll
    (400086002045, 400086002008, 'French Masala Roll', 'french masala roll', NULL, 'OPEN BREAD SANDWICHES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'french masala roll'),
    -- items[2] Cheese Chilly Toast
    (400086002046, 400086002008, 'Cheese Chilly Toast', 'cheese chilly toast', NULL, 'OPEN BREAD SANDWICHES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese chilly toast'),
    -- items[3] Bruschetta
    (400086002047, 400086002008, 'Bruschetta', 'bruschetta', NULL, 'OPEN BREAD SANDWICHES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'bruschetta'),
    -- items[4] Cheezo Blast
    (400086002048, 400086002008, 'Cheezo Blast', 'cheezo blast', NULL, 'OPEN BREAD SANDWICHES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheezo blast'),
    -- items[5] Garlic Avacado Toast
    (400086002049, 400086002008, 'Garlic Avacado Toast', 'garlic avacado toast', NULL, 'OPEN BREAD SANDWICHES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'garlic avacado toast')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002044, 400086002044, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002045, 400086002045, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002046, 400086002046, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002047, 400086002047, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002048, 400086002048, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002049, 400086002049, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002044, 400086002044, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002045, 400086002045, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002046, 400086002046, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002047, 400086002047, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002048, 400086002048, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002049, 400086002049, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [9/43] GRILL SANDWICH W / B  |  JSON: pages[2].sections[2]  (TFT03.jpg, column 1; 8 JSON line(s) -> 8 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Melting Grill
    (400086002050, 400086002009, 'Melting Grill', 'melting grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'melting grill'),
    -- items[1] TFT Spl. Grill
    (400086002051, 400086002009, 'TFT Spl. Grill', 'tft spl. grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tft spl. grill'),
    -- items[2] Paneer Chilli Grill
    (400086002052, 400086002009, 'Paneer Chilli Grill', 'paneer chilli grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli grill'),
    -- items[3] Veg Cheese Grill
    (400086002053, 400086002009, 'Veg Cheese Grill', 'veg cheese grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg cheese grill'),
    -- items[4] Bombay Grill
    (400086002054, 400086002009, 'Bombay Grill', 'bombay grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'bombay grill'),
    -- items[5] Paneer Tikka Grill
    (400086002055, 400086002009, 'Paneer Tikka Grill', 'paneer tikka grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka grill'),
    -- items[6] Marina Grill
    (400086002056, 400086002009, 'Marina Grill', 'marina grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'marina grill'),
    -- items[7] Super Grill
    (400086002057, 400086002009, 'Super Grill', 'super grill', NULL, 'GRILL SANDWICH W / B', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'super grill')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002050, 400086002050, 'White Bread', 'W', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002051, 400086002050, 'Brown Bread', 'B', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002052, 400086002051, 'White Bread', 'W', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002053, 400086002051, 'Brown Bread', 'B', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002054, 400086002052, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002055, 400086002053, 'White Bread', 'W', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002056, 400086002053, 'Brown Bread', 'B', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002057, 400086002054, 'White Bread', 'W', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002058, 400086002054, 'Brown Bread', 'B', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002059, 400086002055, 'White Bread', 'W', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002060, 400086002055, 'Brown Bread', 'B', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002061, 400086002056, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002062, 400086002057, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002050, 400086002050, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002051, 400086002051, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002052, 400086002052, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002053, 400086002053, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002054, 400086002054, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002055, 400086002055, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002056, 400086002056, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002057, 400086002057, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002058, 400086002058, 270.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002059, 400086002059, 270.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002060, 400086002060, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002061, 400086002061, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002062, 400086002062, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002);

-- [10/43] PIZZA (7' THIN CRUST)  |  JSON: pages[2].sections[3]  (TFT03.jpg, column 2; 13 JSON line(s) -> 13 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Cheese Burst Pizza
    (400086002058, 400086002010, 'Cheese Burst Pizza', 'cheese burst pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese burst pizza'),
    -- items[1] Peppy Paneer Pizza
    (400086002059, 400086002010, 'Peppy Paneer Pizza', 'peppy paneer pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'peppy paneer pizza'),
    -- items[2] Garden Pizza
    (400086002060, 400086002010, 'Garden Pizza', 'garden pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'garden pizza'),
    -- items[3] Farmer Pizza
    (400086002061, 400086002010, 'Farmer Pizza', 'farmer pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'farmer pizza'),
    -- items[4] Mexican Pizza
    (400086002062, 400086002010, 'Mexican Pizza', 'mexican pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'mexican pizza'),
    -- items[5] Aioli Pizza
    (400086002063, 400086002010, 'Aioli Pizza', 'aioli pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'aioli pizza'),
    -- items[6] Paneer Tikka Pizza
    (400086002064, 400086002010, 'Paneer Tikka Pizza', 'paneer tikka pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka pizza'),
    -- items[7] Bombay Pizza
    (400086002065, 400086002010, 'Bombay Pizza', 'bombay pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'bombay pizza'),
    -- items[8] Paneer Basil Pizza
    (400086002066, 400086002010, 'Paneer Basil Pizza', 'paneer basil pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer basil pizza'),
    -- items[9] 4 in 1 Pizza
    (400086002067, 400086002010, '4 in 1 Pizza', '4 in 1 pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', '4 in 1 pizza'),
    -- items[10] Margherita Pizza
    (400086002068, 400086002010, 'Margherita Pizza', 'margherita pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'margherita pizza'),
    -- items[11] Smoky BBQ Pizza
    (400086002069, 400086002010, 'Smoky BBQ Pizza', 'smoky bbq pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'smoky bbq pizza'),
    -- items[12] Oriental Paneer Pizza
    (400086002070, 400086002010, 'Oriental Paneer Pizza', 'oriental paneer pizza', NULL, 'PIZZA (7'' THIN CRUST)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'oriental paneer pizza')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002063, 400086002058, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002064, 400086002059, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002065, 400086002060, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002066, 400086002061, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002067, 400086002062, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002068, 400086002063, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002069, 400086002064, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002070, 400086002065, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002071, 400086002066, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002072, 400086002067, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002073, 400086002068, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002074, 400086002069, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002075, 400086002070, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002063, 400086002063, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002064, 400086002064, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002065, 400086002065, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002066, 400086002066, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002067, 400086002067, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002068, 400086002068, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002069, 400086002069, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002070, 400086002070, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002071, 400086002071, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002072, 400086002072, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002073, 400086002073, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002074, 400086002074, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002075, 400086002075, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [11/43] PASTA  |  JSON: pages[2].sections[4]  (TFT03.jpg, column 2; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Alfredo Pasta
    (400086002071, 400086002011, 'Alfredo Pasta', 'alfredo pasta', NULL, 'PASTA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'alfredo pasta'),
    -- items[1] Arrabiata Pasta
    (400086002072, 400086002011, 'Arrabiata Pasta', 'arrabiata pasta', NULL, 'PASTA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'arrabiata pasta'),
    -- items[2] Pink Tango Pasta
    (400086002073, 400086002011, 'Pink Tango Pasta', 'pink tango pasta', NULL, 'PASTA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'pink tango pasta'),
    -- items[3] 4 Cheese Pasta
    (400086002074, 400086002011, '4 Cheese Pasta', '4 cheese pasta', NULL, 'PASTA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', '4 cheese pasta'),
    -- items[4] Creamy Pesto Pasta
    (400086002075, 400086002011, 'Creamy Pesto Pasta', 'creamy pesto pasta', NULL, 'PASTA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'creamy pesto pasta'),
    -- items[5] Creamy Fungi Pasta
    (400086002076, 400086002011, 'Creamy Fungi Pasta', 'creamy fungi pasta', NULL, 'PASTA', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'creamy fungi pasta'),
    -- items[6] Aglio Olio Spaghetti
    (400086002077, 400086002011, 'Aglio Olio Spaghetti', 'aglio olio spaghetti', NULL, 'PASTA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'aglio olio spaghetti')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002076, 400086002071, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002077, 400086002072, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002078, 400086002073, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002079, 400086002074, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002080, 400086002075, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002081, 400086002076, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002082, 400086002077, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002076, 400086002076, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002077, 400086002077, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002078, 400086002078, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002079, 400086002079, 430.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002080, 400086002080, 410.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002081, 400086002081, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002082, 400086002082, 410.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [12/43] HOMEMADE STUFF PASTA  |  JSON: pages[2].sections[5]  (TFT03.jpg, column 2; 2 JSON line(s) -> 2 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Ravioli Pasta
    (400086002078, 400086002012, 'Ravioli Pasta', 'ravioli pasta', '(White / Red / Pink)', 'HOMEMADE STUFF PASTA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'ravioli pasta'),
    -- items[1] Tortellini Pasta
    (400086002079, 400086002012, 'Tortellini Pasta', 'tortellini pasta', '(White / Red / Pink)', 'HOMEMADE STUFF PASTA', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tortellini pasta')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002083, 400086002078, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002084, 400086002079, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002083, 400086002083, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002084, 400086002084, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [13/43] FONDUE  |  JSON: pages[3].sections[0]  (TFT04.jpg, column 1; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Cheese Fondue
    (400086002080, 400086002013, 'Cheese Fondue', 'cheese fondue', NULL, 'FONDUE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese fondue'),
    -- items[1] Veg Cheese Fondue
    (400086002081, 400086002013, 'Veg Cheese Fondue', 'veg cheese fondue', NULL, 'FONDUE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg cheese fondue'),
    -- items[2] Pav Bhaji Fondue
    (400086002082, 400086002013, 'Pav Bhaji Fondue', 'pav bhaji fondue', NULL, 'FONDUE', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'pav bhaji fondue'),
    -- items[3] Thai Fondue
    (400086002083, 400086002013, 'Thai Fondue', 'thai fondue', NULL, 'FONDUE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'thai fondue'),
    -- items[4] Extra Fondue Bread
    (400086002084, 400086002013, 'Extra Fondue Bread', 'extra fondue bread', NULL, 'FONDUE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'extra fondue bread')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002085, 400086002080, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002086, 400086002081, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002087, 400086002082, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002088, 400086002083, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002089, 400086002084, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002085, 400086002085, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002086, 400086002086, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002087, 400086002087, 410.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002088, 400086002088, 410.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002089, 400086002089, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [14/43] LEBANESE  |  JSON: pages[3].sections[1]  (TFT04.jpg, column 1; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Hummus Dip Platter
    (400086002085, 400086002014, 'Hummus Dip Platter', 'hummus dip platter', '(Hummus, Pesto Hummus, Garlic tahina Dip, Pita Bread, Lavash)', 'LEBANESE', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'hummus dip platter'),
    -- items[1] Falafel Bites
    (400086002086, 400086002014, 'Falafel Bites', 'falafel bites', '(Deep Fried Falafel Bites, Tahina Sauce, Harrisa Sauce)', 'LEBANESE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'falafel bites'),
    -- items[2] Assorted Lebanese Platter
    (400086002087, 400086002014, 'Assorted Lebanese Platter', 'assorted lebanese platter', '(Hummus, Basil Hummus, Falafel Bites, Salad, Fries, Harrisa Dip, Tahina Sauce, Lavash, Pita Bread, Khabus Bread)', 'LEBANESE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'assorted lebanese platter'),
    -- items[3] Falafel Sandwich
    (400086002088, 400086002014, 'Falafel Sandwich', 'falafel sandwich', NULL, 'LEBANESE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'falafel sandwich')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002090, 400086002085, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002091, 400086002086, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002092, 400086002087, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002093, 400086002088, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002090, 400086002090, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002091, 400086002091, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002092, 400086002092, 540.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002093, 400086002093, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [15/43] SUSHI (8 Pcs)  |  JSON: pages[3].sections[2]  (TFT04.jpg, column 1; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Asparagus Tempura Sushi
    (400086002089, 400086002015, 'Asparagus Tempura Sushi', 'asparagus tempura sushi', '(Tempura, Asparagus, Cheese, Nori Sheet & Rice)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'asparagus tempura sushi'),
    -- items[1] California Veg.Roll Sushi
    (400086002090, 400086002015, 'California Veg.Roll Sushi', 'california veg.roll sushi', '(Cucumber, Avocado, Carrot, Cheese, Nori Sheet & Rice)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'california veg.roll sushi'),
    -- items[2] Maki Roll
    (400086002091, 400086002015, 'Maki Roll', 'maki roll', '(Cucumber, Asparagus, Carrot, Cheese, Nori Sheet & Rice)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'maki roll'),
    -- items[3] Babycorn Tempura Roll
    (400086002092, 400086002015, 'Babycorn Tempura Roll', 'babycorn tempura roll', '(Avocado, Babycorn, Cheese, Nori Sheet & Rice)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'babycorn tempura roll'),
    -- items[4] Avocado & Cream Cheese Sushi
    (400086002093, 400086002015, 'Avocado & Cream Cheese Sushi', 'avocado & cream cheese sushi', '(Avocado, Cheese, Nori Sheet & Rice)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'avocado & cream cheese sushi'),
    -- items[5] Asparagus Cream Cheese Sushi
    (400086002094, 400086002015, 'Asparagus Cream Cheese Sushi', 'asparagus cream cheese sushi', '(Asparagus, Cheese, Nori Sheet & Rice)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'asparagus cream cheese sushi'),
    -- items[6] Mexican Style Sushi
    (400086002095, 400086002015, 'Mexican Style Sushi', 'mexican style sushi', '(Mix Vegetables, Cheese, Nori Sheet & Rice Spicy)', 'SUSHI (8 Pcs)', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'mexican style sushi')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002094, 400086002089, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002095, 400086002090, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002096, 400086002091, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002097, 400086002092, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002098, 400086002093, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002099, 400086002094, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002100, 400086002095, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002094, 400086002094, 450.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002095, 400086002095, 430.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002096, 400086002096, 430.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002097, 400086002097, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002098, 400086002098, 470.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002099, 400086002099, 440.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002100, 400086002100, 440.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [16/43] PAV BHAJI  |  JSON: pages[3].sections[3]  (TFT04.jpg, column 2; 9 JSON line(s) -> 9 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Pav Bhaji
    (400086002096, 400086002016, 'Pav Bhaji', 'pav bhaji', NULL, 'PAV BHAJI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'pav bhaji'),
    -- items[1] Cheese Pav Bhaji
    (400086002097, 400086002016, 'Cheese Pav Bhaji', 'cheese pav bhaji', NULL, 'PAV BHAJI', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'cheese pav bhaji'),
    -- items[2] Jain Pav Bhaji
    (400086002098, 400086002016, 'Jain Pav Bhaji', 'jain pav bhaji', NULL, 'PAV BHAJI', 'veg', NULL, TRUE, NULL, TRUE, NULL, 'unverified', 'jain pav bhaji'),
    -- items[3] Soya Keema Pav
    (400086002099, 400086002016, 'Soya Keema Pav', 'soya keema pav', NULL, 'PAV BHAJI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'soya keema pav'),
    -- items[4] Masala Pav
    (400086002100, 400086002016, 'Masala Pav', 'masala pav', NULL, 'PAV BHAJI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'masala pav'),
    -- items[5] Hariyali Pav Bhaji
    (400086002101, 400086002016, 'Hariyali Pav Bhaji', 'hariyali pav bhaji', NULL, 'PAV BHAJI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'hariyali pav bhaji'),
    -- items[6] Italian Pav Bhaji
    (400086002102, 400086002016, 'Italian Pav Bhaji', 'italian pav bhaji', NULL, 'PAV BHAJI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'italian pav bhaji'),
    -- items[7] Extra Butter Pav
    (400086002103, 400086002016, 'Extra Butter Pav', 'extra butter pav', NULL, 'PAV BHAJI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'extra butter pav'),
    -- items[8] Plain Pav
    (400086002104, 400086002016, 'Plain Pav', 'plain pav', NULL, 'PAV BHAJI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'plain pav')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002101, 400086002096, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002102, 400086002097, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002103, 400086002098, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002104, 400086002099, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002105, 400086002100, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002106, 400086002101, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002107, 400086002102, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002108, 400086002103, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002109, 400086002104, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002101, 400086002101, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002102, 400086002102, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002103, 400086002103, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002104, 400086002104, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002105, 400086002105, 190.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002106, 400086002106, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002107, 400086002107, 240.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002108, 400086002108, 25.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002109, 400086002109, 15.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [17/43] FUSION FOOD  |  JSON: pages[3].sections[4]  (TFT04.jpg, column 2; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Medu Vada with Thai Curry
    (400086002105, 400086002017, 'Medu Vada with Thai Curry', 'medu vada with thai curry', NULL, 'FUSION FOOD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'medu vada with thai curry'),
    -- items[1] Chole Bhature
    (400086002106, 400086002017, 'Chole Bhature', 'chole bhature', NULL, 'FUSION FOOD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'chole bhature'),
    -- items[2] Chinese Bhel
    (400086002107, 400086002017, 'Chinese Bhel', 'chinese bhel', NULL, 'FUSION FOOD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'chinese bhel'),
    -- items[3] Mexican Bhel
    (400086002108, 400086002017, 'Mexican Bhel', 'mexican bhel', NULL, 'FUSION FOOD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican bhel'),
    -- items[4] Corn Cheese Bhel
    (400086002109, 400086002017, 'Corn Cheese Bhel', 'corn cheese bhel', NULL, 'FUSION FOOD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'corn cheese bhel'),
    -- items[5] Pav Bhaji Bunny Chow
    (400086002110, 400086002017, 'Pav Bhaji Bunny Chow', 'pav bhaji bunny chow', NULL, 'FUSION FOOD', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'pav bhaji bunny chow'),
    -- items[6] Soya Keema Bunny Chow
    (400086002111, 400086002017, 'Soya Keema Bunny Chow', 'soya keema bunny chow', NULL, 'FUSION FOOD', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'soya keema bunny chow')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002110, 400086002105, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002111, 400086002106, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002112, 400086002107, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002113, 400086002108, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002114, 400086002109, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002115, 400086002110, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002116, 400086002111, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002110, 400086002110, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002111, 400086002111, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002112, 400086002112, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002113, 400086002113, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002114, 400086002114, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002115, 400086002115, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002116, 400086002116, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [18/43] ORIENTAL & CONTINENTAL STARTERS  |  JSON: pages[3].sections[5]  (TFT04.jpg, column 2; 19 JSON line(s) -> 19 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Cheese Cigar
    (400086002112, 400086002018, 'Cheese Cigar', 'cheese cigar', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese cigar'),
    -- items[1] Mushroom Cheese Stuff
    (400086002113, 400086002018, 'Mushroom Cheese Stuff', 'mushroom cheese stuff', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'mushroom cheese stuff'),
    -- items[2] Paneer Pattaya
    (400086002114, 400086002018, 'Paneer Pattaya', 'paneer pattaya', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer pattaya'),
    -- items[3] Butter Garlic Paneer
    (400086002115, 400086002018, 'Butter Garlic Paneer', 'butter garlic paneer', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'butter garlic paneer'),
    -- items[4] Cheese Marble
    (400086002116, 400086002018, 'Cheese Marble', 'cheese marble', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese marble'),
    -- items[5] Paneer Lemon Coriander
    (400086002117, 400086002018, 'Paneer Lemon Coriander', 'paneer lemon coriander', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer lemon coriander'),
    -- items[6] Paneer Chilli Dry
    (400086002118, 400086002018, 'Paneer Chilli Dry', 'paneer chilli dry', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli dry'),
    -- items[7] Veg Crispy
    (400086002119, 400086002018, 'Veg Crispy', 'veg crispy', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg crispy'),
    -- items[8] Paneer Satay
    (400086002120, 400086002018, 'Paneer Satay', 'paneer satay', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer satay'),
    -- items[9] Manchurian Chilli Dry
    (400086002121, 400086002018, 'Manchurian Chilli Dry', 'manchurian chilli dry', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'manchurian chilli dry'),
    -- items[10] Paneer Hot Dragon
    (400086002122, 400086002018, 'Paneer Hot Dragon', 'paneer hot dragon', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer hot dragon'),
    -- items[11] Kung Pao (Paneer / Mushroom)
    (400086002123, 400086002018, 'Kung Pao (Paneer / Mushroom)', 'kung pao (paneer / mushroom)', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kung pao (paneer / mushroom)'),
    -- items[12] Paneer Red Pepper
    (400086002124, 400086002018, 'Paneer Red Pepper', 'paneer red pepper', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer red pepper'),
    -- items[13] Thai Basil Paneer
    (400086002125, 400086002018, 'Thai Basil Paneer', 'thai basil paneer', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'thai basil paneer'),
    -- items[14] Paneer Shanghai
    (400086002126, 400086002018, 'Paneer Shanghai', 'paneer shanghai', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer shanghai'),
    -- items[15] Lotus Stem Crispy
    (400086002127, 400086002018, 'Lotus Stem Crispy', 'lotus stem crispy', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'lotus stem crispy'),
    -- items[16] Cheese Croquettes in Siracha Sauce
    (400086002128, 400086002018, 'Cheese Croquettes in Siracha Sauce', 'cheese croquettes in siracha sauce', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese croquettes in siracha sauce'),
    -- items[17] Mushroom Chilli Dry
    (400086002129, 400086002018, 'Mushroom Chilli Dry', 'mushroom chilli dry', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom chilli dry'),
    -- items[18] Paneer ABC
    (400086002130, 400086002018, 'Paneer ABC', 'paneer abc', NULL, 'ORIENTAL & CONTINENTAL STARTERS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer abc')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002117, 400086002112, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002118, 400086002113, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002119, 400086002114, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002120, 400086002115, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002121, 400086002116, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002122, 400086002117, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002123, 400086002118, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002124, 400086002119, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002125, 400086002120, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002126, 400086002121, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002127, 400086002122, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002128, 400086002123, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002129, 400086002124, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002130, 400086002125, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002131, 400086002126, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002132, 400086002127, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002133, 400086002128, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002134, 400086002129, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002135, 400086002130, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002117, 400086002117, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002118, 400086002118, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002119, 400086002119, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002120, 400086002120, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002121, 400086002121, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002122, 400086002122, 360.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002123, 400086002123, 360.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002124, 400086002124, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002125, 400086002125, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002126, 400086002126, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002127, 400086002127, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002128, 400086002128, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002129, 400086002129, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002130, 400086002130, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002131, 400086002131, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002132, 400086002132, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002133, 400086002133, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002134, 400086002134, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002135, 400086002135, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [19/43] INDIAN & TANDOOR STARTER  |  JSON: pages[4].sections[0]  (TFT05.jpg, column 1; 20 JSON line(s) -> 20 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paneer Shole Tikka
    (400086002131, 400086002019, 'Paneer Shole Tikka', 'paneer shole tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer shole tikka'),
    -- items[1] Paneer Hill Top
    (400086002132, 400086002019, 'Paneer Hill Top', 'paneer hill top', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer hill top'),
    -- items[2] Paneer Tikka
    (400086002133, 400086002019, 'Paneer Tikka', 'paneer tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka'),
    -- items[3] Galouti Kebab
    (400086002134, 400086002019, 'Galouti Kebab', 'galouti kebab', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'galouti kebab'),
    -- items[4] Paneer Firangi
    (400086002135, 400086002019, 'Paneer Firangi', 'paneer firangi', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer firangi'),
    -- items[5] Paneer Lasooni Tikka
    (400086002136, 400086002019, 'Paneer Lasooni Tikka', 'paneer lasooni tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'paneer lasooni tikka'),
    -- items[6] Paneer Afgani Tikka
    (400086002137, 400086002019, 'Paneer Afgani Tikka', 'paneer afgani tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer afgani tikka'),
    -- items[7] Paneer Rangrez
    (400086002138, 400086002019, 'Paneer Rangrez', 'paneer rangrez', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer rangrez'),
    -- items[8] Mushroom Tikka
    (400086002139, 400086002019, 'Mushroom Tikka', 'mushroom tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom tikka'),
    -- items[9] Veg Seekh Kebab
    (400086002140, 400086002019, 'Veg Seekh Kebab', 'veg seekh kebab', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg seekh kebab'),
    -- items[10] Banjara Seekh Kebab
    (400086002141, 400086002019, 'Banjara Seekh Kebab', 'banjara seekh kebab', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'banjara seekh kebab'),
    -- items[11] TFT Spl Tikka
    (400086002142, 400086002019, 'TFT Spl Tikka', 'tft spl tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tft spl tikka'),
    -- items[12] Paneer Malai Tikka
    (400086002143, 400086002019, 'Paneer Malai Tikka', 'paneer malai tikka', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer malai tikka'),
    -- items[13] Paneer Achari
    (400086002144, 400086002019, 'Paneer Achari', 'paneer achari', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer achari'),
    -- items[14] Bhatti Wale Aloo
    (400086002145, 400086002019, 'Bhatti Wale Aloo', 'bhatti wale aloo', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'bhatti wale aloo'),
    -- items[15] Hara Bhara Kebab
    (400086002146, 400086002019, 'Hara Bhara Kebab', 'hara bhara kebab', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'hara bhara kebab'),
    -- items[16] Kaju Methi Roll
    (400086002147, 400086002019, 'Kaju Methi Roll', 'kaju methi roll', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'kaju methi roll'),
    -- items[17] Pahadi Aloo Kothi Wale
    (400086002148, 400086002019, 'Pahadi Aloo Kothi Wale', 'pahadi aloo kothi wale', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'pahadi aloo kothi wale'),
    -- items[18] Subz Kurkure Tikki
    (400086002149, 400086002019, 'Subz Kurkure Tikki', 'subz kurkure tikki', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'subz kurkure tikki'),
    -- items[19] Assorted Tandoor Platter
    (400086002150, 400086002019, 'Assorted Tandoor Platter', 'assorted tandoor platter', NULL, 'INDIAN & TANDOOR STARTER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'assorted tandoor platter')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002136, 400086002131, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002137, 400086002132, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002138, 400086002133, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002139, 400086002134, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002140, 400086002135, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002141, 400086002136, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002142, 400086002137, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002143, 400086002138, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002144, 400086002139, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002145, 400086002140, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002146, 400086002141, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002147, 400086002142, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002148, 400086002143, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002149, 400086002144, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002150, 400086002145, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002151, 400086002146, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002152, 400086002147, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002153, 400086002148, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002154, 400086002149, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002155, 400086002150, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002136, 400086002136, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002137, 400086002137, 430.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002138, 400086002138, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002139, 400086002139, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002140, 400086002140, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002141, 400086002141, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002142, 400086002142, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002143, 400086002143, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002144, 400086002144, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002145, 400086002145, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002146, 400086002146, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002147, 400086002147, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002148, 400086002148, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002149, 400086002149, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002150, 400086002150, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002151, 400086002151, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002152, 400086002152, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002153, 400086002153, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002154, 400086002154, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002155, 400086002155, 560.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [20/43] RISOTTO RICE  |  JSON: pages[4].sections[1]  (TFT05.jpg, column 1; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] 4 Cheese Risotto
    (400086002151, 400086002020, '4 Cheese Risotto', '4 cheese risotto', NULL, 'RISOTTO RICE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', '4 cheese risotto'),
    -- items[1] Pesto Risotto
    (400086002152, 400086002020, 'Pesto Risotto', 'pesto risotto', NULL, 'RISOTTO RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'pesto risotto'),
    -- items[2] Tomato Basil Risotto
    (400086002153, 400086002020, 'Tomato Basil Risotto', 'tomato basil risotto', NULL, 'RISOTTO RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tomato basil risotto'),
    -- items[3] Creamy Fungi Risotto
    (400086002154, 400086002020, 'Creamy Fungi Risotto', 'creamy fungi risotto', NULL, 'RISOTTO RICE', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'creamy fungi risotto'),
    -- items[4] Pink Tango Risotto
    (400086002155, 400086002020, 'Pink Tango Risotto', 'pink tango risotto', NULL, 'RISOTTO RICE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'pink tango risotto')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002156, 400086002151, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002157, 400086002152, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002158, 400086002153, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002159, 400086002154, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002160, 400086002155, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002156, 400086002156, 460.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002157, 400086002157, 440.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002158, 400086002158, 430.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002159, 400086002159, 440.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002160, 400086002160, 450.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [21/43] SIZZLER  |  JSON: pages[4].sections[2]  (TFT05.jpg, column 2; 12 JSON line(s) -> 12 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Mexican Sizzler
    (400086002156, 400086002021, 'Mexican Sizzler', 'mexican sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican sizzler'),
    -- items[1] Oriental Sizzler
    (400086002157, 400086002021, 'Oriental Sizzler', 'oriental sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'oriental sizzler'),
    -- items[2] Paneer Shashlik Sizzler
    (400086002158, 400086002021, 'Paneer Shashlik Sizzler', 'paneer shashlik sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer shashlik sizzler'),
    -- items[3] Pav Bhaji Sizzler
    (400086002159, 400086002021, 'Pav Bhaji Sizzler', 'pav bhaji sizzler', '(Masala Pav, Tawa Pulav, Pav Bhaji)', 'SIZZLER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'pav bhaji sizzler'),
    -- items[4] Veg Pepper Sizzler
    (400086002160, 400086002021, 'Veg Pepper Sizzler', 'veg pepper sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg pepper sizzler'),
    -- items[5] Mushroom Pepper Sizzler
    (400086002161, 400086002021, 'Mushroom Pepper Sizzler', 'mushroom pepper sizzler', NULL, 'SIZZLER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom pepper sizzler'),
    -- items[6] European Sizzler
    (400086002162, 400086002021, 'European Sizzler', 'european sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'european sizzler'),
    -- items[7] Paneer Chilli Sizzler
    (400086002163, 400086002021, 'Paneer Chilli Sizzler', 'paneer chilli sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli sizzler'),
    -- items[8] Tandoori Momos Sizzler
    (400086002164, 400086002021, 'Tandoori Momos Sizzler', 'tandoori momos sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tandoori momos sizzler'),
    -- items[9] Thai Sizzler
    (400086002165, 400086002021, 'Thai Sizzler', 'thai sizzler', NULL, 'SIZZLER', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thai sizzler'),
    -- items[10] Garlic Coriander Sizzler
    (400086002166, 400086002021, 'Garlic Coriander Sizzler', 'garlic coriander sizzler', NULL, 'SIZZLER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'garlic coriander sizzler'),
    -- items[11] Hot Garlic Sizzler
    (400086002167, 400086002021, 'Hot Garlic Sizzler', 'hot garlic sizzler', NULL, 'SIZZLER', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'hot garlic sizzler')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002161, 400086002156, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002162, 400086002156, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002163, 400086002157, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002164, 400086002157, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002165, 400086002158, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002166, 400086002158, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002167, 400086002159, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002168, 400086002159, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002169, 400086002160, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002170, 400086002160, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002171, 400086002161, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002172, 400086002161, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002173, 400086002162, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002174, 400086002162, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002175, 400086002163, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002176, 400086002163, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002177, 400086002164, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002178, 400086002164, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002179, 400086002165, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002180, 400086002165, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002181, 400086002166, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002182, 400086002166, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002183, 400086002167, 'Regular', 'R', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002184, 400086002167, 'Large', 'L', 'fixed', NULL, NULL, 2, FALSE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002161, 400086002161, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002162, 400086002162, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002163, 400086002163, 580.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002164, 400086002164, 670.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002165, 400086002165, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002166, 400086002166, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002167, 400086002167, 580.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002168, 400086002168, 670.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002169, 400086002169, 560.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002170, 400086002170, 670.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002171, 400086002171, 560.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002172, 400086002172, 670.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002173, 400086002173, 570.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002174, 400086002174, 670.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002175, 400086002175, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002176, 400086002176, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002177, 400086002177, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002178, 400086002178, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002179, 400086002179, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002180, 400086002180, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002181, 400086002181, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002182, 400086002182, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002183, 400086002183, 590.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002184, 400086002184, 690.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [22/43] EXTRA TOPPINGS  |  JSON: pages[4].sections[3]  (TFT05.jpg, column 2; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Butter
    (400086002168, 400086002022, 'Butter', 'butter', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[1] Cheese
    (400086002169, 400086002022, 'Cheese', 'cheese', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[2] Mayonaise
    (400086002170, 400086002022, 'Mayonaise', 'mayonaise', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[3] Paneer
    (400086002171, 400086002022, 'Paneer', 'paneer', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[4] Sweet Corn
    (400086002172, 400086002022, 'Sweet Corn', 'sweet corn', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', NULL),
    -- items[5] Veggies
    (400086002173, 400086002022, 'Veggies', 'veggies', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', NULL),
    -- items[6] Schezwan Sauce
    (400086002174, 400086002022, 'Schezwan Sauce', 'schezwan sauce', NULL, 'EXTRA TOPPINGS', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', NULL)
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002185, 400086002168, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002186, 400086002169, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002187, 400086002170, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002188, 400086002171, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002189, 400086002172, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002190, 400086002173, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002191, 400086002174, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002185, 400086002185, 60.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002186, 400086002186, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002187, 400086002187, 60.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002188, 400086002188, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002189, 400086002189, 60.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002190, 400086002190, 70.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002191, 400086002191, 70.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [23/43] ORIENTAL & THAI RICE SERVED WITH GRAVY  |  JSON: pages[4].sections[4]  (TFT05.jpg, column 2; 11 JSON line(s) -> 11 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] TFT Special Rice
    (400086002175, 400086002023, 'TFT Special Rice', 'tft special rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tft special rice'),
    -- items[1] Thai Pot Rice
    (400086002176, 400086002023, 'Thai Pot Rice', 'thai pot rice', '(Red / Yellow / Green)', 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thai pot rice'),
    -- items[2] Paneer Chilli Rice
    (400086002177, 400086002023, 'Paneer Chilli Rice', 'paneer chilli rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli rice'),
    -- items[3] Korean Rice
    (400086002178, 400086002023, 'Korean Rice', 'korean rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'korean rice'),
    -- items[4] Manchurian Rice
    (400086002179, 400086002023, 'Manchurian Rice', 'manchurian rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'manchurian rice'),
    -- items[5] Mexican Pot Rice
    (400086002180, 400086002023, 'Mexican Pot Rice', 'mexican pot rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'mexican pot rice'),
    -- items[6] Triple Schezwan Rice
    (400086002181, 400086002023, 'Triple Schezwan Rice', 'triple schezwan rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'triple schezwan rice'),
    -- items[7] Hot Garlic Rice
    (400086002182, 400086002023, 'Hot Garlic Rice', 'hot garlic rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'hot garlic rice'),
    -- items[8] Burrito Bowl
    (400086002183, 400086002023, 'Burrito Bowl', 'burrito bowl', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'burrito bowl'),
    -- items[9] Burmese Khow Suey
    (400086002184, 400086002023, 'Burmese Khow Suey', 'burmese khow suey', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'burmese khow suey'),
    -- items[10] Thousand Rice
    (400086002185, 400086002023, 'Thousand Rice', 'thousand rice', NULL, 'ORIENTAL & THAI RICE SERVED WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thousand rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002192, 400086002175, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002193, 400086002176, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002194, 400086002177, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002195, 400086002178, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002196, 400086002179, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002197, 400086002180, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002198, 400086002181, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002199, 400086002182, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002200, 400086002183, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002201, 400086002184, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002202, 400086002185, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002192, 400086002192, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002193, 400086002193, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002194, 400086002194, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002195, 400086002195, 520.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002196, 400086002196, 480.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002197, 400086002197, 490.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002198, 400086002198, 550.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002199, 400086002199, 480.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002200, 400086002200, 520.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002201, 400086002201, 530.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002202, 400086002202, 480.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [24/43] ORIENTAL & THAI RICE  |  JSON: pages[5].sections[0]  (TFT06.jpg, column 1; 10 JSON line(s) -> 10 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Fried Rice
    (400086002186, 400086002024, 'Fried Rice', 'fried rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'fried rice'),
    -- items[1] Schezwan Rice
    (400086002187, 400086002024, 'Schezwan Rice', 'schezwan rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'schezwan rice'),
    -- items[2] Burn Garlic Rice
    (400086002188, 400086002024, 'Burn Garlic Rice', 'burn garlic rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'burn garlic rice'),
    -- items[3] Chilli Garlic Rice
    (400086002189, 400086002024, 'Chilli Garlic Rice', 'chilli garlic rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'chilli garlic rice'),
    -- items[4] Combination Rice
    (400086002190, 400086002024, 'Combination Rice', 'combination rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'combination rice'),
    -- items[5] Exotic Rice
    (400086002191, 400086002024, 'Exotic Rice', 'exotic rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'exotic rice'),
    -- items[6] Hong Kong Rice
    (400086002192, 400086002024, 'Hong Kong Rice', 'hong kong rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'hong kong rice'),
    -- items[7] Singapuri Rice
    (400086002193, 400086002024, 'Singapuri Rice', 'singapuri rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'singapuri rice'),
    -- items[8] Thai Basil / Oregano Rice
    (400086002194, 400086002024, 'Thai Basil / Oregano Rice', 'thai basil / oregano rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thai basil / oregano rice'),
    -- items[9] Thai Coriander / Garlic Rice
    (400086002195, 400086002024, 'Thai Coriander / Garlic Rice', 'thai coriander / garlic rice', NULL, 'ORIENTAL & THAI RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thai coriander / garlic rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002203, 400086002186, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002204, 400086002187, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002205, 400086002188, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002206, 400086002189, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002207, 400086002190, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002208, 400086002191, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002209, 400086002192, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002210, 400086002193, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002211, 400086002194, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002212, 400086002195, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002203, 400086002203, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002204, 400086002204, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002205, 400086002205, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002206, 400086002206, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002207, 400086002207, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002208, 400086002208, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002209, 400086002209, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002210, 400086002210, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002211, 400086002211, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002212, 400086002212, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [25/43] NOODLES  |  JSON: pages[5].sections[1]  (TFT06.jpg, column 2; 6 JSON line(s) -> 6 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Veg Hakka Noodles
    (400086002196, 400086002025, 'Veg Hakka Noodles', 'veg hakka noodles', NULL, 'NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg hakka noodles'),
    -- items[1] Schezwan Noodles
    (400086002197, 400086002025, 'Schezwan Noodles', 'schezwan noodles', NULL, 'NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'schezwan noodles'),
    -- items[2] Chilli Garlic Noodles
    (400086002198, 400086002025, 'Chilli Garlic Noodles', 'chilli garlic noodles', NULL, 'NOODLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'chilli garlic noodles'),
    -- items[3] Burn Garlic Noodles
    (400086002199, 400086002025, 'Burn Garlic Noodles', 'burn garlic noodles', NULL, 'NOODLES', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'burn garlic noodles'),
    -- items[4] Hong Kong Noodles
    (400086002200, 400086002025, 'Hong Kong Noodles', 'hong kong noodles', NULL, 'NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'hong kong noodles'),
    -- items[5] Singapuri Noodles
    (400086002201, 400086002025, 'Singapuri Noodles', 'singapuri noodles', NULL, 'NOODLES', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'singapuri noodles')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002213, 400086002196, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002214, 400086002197, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002215, 400086002198, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002216, 400086002199, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002217, 400086002200, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002218, 400086002201, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002213, 400086002213, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002214, 400086002214, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002215, 400086002215, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002216, 400086002216, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002217, 400086002217, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002218, 400086002218, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [26/43] NOODLES WITH GRAVY  |  JSON: pages[5].sections[2]  (TFT06.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Triple Schezwan Noodles
    (400086002202, 400086002026, 'Triple Schezwan Noodles', 'triple schezwan noodles', NULL, 'NOODLES WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'triple schezwan noodles'),
    -- items[1] Paneer Chilli Noodles
    (400086002203, 400086002026, 'Paneer Chilli Noodles', 'paneer chilli noodles', NULL, 'NOODLES WITH GRAVY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli noodles'),
    -- items[2] TFT Spl Noodles
    (400086002204, 400086002026, 'TFT Spl Noodles', 'tft spl noodles', NULL, 'NOODLES WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tft spl noodles'),
    -- items[3] Thousand Noodles
    (400086002205, 400086002026, 'Thousand Noodles', 'thousand noodles', NULL, 'NOODLES WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thousand noodles'),
    -- items[4] Korean Noodles
    (400086002206, 400086002026, 'Korean Noodles', 'korean noodles', NULL, 'NOODLES WITH GRAVY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'korean noodles')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002219, 400086002202, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002220, 400086002203, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002221, 400086002204, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002222, 400086002205, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002223, 400086002206, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002219, 400086002219, 520.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002220, 400086002220, 480.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002221, 400086002221, 480.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002222, 400086002222, 460.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002223, 400086002223, 470.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [27/43] ORIENTAL GRAVY & THAI CURRY  |  JSON: pages[5].sections[3]  (TFT06.jpg, column 1; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Hot Garlic Gravy
    (400086002207, 400086002027, 'Hot Garlic Gravy', 'hot garlic gravy', '(Veg / Paneer)', 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, FALSE, FALSE, TRUE, NULL, 'unverified', 'hot garlic gravy'),
    -- items[1] Thai Curry
    (400086002208, 400086002027, 'Thai Curry', 'thai curry', '(Red / Yellow / Green)', 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'thai curry'),
    -- items[2] Peri Peri Curry
    (400086002209, 400086002027, 'Peri Peri Curry', 'peri peri curry', NULL, 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'peri peri curry'),
    -- items[3] Paneer Chilli Gravy
    (400086002210, 400086002027, 'Paneer Chilli Gravy', 'paneer chilli gravy', NULL, 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer chilli gravy'),
    -- items[4] Manchurian Chilli Gravy
    (400086002211, 400086002027, 'Manchurian Chilli Gravy', 'manchurian chilli gravy', NULL, 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'manchurian chilli gravy'),
    -- items[5] Basil Chilli Gravy
    (400086002212, 400086002027, 'Basil Chilli Gravy', 'basil chilli gravy', NULL, 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'basil chilli gravy'),
    -- items[6] Kung Pao Gravy
    (400086002213, 400086002027, 'Kung Pao Gravy', 'kung pao gravy', '(Veg / Veg Ball / Paneer)', 'ORIENTAL GRAVY & THAI CURRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kung pao gravy')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002224, 400086002207, 'Veg', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002225, 400086002207, 'Paneer', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002226, 400086002208, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002227, 400086002209, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002228, 400086002210, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002229, 400086002211, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002230, 400086002212, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002231, 400086002213, 'Veg', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002232, 400086002213, 'Veg Ball', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002233, 400086002213, 'Paneer', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002224, 400086002224, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002225, 400086002225, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002226, 400086002226, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002227, 400086002227, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002228, 400086002228, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002229, 400086002229, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002230, 400086002230, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002231, 400086002231, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002232, 400086002232, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002233, 400086002233, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002);

-- [28/43] INDIAN MAIN COURSE  |  JSON: pages[5].sections[4]  (TFT06.jpg, column 2; 19 JSON line(s) -> 19 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Paneer Tikka Masala
    (400086002214, 400086002028, 'Paneer Tikka Masala', 'paneer tikka masala', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka masala'),
    -- items[1] Paneer Makhmali
    (400086002215, 400086002028, 'Paneer Makhmali', 'paneer makhmali', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer makhmali'),
    -- items[2] Kadai Paneer
    (400086002216, 400086002028, 'Kadai Paneer', 'kadai paneer', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kadai paneer'),
    -- items[3] Palak Paneer
    (400086002217, 400086002028, 'Palak Paneer', 'palak paneer', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'palak paneer'),
    -- items[4] Paneer Lahori
    (400086002218, 400086002028, 'Paneer Lahori', 'paneer lahori', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer lahori'),
    -- items[5] Paneer Mutter Masala
    (400086002219, 400086002028, 'Paneer Mutter Masala', 'paneer mutter masala', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer mutter masala'),
    -- items[6] Paneer Bali Amritsari
    (400086002220, 400086002028, 'Paneer Bali Amritsari', 'paneer bali amritsari', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer bali amritsari'),
    -- items[7] Paneer Butter Masala
    (400086002221, 400086002028, 'Paneer Butter Masala', 'paneer butter masala', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer butter masala'),
    -- items[8] Paneer Malai Kofta
    (400086002222, 400086002028, 'Paneer Malai Kofta', 'paneer malai kofta', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer malai kofta'),
    -- items[9] Paneer Khurchan
    (400086002223, 400086002028, 'Paneer Khurchan', 'paneer khurchan', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer khurchan'),
    -- items[10] Paneer Parat
    (400086002224, 400086002028, 'Paneer Parat', 'paneer parat', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer parat'),
    -- items[11] Paneer Mumtaz
    (400086002225, 400086002028, 'Paneer Mumtaz', 'paneer mumtaz', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer mumtaz'),
    -- items[12] Paneer Pahadi Tikka Masala
    (400086002226, 400086002028, 'Paneer Pahadi Tikka Masala', 'paneer pahadi tikka masala', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer pahadi tikka masala'),
    -- items[13] Paneer Lababdar
    (400086002227, 400086002028, 'Paneer Lababdar', 'paneer lababdar', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer lababdar'),
    -- items[14] Paneer Lazeez
    (400086002228, 400086002028, 'Paneer Lazeez', 'paneer lazeez', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer lazeez'),
    -- items[15] Paneer Angaara
    (400086002229, 400086002028, 'Paneer Angaara', 'paneer angaara', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer angaara'),
    -- items[16] Paneer Nawabi
    (400086002230, 400086002028, 'Paneer Nawabi', 'paneer nawabi', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer nawabi'),
    -- items[17] Paneer Bhuna Masala
    (400086002231, 400086002028, 'Paneer Bhuna Masala', 'paneer bhuna masala', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer bhuna masala'),
    -- items[18] Kaju Paneer Masala
    (400086002232, 400086002028, 'Kaju Paneer Masala', 'kaju paneer masala', NULL, 'INDIAN MAIN COURSE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kaju paneer masala')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002234, 400086002214, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002235, 400086002215, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002236, 400086002216, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002237, 400086002217, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002238, 400086002218, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002239, 400086002219, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002240, 400086002220, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002241, 400086002221, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002242, 400086002222, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002243, 400086002223, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002244, 400086002224, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002245, 400086002225, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002246, 400086002226, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002247, 400086002227, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002248, 400086002228, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002249, 400086002229, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002250, 400086002230, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002251, 400086002231, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002252, 400086002232, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002234, 400086002234, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002235, 400086002235, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002236, 400086002236, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002237, 400086002237, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002238, 400086002238, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002239, 400086002239, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002240, 400086002240, 440.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002241, 400086002241, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002242, 400086002242, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002243, 400086002243, 410.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002244, 400086002244, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002245, 400086002245, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002246, 400086002246, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002247, 400086002247, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002248, 400086002248, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002249, 400086002249, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002250, 400086002250, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002251, 400086002251, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002252, 400086002252, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [29/43] SABJI TARKARI  |  JSON: pages[6].sections[0]  (TFT07.jpg, column 1; 25 JSON line(s) -> 25 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Veg Kolhapuri
    (400086002233, 400086002029, 'Veg Kolhapuri', 'veg kolhapuri', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg kolhapuri'),
    -- items[1] Veg Kadai
    (400086002234, 400086002029, 'Veg Kadai', 'veg kadai', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg kadai'),
    -- items[2] Veg Keema Masala
    (400086002235, 400086002029, 'Veg Keema Masala', 'veg keema masala', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg keema masala'),
    -- items[3] Sabz Bageecha
    (400086002236, 400086002029, 'Sabz Bageecha', 'sabz bageecha', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sabz bageecha'),
    -- items[4] Veg Angaara
    (400086002237, 400086002029, 'Veg Angaara', 'veg angaara', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg angaara'),
    -- items[5] Lal ka Sabz
    (400086002238, 400086002029, 'Lal ka Sabz', 'lal ka sabz', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'lal ka sabz'),
    -- items[6] Sabz Makhmali
    (400086002239, 400086002029, 'Sabz Makhmali', 'sabz makhmali', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'sabz makhmali'),
    -- items[7] Sunehri Chandan
    (400086002240, 400086002029, 'Sunehri Chandan', 'sunehri chandan', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sunehri chandan'),
    -- items[8] Exotic Bhuna Masala
    (400086002241, 400086002029, 'Exotic Bhuna Masala', 'exotic bhuna masala', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'exotic bhuna masala'),
    -- items[9] Bhatti Wale Aloo Masala
    (400086002242, 400086002029, 'Bhatti Wale Aloo Masala', 'bhatti wale aloo masala', NULL, 'SABJI TARKARI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'bhatti wale aloo masala'),
    -- items[10] Nargisi Kofta
    (400086002243, 400086002029, 'Nargisi Kofta', 'nargisi kofta', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'nargisi kofta'),
    -- items[11] Kaju Masala
    (400086002244, 400086002029, 'Kaju Masala', 'kaju masala', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'kaju masala'),
    -- items[12] Sabz Kasturi
    (400086002245, 400086002029, 'Sabz Kasturi', 'sabz kasturi', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sabz kasturi'),
    -- items[13] Banjara Seekh Masala
    (400086002246, 400086002029, 'Banjara Seekh Masala', 'banjara seekh masala', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'banjara seekh masala'),
    -- items[14] Sabz Chat Pata
    (400086002247, 400086002029, 'Sabz Chat Pata', 'sabz chat pata', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sabz chat pata'),
    -- items[15] Mushroom Tikka Masala
    (400086002248, 400086002029, 'Mushroom Tikka Masala', 'mushroom tikka masala', NULL, 'SABJI TARKARI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'mushroom tikka masala'),
    -- items[16] Sham Savera
    (400086002249, 400086002029, 'Sham Savera', 'sham savera', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sham savera'),
    -- items[17] Veg Lasooni Masala
    (400086002250, 400086002029, 'Veg Lasooni Masala', 'veg lasooni masala', NULL, 'SABJI TARKARI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'veg lasooni masala'),
    -- items[18] Methi Mutter Malai
    (400086002251, 400086002029, 'Methi Mutter Malai', 'methi mutter malai', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'methi mutter malai'),
    -- items[19] Veg Makhanwala
    (400086002252, 400086002029, 'Veg Makhanwala', 'veg makhanwala', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg makhanwala'),
    -- items[20] Sabz Chilli Milly
    (400086002253, 400086002029, 'Sabz Chilli Milly', 'sabz chilli milly', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sabz chilli milly'),
    -- items[21] Sabz Myra
    (400086002254, 400086002029, 'Sabz Myra', 'sabz myra', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'sabz myra'),
    -- items[22] Veg Lucknowi Kofta
    (400086002255, 400086002029, 'Veg Lucknowi Kofta', 'veg lucknowi kofta', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg lucknowi kofta'),
    -- items[23] Navratan Korma
    (400086002256, 400086002029, 'Navratan Korma', 'navratan korma', NULL, 'SABJI TARKARI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'navratan korma'),
    -- items[24] Aloo Mutter Methi
    (400086002257, 400086002029, 'Aloo Mutter Methi', 'aloo mutter methi', NULL, 'SABJI TARKARI', 'veg', NULL, FALSE, NULL, TRUE, NULL, 'unverified', 'aloo mutter methi')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002253, 400086002233, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002254, 400086002234, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002255, 400086002235, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002256, 400086002236, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002257, 400086002237, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002258, 400086002238, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002259, 400086002239, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002260, 400086002240, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002261, 400086002241, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002262, 400086002242, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002263, 400086002243, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002264, 400086002244, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002265, 400086002245, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002266, 400086002246, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002267, 400086002247, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002268, 400086002248, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002269, 400086002249, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002270, 400086002250, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002271, 400086002251, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002272, 400086002252, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002273, 400086002253, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002274, 400086002254, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002275, 400086002255, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002276, 400086002256, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002277, 400086002257, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002253, 400086002253, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002254, 400086002254, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002255, 400086002255, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002256, 400086002256, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002257, 400086002257, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002258, 400086002258, 370.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002259, 400086002259, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002260, 400086002260, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002261, 400086002261, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002262, 400086002262, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002263, 400086002263, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002264, 400086002264, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002265, 400086002265, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002266, 400086002266, 360.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002267, 400086002267, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002268, 400086002268, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002269, 400086002269, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002270, 400086002270, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002271, 400086002271, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002272, 400086002272, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002273, 400086002273, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002274, 400086002274, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002275, 400086002275, 380.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002276, 400086002276, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002277, 400086002277, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [30/43] ROTI  |  JSON: pages[6].sections[1]  (TFT07.jpg, column 2; 17 JSON line(s) -> 17 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Tandoori Roti / Butter Roti
    (400086002258, 400086002030, 'Tandoori Roti / Butter Roti', 'tandoori roti / butter roti', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'tandoori roti / butter roti'),
    -- items[1] Naan / Butter Naan
    (400086002259, 400086002030, 'Naan / Butter Naan', 'naan / butter naan', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'naan / butter naan'),
    -- items[2] Garlic Naan / Garlic Butter Naan
    (400086002260, 400086002030, 'Garlic Naan / Garlic Butter Naan', 'garlic naan / garlic butter naan', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'garlic naan / garlic butter naan'),
    -- items[3] Cheese Naan / Garlic Cheese Naan
    (400086002261, 400086002030, 'Cheese Naan / Garlic Cheese Naan', 'cheese naan / garlic cheese naan', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'cheese naan / garlic cheese naan'),
    -- items[4] Pizza Naan (Spl)
    (400086002262, 400086002030, 'Pizza Naan (Spl)', 'pizza naan (spl)', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'pizza naan (spl)'),
    -- items[5] Plain Lachha Paratha / Butter Lachha Paratha
    (400086002263, 400086002030, 'Plain Lachha Paratha / Butter Lachha Paratha', 'plain lachha paratha / butter lachha paratha', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'plain lachha paratha / butter lachha paratha'),
    -- items[6] Pudina Paratha / Naan / Kulcha
    (400086002264, 400086002030, 'Pudina Paratha / Naan / Kulcha', 'pudina paratha / naan / kulcha', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'pudina paratha / naan / kulcha'),
    -- items[7] Ajwain Paratha / Naan / Kulcha
    (400086002265, 400086002030, 'Ajwain Paratha / Naan / Kulcha', 'ajwain paratha / naan / kulcha', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'ajwain paratha / naan / kulcha'),
    -- items[8] Methi Paratha / Naan / Kulcha
    (400086002266, 400086002030, 'Methi Paratha / Naan / Kulcha', 'methi paratha / naan / kulcha', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'methi paratha / naan / kulcha'),
    -- items[9] Kulcha / Butter Kulcha
    (400086002267, 400086002030, 'Kulcha / Butter Kulcha', 'kulcha / butter kulcha', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kulcha / butter kulcha'),
    -- items[10] Stuff Paneer Kulcha / Stuff Cheese Kulcha
    (400086002268, 400086002030, 'Stuff Paneer Kulcha / Stuff Cheese Kulcha', 'stuff paneer kulcha / stuff cheese kulcha', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'stuff paneer kulcha / stuff cheese kulcha'),
    -- items[11] Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg.
    (400086002269, 400086002030, 'Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg.', 'kulcha stuffing-: aloo, gobi, onion or mix veg.', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'kulcha stuffing-: aloo, gobi, onion or mix veg.'),
    -- items[12] Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg.
    (400086002270, 400086002030, 'Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg.', 'stuffed paratha-: aloo, gobi, onion or mix veg.', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'stuffed paratha-: aloo, gobi, onion or mix veg.'),
    -- items[13] Makai Roti / Bajra Roti / Missi Roti / Garlic Roti
    (400086002271, 400086002030, 'Makai Roti / Bajra Roti / Missi Roti / Garlic Roti', 'makai roti / bajra roti / missi roti / garlic roti', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'makai roti / bajra roti / missi roti / garlic roti'),
    -- items[14] Extra Bhature
    (400086002272, 400086002030, 'Extra Bhature', 'extra bhature', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'extra bhature'),
    -- items[15] Plain Rumali Roti / Butter Rumali Roti
    (400086002273, 400086002030, 'Plain Rumali Roti / Butter Rumali Roti', 'plain rumali roti / butter rumali roti', NULL, 'ROTI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'plain rumali roti / butter rumali roti'),
    -- items[16] Roti Ki Tokri (7 Types of Roti)
    (400086002274, 400086002030, 'Roti Ki Tokri (7 Types of Roti)', 'roti ki tokri (7 types of roti)', NULL, 'ROTI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'roti ki tokri (7 types of roti)')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002278, 400086002258, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002279, 400086002258, 'Butter', 'Butter', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002280, 400086002259, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002281, 400086002259, 'Butter', 'Butter', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002282, 400086002260, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002283, 400086002260, 'Butter', 'Butter', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002284, 400086002261, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002285, 400086002261, 'Garlic Cheese', 'Garlic Cheese', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002286, 400086002262, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002287, 400086002263, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002288, 400086002263, 'Butter', 'Butter', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002289, 400086002264, 'Paratha', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002290, 400086002264, 'Naan', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002291, 400086002264, 'Kulcha', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE),
    (400086002292, 400086002265, 'Paratha', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002293, 400086002265, 'Naan', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002294, 400086002265, 'Kulcha', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE),
    (400086002295, 400086002266, 'Paratha', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002296, 400086002266, 'Naan', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002297, 400086002266, 'Kulcha', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE),
    (400086002298, 400086002267, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002299, 400086002267, 'Butter', 'Butter', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002300, 400086002268, 'Plain', 'Plain', 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002301, 400086002268, 'Stuff Cheese', 'Stuff Cheese', 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002302, 400086002269, 'Aloo', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002303, 400086002269, 'Gobi', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002304, 400086002269, 'Onion', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE),
    (400086002305, 400086002269, 'Mix Veg.', NULL, 'fixed', NULL, NULL, 4, FALSE, TRUE),
    (400086002306, 400086002270, 'Aloo', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002307, 400086002270, 'Gobi', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002308, 400086002270, 'Onion', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE),
    (400086002309, 400086002270, 'Mix Veg.', NULL, 'fixed', NULL, NULL, 4, FALSE, TRUE),
    (400086002310, 400086002271, 'Makai Roti', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002311, 400086002271, 'Bajra Roti', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002312, 400086002271, 'Missi Roti', NULL, 'fixed', NULL, NULL, 3, FALSE, TRUE),
    (400086002313, 400086002271, 'Garlic Roti', NULL, 'fixed', NULL, NULL, 4, FALSE, TRUE),
    (400086002314, 400086002272, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002315, 400086002273, 'Plain', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002316, 400086002273, 'Butter', NULL, 'fixed', NULL, NULL, 2, FALSE, TRUE),
    (400086002317, 400086002274, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002278, 400086002278, 50.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002279, 400086002279, 60.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002280, 400086002280, 70.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002281, 400086002281, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002282, 400086002282, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002283, 400086002283, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002284, 400086002284, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002285, 400086002285, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002286, 400086002286, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002287, 400086002287, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002288, 400086002288, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002289, 400086002289, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002290, 400086002290, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002291, 400086002291, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002292, 400086002292, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002293, 400086002293, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002294, 400086002294, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002295, 400086002295, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002296, 400086002296, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002297, 400086002297, 120.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002298, 400086002298, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002299, 400086002299, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002300, 400086002300, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002301, 400086002301, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002302, 400086002302, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002303, 400086002303, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002304, 400086002304, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002305, 400086002305, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002306, 400086002306, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002307, 400086002307, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002308, 400086002308, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002309, 400086002309, 160.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002310, 400086002310, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002311, 400086002311, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002312, 400086002312, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002313, 400086002313, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400086002),
    (400086002314, 400086002314, 80.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002315, 400086002315, 130.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002316, 400086002316, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002317, 400086002317, 420.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [31/43] RICE  |  JSON: pages[6].sections[2]  (TFT07.jpg, column 2; 9 JSON line(s) -> 9 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Steam Rice
    (400086002275, 400086002031, 'Steam Rice', 'steam rice', NULL, 'RICE', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'steam rice'),
    -- items[1] Jeera Rice
    (400086002276, 400086002031, 'Jeera Rice', 'jeera rice', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'jeera rice'),
    -- items[2] Dal Khichdi
    (400086002277, 400086002031, 'Dal Khichdi', 'dal khichdi', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal khichdi'),
    -- items[3] Dal Khichdi Tadka
    (400086002278, 400086002031, 'Dal Khichdi Tadka', 'dal khichdi tadka', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal khichdi tadka'),
    -- items[4] Palak Khichdi
    (400086002279, 400086002031, 'Palak Khichdi', 'palak khichdi', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'palak khichdi'),
    -- items[5] Veg Pulav
    (400086002280, 400086002031, 'Veg Pulav', 'veg pulav', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg pulav'),
    -- items[6] Kashmiri Pulav
    (400086002281, 400086002031, 'Kashmiri Pulav', 'kashmiri pulav', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'kashmiri pulav'),
    -- items[7] Tawa Pulav
    (400086002282, 400086002031, 'Tawa Pulav', 'tawa pulav', NULL, 'RICE', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'tawa pulav'),
    -- items[8] Curd Rice
    (400086002283, 400086002031, 'Curd Rice', 'curd rice', NULL, 'RICE', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'curd rice')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002318, 400086002275, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002319, 400086002276, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002320, 400086002277, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002321, 400086002278, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002322, 400086002279, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002323, 400086002280, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002324, 400086002281, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002325, 400086002282, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002326, 400086002283, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002318, 400086002318, 240.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002319, 400086002319, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002320, 400086002320, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002321, 400086002321, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002322, 400086002322, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002323, 400086002323, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002324, 400086002324, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002325, 400086002325, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002326, 400086002326, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [32/43] DAL  |  JSON: pages[7].sections[0]  (TFT08.jpg, column 1; 7 JSON line(s) -> 7 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Dal Fry
    (400086002284, 400086002032, 'Dal Fry', 'dal fry', NULL, 'DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal fry'),
    -- items[1] Dal Tadkewali
    (400086002285, 400086002032, 'Dal Tadkewali', 'dal tadkewali', NULL, 'DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal tadkewali'),
    -- items[2] Dal Makhani
    (400086002286, 400086002032, 'Dal Makhani', 'dal makhani', NULL, 'DAL', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'dal makhani'),
    -- items[3] Punjabi Kadi Pakodewali
    (400086002287, 400086002032, 'Punjabi Kadi Pakodewali', 'punjabi kadi pakodewali', NULL, 'DAL', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'punjabi kadi pakodewali'),
    -- items[4] Dal Bukhara
    (400086002288, 400086002032, 'Dal Bukhara', 'dal bukhara', NULL, 'DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'dal bukhara'),
    -- items[5] Methi Wali Dal
    (400086002289, 400086002032, 'Methi Wali Dal', 'methi wali dal', NULL, 'DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'methi wali dal'),
    -- items[6] Palak Wali Dal
    (400086002290, 400086002032, 'Palak Wali Dal', 'palak wali dal', NULL, 'DAL', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'palak wali dal')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002327, 400086002284, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002328, 400086002285, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002329, 400086002286, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002330, 400086002287, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002331, 400086002288, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002332, 400086002289, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002333, 400086002290, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002327, 400086002327, 240.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002328, 400086002328, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002329, 400086002329, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002330, 400086002330, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002331, 400086002331, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002332, 400086002332, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002333, 400086002333, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [33/43] BIRYANI  |  JSON: pages[7].sections[1]  (TFT08.jpg, column 1; 6 JSON line(s) -> 6 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Veg Biryani
    (400086002291, 400086002033, 'Veg Biryani', 'veg biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg biryani'),
    -- items[1] Paneer Tikka Biryani
    (400086002292, 400086002033, 'Paneer Tikka Biryani', 'paneer tikka biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'paneer tikka biryani'),
    -- items[2] Afghani Tikka Biryani
    (400086002293, 400086002033, 'Afghani Tikka Biryani', 'afghani tikka biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'afghani tikka biryani'),
    -- items[3] Soya Keema Biryani
    (400086002294, 400086002033, 'Soya Keema Biryani', 'soya keema biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'soya keema biryani'),
    -- items[4] Kali Handi Dum Biryani
    (400086002295, 400086002033, 'Kali Handi Dum Biryani', 'kali handi dum biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'kali handi dum biryani'),
    -- items[5] Veg Chesse Biryani
    (400086002296, 400086002033, 'Veg Chesse Biryani', 'veg chesse biryani', NULL, 'BIRYANI', 'veg', NULL, NULL, NULL, TRUE, NULL, 'unverified', 'veg chesse biryani')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002334, 400086002291, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002335, 400086002292, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002336, 400086002293, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002337, 400086002294, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002338, 400086002295, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002339, 400086002296, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002334, 400086002334, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002335, 400086002335, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002336, 400086002336, 340.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002337, 400086002337, 350.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002338, 400086002338, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002339, 400086002339, 390.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [34/43] RAITA/PAPAD  |  JSON: pages[7].sections[2]  (TFT08.jpg, column 1; 12 JSON line(s) -> 12 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Curd
    (400086002297, 400086002034, 'Curd', 'curd', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'curd'),
    -- items[1] Veg Raita
    (400086002298, 400086002034, 'Veg Raita', 'veg raita', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'veg raita'),
    -- items[2] Boondi Raita
    (400086002299, 400086002034, 'Boondi Raita', 'boondi raita', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'boondi raita'),
    -- items[3] Pineapple Raita
    (400086002300, 400086002034, 'Pineapple Raita', 'pineapple raita', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'pineapple raita'),
    -- items[4] Fruits Raita
    (400086002301, 400086002034, 'Fruits Raita', 'fruits raita', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'fruits raita'),
    -- items[5] Roasted Papad
    (400086002302, 400086002034, 'Roasted Papad', 'roasted papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'roasted papad'),
    -- items[6] Fry Papad
    (400086002303, 400086002034, 'Fry Papad', 'fry papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'fry papad'),
    -- items[7] Masala Papad
    (400086002304, 400086002034, 'Masala Papad', 'masala papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'masala papad'),
    -- items[8] Khichiya Roasted Papad
    (400086002305, 400086002034, 'Khichiya Roasted Papad', 'khichiya roasted papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'khichiya roasted papad'),
    -- items[9] Khichiya Masala Papad
    (400086002306, 400086002034, 'Khichiya Masala Papad', 'khichiya masala papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'khichiya masala papad'),
    -- items[10] Rumali Masala Papad
    (400086002307, 400086002034, 'Rumali Masala Papad', 'rumali masala papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'rumali masala papad'),
    -- items[11] Rumali Masala Cheese Papad
    (400086002308, 400086002034, 'Rumali Masala Cheese Papad', 'rumali masala cheese papad', NULL, 'RAITA/PAPAD', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'rumali masala cheese papad')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002340, 400086002297, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002341, 400086002298, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002342, 400086002299, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002343, 400086002300, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002344, 400086002301, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002345, 400086002302, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002346, 400086002303, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002347, 400086002304, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002348, 400086002305, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002349, 400086002306, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002350, 400086002307, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002351, 400086002308, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002340, 400086002340, 100.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002341, 400086002341, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002342, 400086002342, 190.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002343, 400086002343, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002344, 400086002344, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002345, 400086002345, 50.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002346, 400086002346, 60.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002347, 400086002347, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002348, 400086002348, 110.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002349, 400086002349, 140.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002350, 400086002350, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002351, 400086002351, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [35/43] FRESH JUICE  |  JSON: pages[7].sections[3]  (TFT08.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Anar
    (400086002309, 400086002035, 'Anar', 'anar', NULL, 'FRESH JUICE', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', NULL),
    -- items[1] Apple
    (400086002310, 400086002035, 'Apple', 'apple', NULL, 'FRESH JUICE', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', NULL),
    -- items[2] Cocktail
    (400086002311, 400086002035, 'Cocktail', 'cocktail', NULL, 'FRESH JUICE', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', NULL),
    -- items[3] Pineapple
    (400086002312, 400086002035, 'Pineapple', 'pineapple', NULL, 'FRESH JUICE', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', NULL),
    -- items[4] Watermelon
    (400086002313, 400086002035, 'Watermelon', 'watermelon', NULL, 'FRESH JUICE', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', NULL)
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002352, 400086002309, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002353, 400086002310, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002354, 400086002311, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002355, 400086002312, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002356, 400086002313, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002352, 400086002352, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002353, 400086002353, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002354, 400086002354, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002355, 400086002355, 180.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002356, 400086002356, 150.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [36/43] MIXOLOGY  |  JSON: pages[7].sections[4]  (TFT08.jpg, column 2; 11 JSON line(s) -> 11 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Jamun Shots
    (400086002314, 400086002036, 'Jamun Shots', 'jamun shots', '(Jamun, Lemon)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'jamun shots'),
    -- items[1] Milanberry
    (400086002315, 400086002036, 'Milanberry', 'milanberry', '(Watermelon, Strawberry)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'milanberry'),
    -- items[2] Meverick
    (400086002316, 400086002036, 'Meverick', 'meverick', '(Kiwi, Strawberry)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'meverick'),
    -- items[3] Cindrella
    (400086002317, 400086002036, 'Cindrella', 'cindrella', '(Kiwi, Litchi, Apple)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'cindrella'),
    -- items[4] Litchi Blast
    (400086002318, 400086002036, 'Litchi Blast', 'litchi blast', '(Black Grapes, Litchi)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'litchi blast'),
    -- items[5] Bloom
    (400086002319, 400086002036, 'Bloom', 'bloom', '(Kiwi, Litchi, Strawberry)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'bloom'),
    -- items[6] Mad Mind
    (400086002320, 400086002036, 'Mad Mind', 'mad mind', '(Guava, Pineapple, Sweet Lime)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'mad mind'),
    -- items[7] Holy Affair
    (400086002321, 400086002036, 'Holy Affair', 'holy affair', '(Strawberry, Pineapple, Grapes)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'holy affair'),
    -- items[8] Sniper
    (400086002322, 400086002036, 'Sniper', 'sniper', '(Kiwi, Orange, Anar)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'sniper'),
    -- items[9] Two Berry
    (400086002323, 400086002036, 'Two Berry', 'two berry', '(Strawberry, Mulberry)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'two berry'),
    -- items[10] Sunrise
    (400086002324, 400086002036, 'Sunrise', 'sunrise', '(Mango, Strawberry)', 'MIXOLOGY', 'veg', NULL, NULL, TRUE, TRUE, NULL, 'unverified', 'sunrise')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002357, 400086002314, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002358, 400086002315, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002359, 400086002316, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002360, 400086002317, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002361, 400086002318, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002362, 400086002319, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002363, 400086002320, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002364, 400086002321, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002365, 400086002322, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002366, 400086002323, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002367, 400086002324, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002357, 400086002357, 270.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002358, 400086002358, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002359, 400086002359, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002360, 400086002360, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002361, 400086002361, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002362, 400086002362, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002363, 400086002363, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002364, 400086002364, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002365, 400086002365, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002366, 400086002366, 270.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002367, 400086002367, 270.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [37/43] FALOODA  |  JSON: pages[7].sections[5]  (TFT08.jpg, column 2; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Royal Falooda
    (400086002325, 400086002037, 'Royal Falooda', 'royal falooda', NULL, 'FALOODA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'royal falooda'),
    -- items[1] Kulfi Falooda
    (400086002326, 400086002037, 'Kulfi Falooda', 'kulfi falooda', NULL, 'FALOODA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kulfi falooda'),
    -- items[2] Dryfruit Falooda
    (400086002327, 400086002037, 'Dryfruit Falooda', 'dryfruit falooda', NULL, 'FALOODA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'dryfruit falooda'),
    -- items[3] Kesar Falooda
    (400086002328, 400086002037, 'Kesar Falooda', 'kesar falooda', NULL, 'FALOODA', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kesar falooda')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002368, 400086002325, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002369, 400086002326, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002370, 400086002327, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002371, 400086002328, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002368, 400086002368, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002369, 400086002369, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002370, 400086002370, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002371, 400086002371, 300.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [38/43] MILK SHAKES - CLASSIC SHAKES  |  JSON: pages[8].sections[0]  (TFT09.jpg, column 1; 9 JSON line(s) -> 9 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Vanilla
    (400086002329, 400086002038, 'Vanilla', 'vanilla', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[1] Cold Coffee
    (400086002330, 400086002038, 'Cold Coffee', 'cold coffee', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[2] Chocolate
    (400086002331, 400086002038, 'Chocolate', 'chocolate', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[3] Butterscotch
    (400086002332, 400086002038, 'Butterscotch', 'butterscotch', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[4] Rose
    (400086002333, 400086002038, 'Rose', 'rose', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[5] Strawberry
    (400086002334, 400086002038, 'Strawberry', 'strawberry', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[6] Mango
    (400086002335, 400086002038, 'Mango', 'mango', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[7] Sitafal
    (400086002336, 400086002038, 'Sitafal', 'sitafal', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[8] Dryfruit
    (400086002337, 400086002038, 'Dryfruit', 'dryfruit', NULL, 'MILK SHAKES - CLASSIC SHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL)
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002372, 400086002329, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002373, 400086002330, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002374, 400086002331, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002375, 400086002332, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002376, 400086002333, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002377, 400086002334, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002378, 400086002335, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002379, 400086002336, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002380, 400086002337, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002372, 400086002372, 200.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002373, 400086002373, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002374, 400086002374, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002375, 400086002375, 220.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002376, 400086002376, 210.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002377, 400086002377, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002378, 400086002378, 330.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002379, 400086002379, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002380, 400086002380, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [39/43] BUTTER MILK  |  JSON: pages[8].sections[1]  (TFT09.jpg, column 1; 2 JSON line(s) -> 2 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Butter Milk Masala
    (400086002338, 400086002039, 'Butter Milk Masala', 'butter milk masala', NULL, 'BUTTER MILK', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'butter milk masala'),
    -- items[1] Butter Milk Plain
    (400086002339, 400086002039, 'Butter Milk Plain', 'butter milk plain', NULL, 'BUTTER MILK', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'butter milk plain')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002381, 400086002338, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002382, 400086002339, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002381, 400086002381, 110.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002382, 400086002382, 90.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [40/43] PREMIUM MILKSHAKES  |  JSON: pages[8].sections[2]  (TFT09.jpg, column 1; 10 JSON line(s) -> 10 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Nutella
    (400086002340, 400086002040, 'Nutella', 'nutella', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[1] Kit Kat
    (400086002341, 400086002040, 'Kit Kat', 'kit kat', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[2] Oreo Milkshake
    (400086002342, 400086002040, 'Oreo Milkshake', 'oreo milkshake', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'oreo milkshake'),
    -- items[3] Chocolate Crunch
    (400086002343, 400086002040, 'Chocolate Crunch', 'chocolate crunch', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[4] Kulfi Milkshake
    (400086002344, 400086002040, 'Kulfi Milkshake', 'kulfi milkshake', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'kulfi milkshake'),
    -- items[5] Black Forest
    (400086002345, 400086002040, 'Black Forest', 'black forest', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[6] Blueberry Milkshake
    (400086002346, 400086002040, 'Blueberry Milkshake', 'blueberry milkshake', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'blueberry milkshake'),
    -- items[7] Brownie Milkshake
    (400086002347, 400086002040, 'Brownie Milkshake', 'brownie milkshake', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'brownie milkshake'),
    -- items[8] Hazelnut Mocha Shake
    (400086002348, 400086002040, 'Hazelnut Mocha Shake', 'hazelnut mocha shake', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'hazelnut mocha shake'),
    -- items[9] Tiramisu Mocha Shake
    (400086002349, 400086002040, 'Tiramisu Mocha Shake', 'tiramisu mocha shake', NULL, 'PREMIUM MILKSHAKES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'tiramisu mocha shake')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002383, 400086002340, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002384, 400086002341, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002385, 400086002342, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002386, 400086002343, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002387, 400086002344, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002388, 400086002345, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002389, 400086002346, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002390, 400086002347, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002391, 400086002348, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002392, 400086002349, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002383, 400086002383, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002384, 400086002384, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002385, 400086002385, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002386, 400086002386, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002387, 400086002387, 270.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002388, 400086002388, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002389, 400086002389, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002390, 400086002390, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002391, 400086002391, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002392, 400086002392, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [41/43] FRUIT WITH CREAM  |  JSON: pages[8].sections[3]  (TFT09.jpg, column 1; 4 JSON line(s) -> 4 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Choco Mocha
    (400086002350, 400086002041, 'Choco Mocha', 'choco mocha', '(Vanilla, Chocolate, Whip Cream, Perk, Dry Fruit)', 'FRUIT WITH CREAM', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'choco mocha'),
    -- items[1] Mix Fruit Cream
    (400086002351, 400086002041, 'Mix Fruit Cream', 'mix fruit cream', NULL, 'FRUIT WITH CREAM', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'mix fruit cream'),
    -- items[2] Sitafal Cream
    (400086002352, 400086002041, 'Sitafal Cream', 'sitafal cream', NULL, 'FRUIT WITH CREAM', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'sitafal cream'),
    -- items[3] Caramel Custard
    (400086002353, 400086002041, 'Caramel Custard', 'caramel custard', NULL, 'FRUIT WITH CREAM', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'caramel custard')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002393, 400086002350, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002394, 400086002351, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002395, 400086002352, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002396, 400086002353, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002393, 400086002393, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002394, 400086002394, 320.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002395, 400086002395, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002396, 400086002396, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [42/43] PASTRY  |  JSON: pages[8].sections[4]  (TFT09.jpg, column 2; 5 JSON line(s) -> 5 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Belgium Chocolate
    (400086002354, 400086002042, 'Belgium Chocolate', 'belgium chocolate', NULL, 'PASTRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', NULL),
    -- items[1] Nutella Cheese Cake
    (400086002355, 400086002042, 'Nutella Cheese Cake', 'nutella cheese cake', NULL, 'PASTRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'nutella cheese cake'),
    -- items[2] Blueberry Cheese Cake
    (400086002356, 400086002042, 'Blueberry Cheese Cake', 'blueberry cheese cake', NULL, 'PASTRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'blueberry cheese cake'),
    -- items[3] Strawberry Cheese Cake
    (400086002357, 400086002042, 'Strawberry Cheese Cake', 'strawberry cheese cake', NULL, 'PASTRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'strawberry cheese cake'),
    -- items[4] Biscoff Cheese Cake
    (400086002358, 400086002042, 'Biscoff Cheese Cake', 'biscoff cheese cake', NULL, 'PASTRY', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'biscoff cheese cake')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002397, 400086002354, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002398, 400086002355, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002399, 400086002356, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002400, 400086002357, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002401, 400086002358, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002397, 400086002397, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002398, 400086002398, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002399, 400086002399, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002400, 400086002400, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002401, 400086002401, 310.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- [43/43] WAFFLES  |  JSON: pages[8].sections[5]  (TFT09.jpg, column 2; 8 JSON line(s) -> 8 item(s))
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                       description, raw_category_text, food_classification_code, protein_type_id,
                       is_jain, is_vegan, is_eggless, split_group_key, verification_status_code)
SELECT v.menu_item_id, 400086002, v.menu_category_id, cd.canonical_dish_id, v.name, v.normalized_name,
       v.description, v.raw_category_text, v.food_classification_code, pt.protein_type_id,
       v.is_jain::boolean, v.is_vegan::boolean, v.is_eggless::boolean, v.split_group_key,
       v.verification_status_code
FROM (VALUES
    -- items[0] Brownie Waffles
    (400086002359, 400086002043, 'Brownie Waffles', 'brownie waffles', '(Waffle Serve With Dark Chocolate Sauce, Crunchy Walnut & With Vanilla Ice-Cream)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'brownie waffles'),
    -- items[1] Crunchy Kit-Kat Waffles
    (400086002360, 400086002043, 'Crunchy Kit-Kat Waffles', 'crunchy kit-kat waffles', '(Waffle Serve With Dark, Milk & White Chocolate Topped With Kit-Kat)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'crunchy kit-kat waffles'),
    -- items[2] Nutella Waffles
    (400086002361, 400086002043, 'Nutella Waffles', 'nutella waffles', '(Dark Chocolate, Milk Chocolate & Nutella)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'nutella waffles'),
    -- items[3] Overload Chocolate Waffles
    (400086002362, 400086002043, 'Overload Chocolate Waffles', 'overload chocolate waffles', '(Waffle Serve With Dark, Milk & White Chocolate Garnish With Choco Chips)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'overload chocolate waffles'),
    -- items[4] Naughty Nuts Waffles
    (400086002363, 400086002043, 'Naughty Nuts Waffles', 'naughty nuts waffles', '(Waffle Serve With Dark, Milk & White Chocolate Topped With Naughty Crunchy Nuts)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'naughty nuts waffles'),
    -- items[5] Authentic Belgium Waffles
    (400086002364, 400086002043, 'Authentic Belgium Waffles', 'authentic belgium waffles', '(Waffle Serve With Butter & Maple Syrup)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'authentic belgium waffles'),
    -- items[6] Oreo Waffles
    (400086002365, 400086002043, 'Oreo Waffles', 'oreo waffles', '(Waffle Serve With Dark, Milk & White Chocolate Topped With Crunchy Oreo)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'oreo waffles'),
    -- items[7] Gems Magic Waffles
    (400086002366, 400086002043, 'Gems Magic Waffles', 'gems magic waffles', '(Waffle Serve With Dark Chocolate Sauce, Vanilla Ice-Cream Topped With Colourful Gems)', 'WAFFLES', 'veg', NULL, NULL, FALSE, TRUE, NULL, 'unverified', 'gems magic waffles')
) AS v(menu_item_id, menu_category_id, name, normalized_name, description, raw_category_text,
       food_classification_code, protein_code, is_jain, is_vegan, is_eggless, split_group_key,
       verification_status_code, canon_norm)
LEFT JOIN protein_type pt ON upper(pt.code) = v.protein_code
LEFT JOIN LATERAL (SELECT d.canonical_dish_id FROM canonical_dish d
                   WHERE d.normalized_name = v.canon_norm ORDER BY d.canonical_dish_id LIMIT 1) cd ON TRUE;
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, variant_code, pricing_basis_code,
                               quantity_value, quantity_unit_code, display_sequence, is_default, is_active)
VALUES
    (400086002402, 400086002359, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002403, 400086002360, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002404, 400086002361, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002405, 400086002362, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002406, 400086002363, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002407, 400086002364, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002408, 400086002365, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE),
    (400086002409, 400086002366, 'Regular', NULL, 'fixed', NULL, NULL, 1, TRUE, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code,
                             tax_rate, effective_from, verification_status_code, source_id)
VALUES
    (400086002402, 400086002402, 290.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002403, 400086002403, 250.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002404, 400086002404, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002405, 400086002405, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002406, 400086002406, 280.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002407, 400086002407, 230.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002408, 400086002408, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002),
    (400086002409, 400086002409, 260.00, NULL, NULL, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400086002);

-- ----------------------------------------------------------------------------
-- 7. PROVENANCE LINKS (menu_item_source, menu_item_price_source)
-- ----------------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400086002001, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002002, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002003, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002004, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002005, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002006, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002007, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002008, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002009, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002010, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002011, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002012, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002013, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002014, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002015, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002016, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002017, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002018, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002019, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002020, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002021, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002022, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002023, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002024, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002025, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002026, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002027, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002028, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002029, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002030, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002031, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002032, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002033, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002034, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002035, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002036, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002037, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002038, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002039, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002040, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002041, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002042, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002043, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002044, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002045, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002046, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002047, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002048, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002049, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002050, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002051, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002052, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002053, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002054, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002055, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002056, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002057, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002058, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002059, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002060, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002061, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002062, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002063, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002064, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002065, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002066, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002067, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002068, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002069, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002070, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002071, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002072, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002073, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002074, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002075, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002076, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002077, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002078, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002079, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002080, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002081, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002082, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002083, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002084, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002085, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002086, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002087, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002088, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002089, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002090, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002091, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002092, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002093, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002094, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002095, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002096, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002097, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002098, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002099, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002100, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002101, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002102, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002103, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002104, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002105, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002106, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002107, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002108, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002109, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002110, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002111, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002112, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002113, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002114, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002115, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002116, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002117, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002118, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002119, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002120, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002121, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002122, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002123, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002124, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002125, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002126, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002127, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002128, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002129, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002130, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002131, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002132, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002133, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002134, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002135, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002136, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002137, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002138, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002139, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002140, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002141, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002142, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002143, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002144, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002145, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002146, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002147, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002148, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002149, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002150, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002151, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002152, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002153, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002154, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002155, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002156, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002157, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002158, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002159, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002160, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002161, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002162, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002163, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002164, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002165, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002166, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002167, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002168, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002169, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002170, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002171, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002172, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002173, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002174, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002175, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002176, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002177, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002178, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002179, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002180, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002181, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002182, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002183, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002184, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002185, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002186, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002187, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002188, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002189, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002190, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002191, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002192, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002193, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002194, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002195, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002196, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002197, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002198, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002199, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002200, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002201, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002202, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002203, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002204, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002205, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002206, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002207, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002208, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002209, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002210, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002211, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002212, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002213, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002214, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002215, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002216, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002217, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002218, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002219, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002220, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002221, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002222, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002223, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002224, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002225, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002226, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002227, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002228, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002229, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002230, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002231, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002232, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002233, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002234, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002235, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002236, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002237, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002238, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002239, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002240, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002241, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002242, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002243, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002244, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002245, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002246, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002247, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002248, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002249, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002250, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002251, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002252, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002253, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002254, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002255, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002256, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002257, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002258, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002259, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002260, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002261, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002262, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002263, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002264, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002265, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002266, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002267, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002268, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002269, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002270, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002271, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002272, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002273, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002274, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002275, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002276, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002277, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002278, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002279, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002280, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002281, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002282, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002283, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002284, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002285, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002286, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002287, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002288, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002289, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002290, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002291, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002292, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002293, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002294, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002295, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002296, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002297, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002298, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002299, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002300, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002301, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002302, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002303, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002304, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002305, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002306, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002307, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002308, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002309, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002310, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002311, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002312, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002313, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002314, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002315, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002316, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002317, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002318, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002319, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002320, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002321, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002322, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002323, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002324, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002325, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002326, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002327, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002328, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002329, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002330, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002331, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002332, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002333, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002334, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002335, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002336, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002337, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002338, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002339, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002340, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002341, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002342, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002343, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002344, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002345, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002346, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002347, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002348, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002349, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002350, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002351, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002352, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002353, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002354, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002355, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002356, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002357, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002358, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002359, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002360, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002361, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002362, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002363, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002364, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002365, 400086002, (:base_batch + 1), 0.95000, 'unverified'),
    (400086002366, 400086002, (:base_batch + 1), 0.95000, 'unverified');
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400086002001, 400086002, (:base_batch + 1), 0.95000),
    (400086002002, 400086002, (:base_batch + 1), 0.95000),
    (400086002003, 400086002, (:base_batch + 1), 0.95000),
    (400086002004, 400086002, (:base_batch + 1), 0.95000),
    (400086002005, 400086002, (:base_batch + 1), 0.95000),
    (400086002006, 400086002, (:base_batch + 1), 0.95000),
    (400086002007, 400086002, (:base_batch + 1), 0.95000),
    (400086002008, 400086002, (:base_batch + 1), 0.95000),
    (400086002009, 400086002, (:base_batch + 1), 0.95000),
    (400086002010, 400086002, (:base_batch + 1), 0.95000),
    (400086002011, 400086002, (:base_batch + 1), 0.95000),
    (400086002012, 400086002, (:base_batch + 1), 0.95000),
    (400086002013, 400086002, (:base_batch + 1), 0.95000),
    (400086002014, 400086002, (:base_batch + 1), 0.95000),
    (400086002015, 400086002, (:base_batch + 1), 0.95000),
    (400086002016, 400086002, (:base_batch + 1), 0.95000),
    (400086002017, 400086002, (:base_batch + 1), 0.95000),
    (400086002018, 400086002, (:base_batch + 1), 0.95000),
    (400086002019, 400086002, (:base_batch + 1), 0.95000),
    (400086002020, 400086002, (:base_batch + 1), 0.95000),
    (400086002021, 400086002, (:base_batch + 1), 0.95000),
    (400086002022, 400086002, (:base_batch + 1), 0.95000),
    (400086002023, 400086002, (:base_batch + 1), 0.95000),
    (400086002024, 400086002, (:base_batch + 1), 0.95000),
    (400086002025, 400086002, (:base_batch + 1), 0.95000),
    (400086002026, 400086002, (:base_batch + 1), 0.95000),
    (400086002027, 400086002, (:base_batch + 1), 0.95000),
    (400086002028, 400086002, (:base_batch + 1), 0.95000),
    (400086002029, 400086002, (:base_batch + 1), 0.95000),
    (400086002030, 400086002, (:base_batch + 1), 0.95000),
    (400086002031, 400086002, (:base_batch + 1), 0.95000),
    (400086002032, 400086002, (:base_batch + 1), 0.95000),
    (400086002033, 400086002, (:base_batch + 1), 0.95000),
    (400086002034, 400086002, (:base_batch + 1), 0.95000),
    (400086002035, 400086002, (:base_batch + 1), 0.95000),
    (400086002036, 400086002, (:base_batch + 1), 0.95000),
    (400086002037, 400086002, (:base_batch + 1), 0.95000),
    (400086002038, 400086002, (:base_batch + 1), 0.95000),
    (400086002039, 400086002, (:base_batch + 1), 0.95000),
    (400086002040, 400086002, (:base_batch + 1), 0.95000),
    (400086002041, 400086002, (:base_batch + 1), 0.95000),
    (400086002042, 400086002, (:base_batch + 1), 0.95000),
    (400086002043, 400086002, (:base_batch + 1), 0.95000),
    (400086002044, 400086002, (:base_batch + 1), 0.95000),
    (400086002045, 400086002, (:base_batch + 1), 0.95000),
    (400086002046, 400086002, (:base_batch + 1), 0.95000),
    (400086002047, 400086002, (:base_batch + 1), 0.95000),
    (400086002048, 400086002, (:base_batch + 1), 0.95000),
    (400086002049, 400086002, (:base_batch + 1), 0.95000),
    (400086002050, 400086002, (:base_batch + 1), 0.85000),
    (400086002051, 400086002, (:base_batch + 1), 0.85000),
    (400086002052, 400086002, (:base_batch + 1), 0.85000),
    (400086002053, 400086002, (:base_batch + 1), 0.85000),
    (400086002054, 400086002, (:base_batch + 1), 0.75000),
    (400086002055, 400086002, (:base_batch + 1), 0.85000),
    (400086002056, 400086002, (:base_batch + 1), 0.85000),
    (400086002057, 400086002, (:base_batch + 1), 0.85000),
    (400086002058, 400086002, (:base_batch + 1), 0.85000),
    (400086002059, 400086002, (:base_batch + 1), 0.85000),
    (400086002060, 400086002, (:base_batch + 1), 0.85000),
    (400086002061, 400086002, (:base_batch + 1), 0.75000),
    (400086002062, 400086002, (:base_batch + 1), 0.75000),
    (400086002063, 400086002, (:base_batch + 1), 0.95000),
    (400086002064, 400086002, (:base_batch + 1), 0.95000),
    (400086002065, 400086002, (:base_batch + 1), 0.95000),
    (400086002066, 400086002, (:base_batch + 1), 0.95000),
    (400086002067, 400086002, (:base_batch + 1), 0.95000),
    (400086002068, 400086002, (:base_batch + 1), 0.95000),
    (400086002069, 400086002, (:base_batch + 1), 0.95000),
    (400086002070, 400086002, (:base_batch + 1), 0.95000),
    (400086002071, 400086002, (:base_batch + 1), 0.95000),
    (400086002072, 400086002, (:base_batch + 1), 0.95000),
    (400086002073, 400086002, (:base_batch + 1), 0.95000),
    (400086002074, 400086002, (:base_batch + 1), 0.95000),
    (400086002075, 400086002, (:base_batch + 1), 0.95000),
    (400086002076, 400086002, (:base_batch + 1), 0.95000),
    (400086002077, 400086002, (:base_batch + 1), 0.95000),
    (400086002078, 400086002, (:base_batch + 1), 0.95000),
    (400086002079, 400086002, (:base_batch + 1), 0.95000),
    (400086002080, 400086002, (:base_batch + 1), 0.95000),
    (400086002081, 400086002, (:base_batch + 1), 0.95000),
    (400086002082, 400086002, (:base_batch + 1), 0.95000),
    (400086002083, 400086002, (:base_batch + 1), 0.95000),
    (400086002084, 400086002, (:base_batch + 1), 0.95000),
    (400086002085, 400086002, (:base_batch + 1), 0.95000),
    (400086002086, 400086002, (:base_batch + 1), 0.95000),
    (400086002087, 400086002, (:base_batch + 1), 0.95000),
    (400086002088, 400086002, (:base_batch + 1), 0.95000),
    (400086002089, 400086002, (:base_batch + 1), 0.95000),
    (400086002090, 400086002, (:base_batch + 1), 0.95000),
    (400086002091, 400086002, (:base_batch + 1), 0.95000),
    (400086002092, 400086002, (:base_batch + 1), 0.95000),
    (400086002093, 400086002, (:base_batch + 1), 0.95000),
    (400086002094, 400086002, (:base_batch + 1), 0.95000),
    (400086002095, 400086002, (:base_batch + 1), 0.95000),
    (400086002096, 400086002, (:base_batch + 1), 0.95000),
    (400086002097, 400086002, (:base_batch + 1), 0.95000),
    (400086002098, 400086002, (:base_batch + 1), 0.95000),
    (400086002099, 400086002, (:base_batch + 1), 0.95000),
    (400086002100, 400086002, (:base_batch + 1), 0.95000),
    (400086002101, 400086002, (:base_batch + 1), 0.95000),
    (400086002102, 400086002, (:base_batch + 1), 0.95000),
    (400086002103, 400086002, (:base_batch + 1), 0.95000),
    (400086002104, 400086002, (:base_batch + 1), 0.95000),
    (400086002105, 400086002, (:base_batch + 1), 0.95000),
    (400086002106, 400086002, (:base_batch + 1), 0.95000),
    (400086002107, 400086002, (:base_batch + 1), 0.95000),
    (400086002108, 400086002, (:base_batch + 1), 0.95000),
    (400086002109, 400086002, (:base_batch + 1), 0.95000),
    (400086002110, 400086002, (:base_batch + 1), 0.95000),
    (400086002111, 400086002, (:base_batch + 1), 0.95000),
    (400086002112, 400086002, (:base_batch + 1), 0.95000),
    (400086002113, 400086002, (:base_batch + 1), 0.95000),
    (400086002114, 400086002, (:base_batch + 1), 0.95000),
    (400086002115, 400086002, (:base_batch + 1), 0.95000),
    (400086002116, 400086002, (:base_batch + 1), 0.95000),
    (400086002117, 400086002, (:base_batch + 1), 0.95000),
    (400086002118, 400086002, (:base_batch + 1), 0.95000),
    (400086002119, 400086002, (:base_batch + 1), 0.95000),
    (400086002120, 400086002, (:base_batch + 1), 0.95000),
    (400086002121, 400086002, (:base_batch + 1), 0.95000),
    (400086002122, 400086002, (:base_batch + 1), 0.95000),
    (400086002123, 400086002, (:base_batch + 1), 0.95000),
    (400086002124, 400086002, (:base_batch + 1), 0.95000),
    (400086002125, 400086002, (:base_batch + 1), 0.95000),
    (400086002126, 400086002, (:base_batch + 1), 0.95000),
    (400086002127, 400086002, (:base_batch + 1), 0.95000),
    (400086002128, 400086002, (:base_batch + 1), 0.95000),
    (400086002129, 400086002, (:base_batch + 1), 0.95000),
    (400086002130, 400086002, (:base_batch + 1), 0.95000),
    (400086002131, 400086002, (:base_batch + 1), 0.95000),
    (400086002132, 400086002, (:base_batch + 1), 0.95000),
    (400086002133, 400086002, (:base_batch + 1), 0.95000),
    (400086002134, 400086002, (:base_batch + 1), 0.95000),
    (400086002135, 400086002, (:base_batch + 1), 0.95000),
    (400086002136, 400086002, (:base_batch + 1), 0.95000),
    (400086002137, 400086002, (:base_batch + 1), 0.95000),
    (400086002138, 400086002, (:base_batch + 1), 0.95000),
    (400086002139, 400086002, (:base_batch + 1), 0.95000),
    (400086002140, 400086002, (:base_batch + 1), 0.95000),
    (400086002141, 400086002, (:base_batch + 1), 0.95000),
    (400086002142, 400086002, (:base_batch + 1), 0.95000),
    (400086002143, 400086002, (:base_batch + 1), 0.95000),
    (400086002144, 400086002, (:base_batch + 1), 0.95000),
    (400086002145, 400086002, (:base_batch + 1), 0.95000),
    (400086002146, 400086002, (:base_batch + 1), 0.95000),
    (400086002147, 400086002, (:base_batch + 1), 0.95000),
    (400086002148, 400086002, (:base_batch + 1), 0.95000),
    (400086002149, 400086002, (:base_batch + 1), 0.95000),
    (400086002150, 400086002, (:base_batch + 1), 0.95000),
    (400086002151, 400086002, (:base_batch + 1), 0.95000),
    (400086002152, 400086002, (:base_batch + 1), 0.95000),
    (400086002153, 400086002, (:base_batch + 1), 0.95000),
    (400086002154, 400086002, (:base_batch + 1), 0.95000),
    (400086002155, 400086002, (:base_batch + 1), 0.95000),
    (400086002156, 400086002, (:base_batch + 1), 0.95000),
    (400086002157, 400086002, (:base_batch + 1), 0.95000),
    (400086002158, 400086002, (:base_batch + 1), 0.95000),
    (400086002159, 400086002, (:base_batch + 1), 0.95000),
    (400086002160, 400086002, (:base_batch + 1), 0.95000),
    (400086002161, 400086002, (:base_batch + 1), 0.85000),
    (400086002162, 400086002, (:base_batch + 1), 0.85000),
    (400086002163, 400086002, (:base_batch + 1), 0.85000),
    (400086002164, 400086002, (:base_batch + 1), 0.85000),
    (400086002165, 400086002, (:base_batch + 1), 0.85000),
    (400086002166, 400086002, (:base_batch + 1), 0.85000),
    (400086002167, 400086002, (:base_batch + 1), 0.85000),
    (400086002168, 400086002, (:base_batch + 1), 0.85000),
    (400086002169, 400086002, (:base_batch + 1), 0.85000),
    (400086002170, 400086002, (:base_batch + 1), 0.85000),
    (400086002171, 400086002, (:base_batch + 1), 0.85000),
    (400086002172, 400086002, (:base_batch + 1), 0.85000),
    (400086002173, 400086002, (:base_batch + 1), 0.85000),
    (400086002174, 400086002, (:base_batch + 1), 0.85000),
    (400086002175, 400086002, (:base_batch + 1), 0.85000),
    (400086002176, 400086002, (:base_batch + 1), 0.85000),
    (400086002177, 400086002, (:base_batch + 1), 0.85000),
    (400086002178, 400086002, (:base_batch + 1), 0.85000),
    (400086002179, 400086002, (:base_batch + 1), 0.85000),
    (400086002180, 400086002, (:base_batch + 1), 0.85000),
    (400086002181, 400086002, (:base_batch + 1), 0.85000),
    (400086002182, 400086002, (:base_batch + 1), 0.85000),
    (400086002183, 400086002, (:base_batch + 1), 0.85000),
    (400086002184, 400086002, (:base_batch + 1), 0.85000),
    (400086002185, 400086002, (:base_batch + 1), 0.95000),
    (400086002186, 400086002, (:base_batch + 1), 0.95000),
    (400086002187, 400086002, (:base_batch + 1), 0.95000),
    (400086002188, 400086002, (:base_batch + 1), 0.95000),
    (400086002189, 400086002, (:base_batch + 1), 0.95000),
    (400086002190, 400086002, (:base_batch + 1), 0.95000),
    (400086002191, 400086002, (:base_batch + 1), 0.95000),
    (400086002192, 400086002, (:base_batch + 1), 0.95000),
    (400086002193, 400086002, (:base_batch + 1), 0.95000),
    (400086002194, 400086002, (:base_batch + 1), 0.95000),
    (400086002195, 400086002, (:base_batch + 1), 0.95000),
    (400086002196, 400086002, (:base_batch + 1), 0.95000),
    (400086002197, 400086002, (:base_batch + 1), 0.95000),
    (400086002198, 400086002, (:base_batch + 1), 0.95000),
    (400086002199, 400086002, (:base_batch + 1), 0.95000),
    (400086002200, 400086002, (:base_batch + 1), 0.95000),
    (400086002201, 400086002, (:base_batch + 1), 0.95000),
    (400086002202, 400086002, (:base_batch + 1), 0.95000),
    (400086002203, 400086002, (:base_batch + 1), 0.95000),
    (400086002204, 400086002, (:base_batch + 1), 0.95000),
    (400086002205, 400086002, (:base_batch + 1), 0.95000),
    (400086002206, 400086002, (:base_batch + 1), 0.95000),
    (400086002207, 400086002, (:base_batch + 1), 0.95000),
    (400086002208, 400086002, (:base_batch + 1), 0.95000),
    (400086002209, 400086002, (:base_batch + 1), 0.95000),
    (400086002210, 400086002, (:base_batch + 1), 0.95000),
    (400086002211, 400086002, (:base_batch + 1), 0.95000),
    (400086002212, 400086002, (:base_batch + 1), 0.95000),
    (400086002213, 400086002, (:base_batch + 1), 0.95000),
    (400086002214, 400086002, (:base_batch + 1), 0.95000),
    (400086002215, 400086002, (:base_batch + 1), 0.95000),
    (400086002216, 400086002, (:base_batch + 1), 0.95000),
    (400086002217, 400086002, (:base_batch + 1), 0.95000),
    (400086002218, 400086002, (:base_batch + 1), 0.95000),
    (400086002219, 400086002, (:base_batch + 1), 0.95000),
    (400086002220, 400086002, (:base_batch + 1), 0.95000),
    (400086002221, 400086002, (:base_batch + 1), 0.95000),
    (400086002222, 400086002, (:base_batch + 1), 0.95000),
    (400086002223, 400086002, (:base_batch + 1), 0.95000),
    (400086002224, 400086002, (:base_batch + 1), 0.90000),
    (400086002225, 400086002, (:base_batch + 1), 0.90000),
    (400086002226, 400086002, (:base_batch + 1), 0.95000),
    (400086002227, 400086002, (:base_batch + 1), 0.95000),
    (400086002228, 400086002, (:base_batch + 1), 0.95000),
    (400086002229, 400086002, (:base_batch + 1), 0.95000),
    (400086002230, 400086002, (:base_batch + 1), 0.95000),
    (400086002231, 400086002, (:base_batch + 1), 0.90000),
    (400086002232, 400086002, (:base_batch + 1), 0.90000),
    (400086002233, 400086002, (:base_batch + 1), 0.75000),
    (400086002234, 400086002, (:base_batch + 1), 0.95000),
    (400086002235, 400086002, (:base_batch + 1), 0.95000),
    (400086002236, 400086002, (:base_batch + 1), 0.95000),
    (400086002237, 400086002, (:base_batch + 1), 0.95000),
    (400086002238, 400086002, (:base_batch + 1), 0.95000),
    (400086002239, 400086002, (:base_batch + 1), 0.95000),
    (400086002240, 400086002, (:base_batch + 1), 0.95000),
    (400086002241, 400086002, (:base_batch + 1), 0.95000),
    (400086002242, 400086002, (:base_batch + 1), 0.95000),
    (400086002243, 400086002, (:base_batch + 1), 0.95000),
    (400086002244, 400086002, (:base_batch + 1), 0.95000),
    (400086002245, 400086002, (:base_batch + 1), 0.95000),
    (400086002246, 400086002, (:base_batch + 1), 0.95000),
    (400086002247, 400086002, (:base_batch + 1), 0.95000),
    (400086002248, 400086002, (:base_batch + 1), 0.95000),
    (400086002249, 400086002, (:base_batch + 1), 0.95000),
    (400086002250, 400086002, (:base_batch + 1), 0.95000),
    (400086002251, 400086002, (:base_batch + 1), 0.95000),
    (400086002252, 400086002, (:base_batch + 1), 0.95000),
    (400086002253, 400086002, (:base_batch + 1), 0.95000),
    (400086002254, 400086002, (:base_batch + 1), 0.95000),
    (400086002255, 400086002, (:base_batch + 1), 0.95000),
    (400086002256, 400086002, (:base_batch + 1), 0.95000),
    (400086002257, 400086002, (:base_batch + 1), 0.95000),
    (400086002258, 400086002, (:base_batch + 1), 0.95000),
    (400086002259, 400086002, (:base_batch + 1), 0.95000),
    (400086002260, 400086002, (:base_batch + 1), 0.95000),
    (400086002261, 400086002, (:base_batch + 1), 0.95000),
    (400086002262, 400086002, (:base_batch + 1), 0.95000),
    (400086002263, 400086002, (:base_batch + 1), 0.95000),
    (400086002264, 400086002, (:base_batch + 1), 0.95000),
    (400086002265, 400086002, (:base_batch + 1), 0.95000),
    (400086002266, 400086002, (:base_batch + 1), 0.95000),
    (400086002267, 400086002, (:base_batch + 1), 0.95000),
    (400086002268, 400086002, (:base_batch + 1), 0.95000),
    (400086002269, 400086002, (:base_batch + 1), 0.95000),
    (400086002270, 400086002, (:base_batch + 1), 0.95000),
    (400086002271, 400086002, (:base_batch + 1), 0.95000),
    (400086002272, 400086002, (:base_batch + 1), 0.95000),
    (400086002273, 400086002, (:base_batch + 1), 0.95000),
    (400086002274, 400086002, (:base_batch + 1), 0.95000),
    (400086002275, 400086002, (:base_batch + 1), 0.95000),
    (400086002276, 400086002, (:base_batch + 1), 0.95000),
    (400086002277, 400086002, (:base_batch + 1), 0.95000),
    (400086002278, 400086002, (:base_batch + 1), 0.95000),
    (400086002279, 400086002, (:base_batch + 1), 0.95000),
    (400086002280, 400086002, (:base_batch + 1), 0.95000),
    (400086002281, 400086002, (:base_batch + 1), 0.95000),
    (400086002282, 400086002, (:base_batch + 1), 0.95000),
    (400086002283, 400086002, (:base_batch + 1), 0.95000),
    (400086002284, 400086002, (:base_batch + 1), 0.95000),
    (400086002285, 400086002, (:base_batch + 1), 0.95000),
    (400086002286, 400086002, (:base_batch + 1), 0.95000),
    (400086002287, 400086002, (:base_batch + 1), 0.95000),
    (400086002288, 400086002, (:base_batch + 1), 0.95000),
    (400086002289, 400086002, (:base_batch + 1), 0.90000),
    (400086002290, 400086002, (:base_batch + 1), 0.90000),
    (400086002291, 400086002, (:base_batch + 1), 0.75000),
    (400086002292, 400086002, (:base_batch + 1), 0.85000),
    (400086002293, 400086002, (:base_batch + 1), 0.85000),
    (400086002294, 400086002, (:base_batch + 1), 0.70000),
    (400086002295, 400086002, (:base_batch + 1), 0.85000),
    (400086002296, 400086002, (:base_batch + 1), 0.85000),
    (400086002297, 400086002, (:base_batch + 1), 0.70000),
    (400086002298, 400086002, (:base_batch + 1), 0.95000),
    (400086002299, 400086002, (:base_batch + 1), 0.95000),
    (400086002300, 400086002, (:base_batch + 1), 0.75000),
    (400086002301, 400086002, (:base_batch + 1), 0.75000),
    (400086002302, 400086002, (:base_batch + 1), 0.70000),
    (400086002303, 400086002, (:base_batch + 1), 0.70000),
    (400086002304, 400086002, (:base_batch + 1), 0.60000),
    (400086002305, 400086002, (:base_batch + 1), 0.60000),
    (400086002306, 400086002, (:base_batch + 1), 0.70000),
    (400086002307, 400086002, (:base_batch + 1), 0.70000),
    (400086002308, 400086002, (:base_batch + 1), 0.60000),
    (400086002309, 400086002, (:base_batch + 1), 0.60000),
    (400086002310, 400086002, (:base_batch + 1), 0.70000),
    (400086002311, 400086002, (:base_batch + 1), 0.70000),
    (400086002312, 400086002, (:base_batch + 1), 0.60000),
    (400086002313, 400086002, (:base_batch + 1), 0.60000),
    (400086002314, 400086002, (:base_batch + 1), 0.95000),
    (400086002315, 400086002, (:base_batch + 1), 0.90000),
    (400086002316, 400086002, (:base_batch + 1), 0.90000),
    (400086002317, 400086002, (:base_batch + 1), 0.95000),
    (400086002318, 400086002, (:base_batch + 1), 0.95000),
    (400086002319, 400086002, (:base_batch + 1), 0.95000),
    (400086002320, 400086002, (:base_batch + 1), 0.95000),
    (400086002321, 400086002, (:base_batch + 1), 0.95000),
    (400086002322, 400086002, (:base_batch + 1), 0.95000),
    (400086002323, 400086002, (:base_batch + 1), 0.95000),
    (400086002324, 400086002, (:base_batch + 1), 0.95000),
    (400086002325, 400086002, (:base_batch + 1), 0.95000),
    (400086002326, 400086002, (:base_batch + 1), 0.95000),
    (400086002327, 400086002, (:base_batch + 1), 0.95000),
    (400086002328, 400086002, (:base_batch + 1), 0.95000),
    (400086002329, 400086002, (:base_batch + 1), 0.95000),
    (400086002330, 400086002, (:base_batch + 1), 0.95000),
    (400086002331, 400086002, (:base_batch + 1), 0.95000),
    (400086002332, 400086002, (:base_batch + 1), 0.95000),
    (400086002333, 400086002, (:base_batch + 1), 0.95000),
    (400086002334, 400086002, (:base_batch + 1), 0.95000),
    (400086002335, 400086002, (:base_batch + 1), 0.95000),
    (400086002336, 400086002, (:base_batch + 1), 0.95000),
    (400086002337, 400086002, (:base_batch + 1), 0.95000),
    (400086002338, 400086002, (:base_batch + 1), 0.95000),
    (400086002339, 400086002, (:base_batch + 1), 0.95000),
    (400086002340, 400086002, (:base_batch + 1), 0.95000),
    (400086002341, 400086002, (:base_batch + 1), 0.95000),
    (400086002342, 400086002, (:base_batch + 1), 0.95000),
    (400086002343, 400086002, (:base_batch + 1), 0.95000),
    (400086002344, 400086002, (:base_batch + 1), 0.95000),
    (400086002345, 400086002, (:base_batch + 1), 0.95000),
    (400086002346, 400086002, (:base_batch + 1), 0.95000),
    (400086002347, 400086002, (:base_batch + 1), 0.95000),
    (400086002348, 400086002, (:base_batch + 1), 0.95000),
    (400086002349, 400086002, (:base_batch + 1), 0.95000),
    (400086002350, 400086002, (:base_batch + 1), 0.95000),
    (400086002351, 400086002, (:base_batch + 1), 0.95000),
    (400086002352, 400086002, (:base_batch + 1), 0.95000),
    (400086002353, 400086002, (:base_batch + 1), 0.95000),
    (400086002354, 400086002, (:base_batch + 1), 0.95000),
    (400086002355, 400086002, (:base_batch + 1), 0.95000),
    (400086002356, 400086002, (:base_batch + 1), 0.95000),
    (400086002357, 400086002, (:base_batch + 1), 0.95000),
    (400086002358, 400086002, (:base_batch + 1), 0.95000),
    (400086002359, 400086002, (:base_batch + 1), 0.95000),
    (400086002360, 400086002, (:base_batch + 1), 0.95000),
    (400086002361, 400086002, (:base_batch + 1), 0.95000),
    (400086002362, 400086002, (:base_batch + 1), 0.95000),
    (400086002363, 400086002, (:base_batch + 1), 0.95000),
    (400086002364, 400086002, (:base_batch + 1), 0.95000),
    (400086002365, 400086002, (:base_batch + 1), 0.95000),
    (400086002366, 400086002, (:base_batch + 1), 0.95000),
    (400086002367, 400086002, (:base_batch + 1), 0.95000),
    (400086002368, 400086002, (:base_batch + 1), 0.95000),
    (400086002369, 400086002, (:base_batch + 1), 0.95000),
    (400086002370, 400086002, (:base_batch + 1), 0.95000),
    (400086002371, 400086002, (:base_batch + 1), 0.95000),
    (400086002372, 400086002, (:base_batch + 1), 0.95000),
    (400086002373, 400086002, (:base_batch + 1), 0.95000),
    (400086002374, 400086002, (:base_batch + 1), 0.95000),
    (400086002375, 400086002, (:base_batch + 1), 0.95000),
    (400086002376, 400086002, (:base_batch + 1), 0.95000),
    (400086002377, 400086002, (:base_batch + 1), 0.95000),
    (400086002378, 400086002, (:base_batch + 1), 0.95000),
    (400086002379, 400086002, (:base_batch + 1), 0.95000),
    (400086002380, 400086002, (:base_batch + 1), 0.95000),
    (400086002381, 400086002, (:base_batch + 1), 0.95000),
    (400086002382, 400086002, (:base_batch + 1), 0.95000),
    (400086002383, 400086002, (:base_batch + 1), 0.95000),
    (400086002384, 400086002, (:base_batch + 1), 0.95000),
    (400086002385, 400086002, (:base_batch + 1), 0.95000),
    (400086002386, 400086002, (:base_batch + 1), 0.95000),
    (400086002387, 400086002, (:base_batch + 1), 0.95000),
    (400086002388, 400086002, (:base_batch + 1), 0.95000),
    (400086002389, 400086002, (:base_batch + 1), 0.95000),
    (400086002390, 400086002, (:base_batch + 1), 0.95000),
    (400086002391, 400086002, (:base_batch + 1), 0.95000),
    (400086002392, 400086002, (:base_batch + 1), 0.95000),
    (400086002393, 400086002, (:base_batch + 1), 0.95000),
    (400086002394, 400086002, (:base_batch + 1), 0.95000),
    (400086002395, 400086002, (:base_batch + 1), 0.95000),
    (400086002396, 400086002, (:base_batch + 1), 0.95000),
    (400086002397, 400086002, (:base_batch + 1), 0.95000),
    (400086002398, 400086002, (:base_batch + 1), 0.95000),
    (400086002399, 400086002, (:base_batch + 1), 0.95000),
    (400086002400, 400086002, (:base_batch + 1), 0.95000),
    (400086002401, 400086002, (:base_batch + 1), 0.95000),
    (400086002402, 400086002, (:base_batch + 1), 0.95000),
    (400086002403, 400086002, (:base_batch + 1), 0.95000),
    (400086002404, 400086002, (:base_batch + 1), 0.95000),
    (400086002405, 400086002, (:base_batch + 1), 0.95000),
    (400086002406, 400086002, (:base_batch + 1), 0.95000),
    (400086002407, 400086002, (:base_batch + 1), 0.95000),
    (400086002408, 400086002, (:base_batch + 1), 0.95000),
    (400086002409, 400086002, (:base_batch + 1), 0.95000);

-- ----------------------------------------------------------------------------
-- 8. DELIVERY CAPABILITY
-- ----------------------------------------------------------------------------
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available,
                                 self_delivery_min_order_amount)
VALUES (400086002, TRUE, TRUE, 250.00);
-- free-delivery radius (2 km) has no column - see trailing Block 2

-- ----------------------------------------------------------------------------
-- 9. BOARD MAPPINGS (board <- categories <- items, JSON order)
-- ----------------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400086002, 400086002001, 400086002001, 1),
    (400086002, 400086002001, 400086002002, 2),
    (400086002, 400086002001, 400086002003, 3),
    (400086002, 400086002001, 400086002004, 4),
    (400086002, 400086002001, 400086002005, 5),
    (400086002, 400086002001, 400086002006, 6),
    (400086002, 400086002001, 400086002007, 7),
    (400086002, 400086002001, 400086002008, 8),
    (400086002, 400086002001, 400086002009, 9),
    (400086002, 400086002001, 400086002010, 10),
    (400086002, 400086002001, 400086002011, 11),
    (400086002, 400086002001, 400086002012, 12),
    (400086002, 400086002001, 400086002013, 13),
    (400086002, 400086002001, 400086002014, 14),
    (400086002, 400086002001, 400086002015, 15),
    (400086002, 400086002001, 400086002016, 16),
    (400086002, 400086002001, 400086002017, 17),
    (400086002, 400086002001, 400086002018, 18),
    (400086002, 400086002001, 400086002019, 19),
    (400086002, 400086002001, 400086002020, 20),
    (400086002, 400086002001, 400086002021, 21),
    (400086002, 400086002001, 400086002022, 22),
    (400086002, 400086002001, 400086002023, 23),
    (400086002, 400086002001, 400086002024, 24),
    (400086002, 400086002001, 400086002025, 25),
    (400086002, 400086002001, 400086002026, 26),
    (400086002, 400086002001, 400086002027, 27),
    (400086002, 400086002001, 400086002028, 28),
    (400086002, 400086002001, 400086002029, 29),
    (400086002, 400086002001, 400086002030, 30),
    (400086002, 400086002001, 400086002031, 31),
    (400086002, 400086002001, 400086002032, 32),
    (400086002, 400086002001, 400086002033, 33),
    (400086002, 400086002001, 400086002034, 34),
    (400086002, 400086002001, 400086002035, 35),
    (400086002, 400086002001, 400086002036, 36),
    (400086002, 400086002001, 400086002037, 37),
    (400086002, 400086002001, 400086002038, 38),
    (400086002, 400086002001, 400086002039, 39),
    (400086002, 400086002001, 400086002040, 40),
    (400086002, 400086002001, 400086002041, 41),
    (400086002, 400086002001, 400086002042, 42),
    (400086002, 400086002001, 400086002043, 43);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id,
                             display_sequence)
VALUES
    (400086002001, 400086002, 400086002001, 400086002001, 400086002001, 1),
    (400086002002, 400086002, 400086002001, 400086002002, 400086002001, 2),
    (400086002003, 400086002, 400086002001, 400086002003, 400086002001, 3),
    (400086002004, 400086002, 400086002001, 400086002004, 400086002001, 4),
    (400086002005, 400086002, 400086002001, 400086002005, 400086002001, 5),
    (400086002006, 400086002, 400086002001, 400086002006, 400086002001, 6),
    (400086002007, 400086002, 400086002001, 400086002007, 400086002001, 7),
    (400086002008, 400086002, 400086002001, 400086002008, 400086002001, 8),
    (400086002009, 400086002, 400086002001, 400086002009, 400086002001, 9),
    (400086002010, 400086002, 400086002001, 400086002010, 400086002001, 10),
    (400086002011, 400086002, 400086002001, 400086002011, 400086002001, 11),
    (400086002012, 400086002, 400086002001, 400086002012, 400086002001, 12),
    (400086002013, 400086002, 400086002001, 400086002013, 400086002001, 13),
    (400086002014, 400086002, 400086002001, 400086002014, 400086002001, 14),
    (400086002015, 400086002, 400086002001, 400086002015, 400086002001, 15),
    (400086002016, 400086002, 400086002001, 400086002016, 400086002002, 16),
    (400086002017, 400086002, 400086002001, 400086002017, 400086002002, 17),
    (400086002018, 400086002, 400086002001, 400086002018, 400086002003, 18),
    (400086002019, 400086002, 400086002001, 400086002019, 400086002003, 19),
    (400086002020, 400086002, 400086002001, 400086002020, 400086002003, 20),
    (400086002021, 400086002, 400086002001, 400086002021, 400086002003, 21),
    (400086002022, 400086002, 400086002001, 400086002022, 400086002003, 22),
    (400086002023, 400086002, 400086002001, 400086002023, 400086002004, 23),
    (400086002024, 400086002, 400086002001, 400086002024, 400086002004, 24),
    (400086002025, 400086002, 400086002001, 400086002025, 400086002004, 25),
    (400086002026, 400086002, 400086002001, 400086002026, 400086002004, 26),
    (400086002027, 400086002, 400086002001, 400086002027, 400086002004, 27),
    (400086002028, 400086002, 400086002001, 400086002028, 400086002005, 28),
    (400086002029, 400086002, 400086002001, 400086002029, 400086002005, 29),
    (400086002030, 400086002, 400086002001, 400086002030, 400086002005, 30),
    (400086002031, 400086002, 400086002001, 400086002031, 400086002005, 31),
    (400086002032, 400086002, 400086002001, 400086002032, 400086002006, 32),
    (400086002033, 400086002, 400086002001, 400086002033, 400086002006, 33),
    (400086002034, 400086002, 400086002001, 400086002034, 400086002006, 34),
    (400086002035, 400086002, 400086002001, 400086002035, 400086002006, 35),
    (400086002036, 400086002, 400086002001, 400086002036, 400086002006, 36),
    (400086002037, 400086002, 400086002001, 400086002037, 400086002007, 37),
    (400086002038, 400086002, 400086002001, 400086002038, 400086002007, 38),
    (400086002039, 400086002, 400086002001, 400086002039, 400086002007, 39),
    (400086002040, 400086002, 400086002001, 400086002040, 400086002007, 40),
    (400086002041, 400086002, 400086002001, 400086002041, 400086002007, 41),
    (400086002042, 400086002, 400086002001, 400086002042, 400086002007, 42),
    (400086002043, 400086002, 400086002001, 400086002043, 400086002007, 43),
    (400086002044, 400086002, 400086002001, 400086002044, 400086002008, 44),
    (400086002045, 400086002, 400086002001, 400086002045, 400086002008, 45),
    (400086002046, 400086002, 400086002001, 400086002046, 400086002008, 46),
    (400086002047, 400086002, 400086002001, 400086002047, 400086002008, 47),
    (400086002048, 400086002, 400086002001, 400086002048, 400086002008, 48),
    (400086002049, 400086002, 400086002001, 400086002049, 400086002008, 49),
    (400086002050, 400086002, 400086002001, 400086002050, 400086002009, 50),
    (400086002051, 400086002, 400086002001, 400086002051, 400086002009, 51),
    (400086002052, 400086002, 400086002001, 400086002052, 400086002009, 52),
    (400086002053, 400086002, 400086002001, 400086002053, 400086002009, 53),
    (400086002054, 400086002, 400086002001, 400086002054, 400086002009, 54),
    (400086002055, 400086002, 400086002001, 400086002055, 400086002009, 55),
    (400086002056, 400086002, 400086002001, 400086002056, 400086002009, 56),
    (400086002057, 400086002, 400086002001, 400086002057, 400086002009, 57),
    (400086002058, 400086002, 400086002001, 400086002058, 400086002010, 58),
    (400086002059, 400086002, 400086002001, 400086002059, 400086002010, 59),
    (400086002060, 400086002, 400086002001, 400086002060, 400086002010, 60),
    (400086002061, 400086002, 400086002001, 400086002061, 400086002010, 61),
    (400086002062, 400086002, 400086002001, 400086002062, 400086002010, 62),
    (400086002063, 400086002, 400086002001, 400086002063, 400086002010, 63),
    (400086002064, 400086002, 400086002001, 400086002064, 400086002010, 64),
    (400086002065, 400086002, 400086002001, 400086002065, 400086002010, 65),
    (400086002066, 400086002, 400086002001, 400086002066, 400086002010, 66),
    (400086002067, 400086002, 400086002001, 400086002067, 400086002010, 67),
    (400086002068, 400086002, 400086002001, 400086002068, 400086002010, 68),
    (400086002069, 400086002, 400086002001, 400086002069, 400086002010, 69),
    (400086002070, 400086002, 400086002001, 400086002070, 400086002010, 70),
    (400086002071, 400086002, 400086002001, 400086002071, 400086002011, 71),
    (400086002072, 400086002, 400086002001, 400086002072, 400086002011, 72),
    (400086002073, 400086002, 400086002001, 400086002073, 400086002011, 73),
    (400086002074, 400086002, 400086002001, 400086002074, 400086002011, 74),
    (400086002075, 400086002, 400086002001, 400086002075, 400086002011, 75),
    (400086002076, 400086002, 400086002001, 400086002076, 400086002011, 76),
    (400086002077, 400086002, 400086002001, 400086002077, 400086002011, 77),
    (400086002078, 400086002, 400086002001, 400086002078, 400086002012, 78),
    (400086002079, 400086002, 400086002001, 400086002079, 400086002012, 79),
    (400086002080, 400086002, 400086002001, 400086002080, 400086002013, 80),
    (400086002081, 400086002, 400086002001, 400086002081, 400086002013, 81),
    (400086002082, 400086002, 400086002001, 400086002082, 400086002013, 82),
    (400086002083, 400086002, 400086002001, 400086002083, 400086002013, 83),
    (400086002084, 400086002, 400086002001, 400086002084, 400086002013, 84),
    (400086002085, 400086002, 400086002001, 400086002085, 400086002014, 85),
    (400086002086, 400086002, 400086002001, 400086002086, 400086002014, 86),
    (400086002087, 400086002, 400086002001, 400086002087, 400086002014, 87),
    (400086002088, 400086002, 400086002001, 400086002088, 400086002014, 88),
    (400086002089, 400086002, 400086002001, 400086002089, 400086002015, 89),
    (400086002090, 400086002, 400086002001, 400086002090, 400086002015, 90),
    (400086002091, 400086002, 400086002001, 400086002091, 400086002015, 91),
    (400086002092, 400086002, 400086002001, 400086002092, 400086002015, 92),
    (400086002093, 400086002, 400086002001, 400086002093, 400086002015, 93),
    (400086002094, 400086002, 400086002001, 400086002094, 400086002015, 94),
    (400086002095, 400086002, 400086002001, 400086002095, 400086002015, 95),
    (400086002096, 400086002, 400086002001, 400086002096, 400086002016, 96),
    (400086002097, 400086002, 400086002001, 400086002097, 400086002016, 97),
    (400086002098, 400086002, 400086002001, 400086002098, 400086002016, 98),
    (400086002099, 400086002, 400086002001, 400086002099, 400086002016, 99),
    (400086002100, 400086002, 400086002001, 400086002100, 400086002016, 100),
    (400086002101, 400086002, 400086002001, 400086002101, 400086002016, 101),
    (400086002102, 400086002, 400086002001, 400086002102, 400086002016, 102),
    (400086002103, 400086002, 400086002001, 400086002103, 400086002016, 103),
    (400086002104, 400086002, 400086002001, 400086002104, 400086002016, 104),
    (400086002105, 400086002, 400086002001, 400086002105, 400086002017, 105),
    (400086002106, 400086002, 400086002001, 400086002106, 400086002017, 106),
    (400086002107, 400086002, 400086002001, 400086002107, 400086002017, 107),
    (400086002108, 400086002, 400086002001, 400086002108, 400086002017, 108),
    (400086002109, 400086002, 400086002001, 400086002109, 400086002017, 109),
    (400086002110, 400086002, 400086002001, 400086002110, 400086002017, 110),
    (400086002111, 400086002, 400086002001, 400086002111, 400086002017, 111),
    (400086002112, 400086002, 400086002001, 400086002112, 400086002018, 112),
    (400086002113, 400086002, 400086002001, 400086002113, 400086002018, 113),
    (400086002114, 400086002, 400086002001, 400086002114, 400086002018, 114),
    (400086002115, 400086002, 400086002001, 400086002115, 400086002018, 115),
    (400086002116, 400086002, 400086002001, 400086002116, 400086002018, 116),
    (400086002117, 400086002, 400086002001, 400086002117, 400086002018, 117),
    (400086002118, 400086002, 400086002001, 400086002118, 400086002018, 118),
    (400086002119, 400086002, 400086002001, 400086002119, 400086002018, 119),
    (400086002120, 400086002, 400086002001, 400086002120, 400086002018, 120),
    (400086002121, 400086002, 400086002001, 400086002121, 400086002018, 121),
    (400086002122, 400086002, 400086002001, 400086002122, 400086002018, 122),
    (400086002123, 400086002, 400086002001, 400086002123, 400086002018, 123),
    (400086002124, 400086002, 400086002001, 400086002124, 400086002018, 124),
    (400086002125, 400086002, 400086002001, 400086002125, 400086002018, 125),
    (400086002126, 400086002, 400086002001, 400086002126, 400086002018, 126),
    (400086002127, 400086002, 400086002001, 400086002127, 400086002018, 127),
    (400086002128, 400086002, 400086002001, 400086002128, 400086002018, 128),
    (400086002129, 400086002, 400086002001, 400086002129, 400086002018, 129),
    (400086002130, 400086002, 400086002001, 400086002130, 400086002018, 130),
    (400086002131, 400086002, 400086002001, 400086002131, 400086002019, 131),
    (400086002132, 400086002, 400086002001, 400086002132, 400086002019, 132),
    (400086002133, 400086002, 400086002001, 400086002133, 400086002019, 133),
    (400086002134, 400086002, 400086002001, 400086002134, 400086002019, 134),
    (400086002135, 400086002, 400086002001, 400086002135, 400086002019, 135),
    (400086002136, 400086002, 400086002001, 400086002136, 400086002019, 136),
    (400086002137, 400086002, 400086002001, 400086002137, 400086002019, 137),
    (400086002138, 400086002, 400086002001, 400086002138, 400086002019, 138),
    (400086002139, 400086002, 400086002001, 400086002139, 400086002019, 139),
    (400086002140, 400086002, 400086002001, 400086002140, 400086002019, 140),
    (400086002141, 400086002, 400086002001, 400086002141, 400086002019, 141),
    (400086002142, 400086002, 400086002001, 400086002142, 400086002019, 142),
    (400086002143, 400086002, 400086002001, 400086002143, 400086002019, 143),
    (400086002144, 400086002, 400086002001, 400086002144, 400086002019, 144),
    (400086002145, 400086002, 400086002001, 400086002145, 400086002019, 145),
    (400086002146, 400086002, 400086002001, 400086002146, 400086002019, 146),
    (400086002147, 400086002, 400086002001, 400086002147, 400086002019, 147),
    (400086002148, 400086002, 400086002001, 400086002148, 400086002019, 148),
    (400086002149, 400086002, 400086002001, 400086002149, 400086002019, 149),
    (400086002150, 400086002, 400086002001, 400086002150, 400086002019, 150),
    (400086002151, 400086002, 400086002001, 400086002151, 400086002020, 151),
    (400086002152, 400086002, 400086002001, 400086002152, 400086002020, 152),
    (400086002153, 400086002, 400086002001, 400086002153, 400086002020, 153),
    (400086002154, 400086002, 400086002001, 400086002154, 400086002020, 154),
    (400086002155, 400086002, 400086002001, 400086002155, 400086002020, 155),
    (400086002156, 400086002, 400086002001, 400086002156, 400086002021, 156),
    (400086002157, 400086002, 400086002001, 400086002157, 400086002021, 157),
    (400086002158, 400086002, 400086002001, 400086002158, 400086002021, 158),
    (400086002159, 400086002, 400086002001, 400086002159, 400086002021, 159),
    (400086002160, 400086002, 400086002001, 400086002160, 400086002021, 160),
    (400086002161, 400086002, 400086002001, 400086002161, 400086002021, 161),
    (400086002162, 400086002, 400086002001, 400086002162, 400086002021, 162),
    (400086002163, 400086002, 400086002001, 400086002163, 400086002021, 163),
    (400086002164, 400086002, 400086002001, 400086002164, 400086002021, 164),
    (400086002165, 400086002, 400086002001, 400086002165, 400086002021, 165),
    (400086002166, 400086002, 400086002001, 400086002166, 400086002021, 166),
    (400086002167, 400086002, 400086002001, 400086002167, 400086002021, 167),
    (400086002168, 400086002, 400086002001, 400086002168, 400086002022, 168),
    (400086002169, 400086002, 400086002001, 400086002169, 400086002022, 169),
    (400086002170, 400086002, 400086002001, 400086002170, 400086002022, 170),
    (400086002171, 400086002, 400086002001, 400086002171, 400086002022, 171),
    (400086002172, 400086002, 400086002001, 400086002172, 400086002022, 172),
    (400086002173, 400086002, 400086002001, 400086002173, 400086002022, 173),
    (400086002174, 400086002, 400086002001, 400086002174, 400086002022, 174),
    (400086002175, 400086002, 400086002001, 400086002175, 400086002023, 175),
    (400086002176, 400086002, 400086002001, 400086002176, 400086002023, 176),
    (400086002177, 400086002, 400086002001, 400086002177, 400086002023, 177),
    (400086002178, 400086002, 400086002001, 400086002178, 400086002023, 178),
    (400086002179, 400086002, 400086002001, 400086002179, 400086002023, 179),
    (400086002180, 400086002, 400086002001, 400086002180, 400086002023, 180),
    (400086002181, 400086002, 400086002001, 400086002181, 400086002023, 181),
    (400086002182, 400086002, 400086002001, 400086002182, 400086002023, 182),
    (400086002183, 400086002, 400086002001, 400086002183, 400086002023, 183),
    (400086002184, 400086002, 400086002001, 400086002184, 400086002023, 184),
    (400086002185, 400086002, 400086002001, 400086002185, 400086002023, 185),
    (400086002186, 400086002, 400086002001, 400086002186, 400086002024, 186),
    (400086002187, 400086002, 400086002001, 400086002187, 400086002024, 187),
    (400086002188, 400086002, 400086002001, 400086002188, 400086002024, 188),
    (400086002189, 400086002, 400086002001, 400086002189, 400086002024, 189),
    (400086002190, 400086002, 400086002001, 400086002190, 400086002024, 190),
    (400086002191, 400086002, 400086002001, 400086002191, 400086002024, 191),
    (400086002192, 400086002, 400086002001, 400086002192, 400086002024, 192),
    (400086002193, 400086002, 400086002001, 400086002193, 400086002024, 193),
    (400086002194, 400086002, 400086002001, 400086002194, 400086002024, 194),
    (400086002195, 400086002, 400086002001, 400086002195, 400086002024, 195),
    (400086002196, 400086002, 400086002001, 400086002196, 400086002025, 196),
    (400086002197, 400086002, 400086002001, 400086002197, 400086002025, 197),
    (400086002198, 400086002, 400086002001, 400086002198, 400086002025, 198),
    (400086002199, 400086002, 400086002001, 400086002199, 400086002025, 199),
    (400086002200, 400086002, 400086002001, 400086002200, 400086002025, 200),
    (400086002201, 400086002, 400086002001, 400086002201, 400086002025, 201),
    (400086002202, 400086002, 400086002001, 400086002202, 400086002026, 202),
    (400086002203, 400086002, 400086002001, 400086002203, 400086002026, 203),
    (400086002204, 400086002, 400086002001, 400086002204, 400086002026, 204),
    (400086002205, 400086002, 400086002001, 400086002205, 400086002026, 205),
    (400086002206, 400086002, 400086002001, 400086002206, 400086002026, 206),
    (400086002207, 400086002, 400086002001, 400086002207, 400086002027, 207),
    (400086002208, 400086002, 400086002001, 400086002208, 400086002027, 208),
    (400086002209, 400086002, 400086002001, 400086002209, 400086002027, 209),
    (400086002210, 400086002, 400086002001, 400086002210, 400086002027, 210),
    (400086002211, 400086002, 400086002001, 400086002211, 400086002027, 211),
    (400086002212, 400086002, 400086002001, 400086002212, 400086002027, 212),
    (400086002213, 400086002, 400086002001, 400086002213, 400086002027, 213),
    (400086002214, 400086002, 400086002001, 400086002214, 400086002028, 214),
    (400086002215, 400086002, 400086002001, 400086002215, 400086002028, 215),
    (400086002216, 400086002, 400086002001, 400086002216, 400086002028, 216),
    (400086002217, 400086002, 400086002001, 400086002217, 400086002028, 217),
    (400086002218, 400086002, 400086002001, 400086002218, 400086002028, 218),
    (400086002219, 400086002, 400086002001, 400086002219, 400086002028, 219),
    (400086002220, 400086002, 400086002001, 400086002220, 400086002028, 220),
    (400086002221, 400086002, 400086002001, 400086002221, 400086002028, 221),
    (400086002222, 400086002, 400086002001, 400086002222, 400086002028, 222),
    (400086002223, 400086002, 400086002001, 400086002223, 400086002028, 223),
    (400086002224, 400086002, 400086002001, 400086002224, 400086002028, 224),
    (400086002225, 400086002, 400086002001, 400086002225, 400086002028, 225),
    (400086002226, 400086002, 400086002001, 400086002226, 400086002028, 226),
    (400086002227, 400086002, 400086002001, 400086002227, 400086002028, 227),
    (400086002228, 400086002, 400086002001, 400086002228, 400086002028, 228),
    (400086002229, 400086002, 400086002001, 400086002229, 400086002028, 229),
    (400086002230, 400086002, 400086002001, 400086002230, 400086002028, 230),
    (400086002231, 400086002, 400086002001, 400086002231, 400086002028, 231),
    (400086002232, 400086002, 400086002001, 400086002232, 400086002028, 232),
    (400086002233, 400086002, 400086002001, 400086002233, 400086002029, 233),
    (400086002234, 400086002, 400086002001, 400086002234, 400086002029, 234),
    (400086002235, 400086002, 400086002001, 400086002235, 400086002029, 235),
    (400086002236, 400086002, 400086002001, 400086002236, 400086002029, 236),
    (400086002237, 400086002, 400086002001, 400086002237, 400086002029, 237),
    (400086002238, 400086002, 400086002001, 400086002238, 400086002029, 238),
    (400086002239, 400086002, 400086002001, 400086002239, 400086002029, 239),
    (400086002240, 400086002, 400086002001, 400086002240, 400086002029, 240),
    (400086002241, 400086002, 400086002001, 400086002241, 400086002029, 241),
    (400086002242, 400086002, 400086002001, 400086002242, 400086002029, 242),
    (400086002243, 400086002, 400086002001, 400086002243, 400086002029, 243),
    (400086002244, 400086002, 400086002001, 400086002244, 400086002029, 244),
    (400086002245, 400086002, 400086002001, 400086002245, 400086002029, 245),
    (400086002246, 400086002, 400086002001, 400086002246, 400086002029, 246),
    (400086002247, 400086002, 400086002001, 400086002247, 400086002029, 247),
    (400086002248, 400086002, 400086002001, 400086002248, 400086002029, 248),
    (400086002249, 400086002, 400086002001, 400086002249, 400086002029, 249),
    (400086002250, 400086002, 400086002001, 400086002250, 400086002029, 250),
    (400086002251, 400086002, 400086002001, 400086002251, 400086002029, 251),
    (400086002252, 400086002, 400086002001, 400086002252, 400086002029, 252),
    (400086002253, 400086002, 400086002001, 400086002253, 400086002029, 253),
    (400086002254, 400086002, 400086002001, 400086002254, 400086002029, 254),
    (400086002255, 400086002, 400086002001, 400086002255, 400086002029, 255),
    (400086002256, 400086002, 400086002001, 400086002256, 400086002029, 256),
    (400086002257, 400086002, 400086002001, 400086002257, 400086002029, 257),
    (400086002258, 400086002, 400086002001, 400086002258, 400086002030, 258),
    (400086002259, 400086002, 400086002001, 400086002259, 400086002030, 259),
    (400086002260, 400086002, 400086002001, 400086002260, 400086002030, 260),
    (400086002261, 400086002, 400086002001, 400086002261, 400086002030, 261),
    (400086002262, 400086002, 400086002001, 400086002262, 400086002030, 262),
    (400086002263, 400086002, 400086002001, 400086002263, 400086002030, 263),
    (400086002264, 400086002, 400086002001, 400086002264, 400086002030, 264),
    (400086002265, 400086002, 400086002001, 400086002265, 400086002030, 265),
    (400086002266, 400086002, 400086002001, 400086002266, 400086002030, 266),
    (400086002267, 400086002, 400086002001, 400086002267, 400086002030, 267),
    (400086002268, 400086002, 400086002001, 400086002268, 400086002030, 268),
    (400086002269, 400086002, 400086002001, 400086002269, 400086002030, 269),
    (400086002270, 400086002, 400086002001, 400086002270, 400086002030, 270),
    (400086002271, 400086002, 400086002001, 400086002271, 400086002030, 271),
    (400086002272, 400086002, 400086002001, 400086002272, 400086002030, 272),
    (400086002273, 400086002, 400086002001, 400086002273, 400086002030, 273),
    (400086002274, 400086002, 400086002001, 400086002274, 400086002030, 274),
    (400086002275, 400086002, 400086002001, 400086002275, 400086002031, 275),
    (400086002276, 400086002, 400086002001, 400086002276, 400086002031, 276),
    (400086002277, 400086002, 400086002001, 400086002277, 400086002031, 277),
    (400086002278, 400086002, 400086002001, 400086002278, 400086002031, 278),
    (400086002279, 400086002, 400086002001, 400086002279, 400086002031, 279),
    (400086002280, 400086002, 400086002001, 400086002280, 400086002031, 280),
    (400086002281, 400086002, 400086002001, 400086002281, 400086002031, 281),
    (400086002282, 400086002, 400086002001, 400086002282, 400086002031, 282),
    (400086002283, 400086002, 400086002001, 400086002283, 400086002031, 283),
    (400086002284, 400086002, 400086002001, 400086002284, 400086002032, 284),
    (400086002285, 400086002, 400086002001, 400086002285, 400086002032, 285),
    (400086002286, 400086002, 400086002001, 400086002286, 400086002032, 286),
    (400086002287, 400086002, 400086002001, 400086002287, 400086002032, 287),
    (400086002288, 400086002, 400086002001, 400086002288, 400086002032, 288),
    (400086002289, 400086002, 400086002001, 400086002289, 400086002032, 289),
    (400086002290, 400086002, 400086002001, 400086002290, 400086002032, 290),
    (400086002291, 400086002, 400086002001, 400086002291, 400086002033, 291),
    (400086002292, 400086002, 400086002001, 400086002292, 400086002033, 292),
    (400086002293, 400086002, 400086002001, 400086002293, 400086002033, 293),
    (400086002294, 400086002, 400086002001, 400086002294, 400086002033, 294),
    (400086002295, 400086002, 400086002001, 400086002295, 400086002033, 295),
    (400086002296, 400086002, 400086002001, 400086002296, 400086002033, 296),
    (400086002297, 400086002, 400086002001, 400086002297, 400086002034, 297),
    (400086002298, 400086002, 400086002001, 400086002298, 400086002034, 298),
    (400086002299, 400086002, 400086002001, 400086002299, 400086002034, 299),
    (400086002300, 400086002, 400086002001, 400086002300, 400086002034, 300),
    (400086002301, 400086002, 400086002001, 400086002301, 400086002034, 301),
    (400086002302, 400086002, 400086002001, 400086002302, 400086002034, 302),
    (400086002303, 400086002, 400086002001, 400086002303, 400086002034, 303),
    (400086002304, 400086002, 400086002001, 400086002304, 400086002034, 304),
    (400086002305, 400086002, 400086002001, 400086002305, 400086002034, 305),
    (400086002306, 400086002, 400086002001, 400086002306, 400086002034, 306),
    (400086002307, 400086002, 400086002001, 400086002307, 400086002034, 307),
    (400086002308, 400086002, 400086002001, 400086002308, 400086002034, 308),
    (400086002309, 400086002, 400086002001, 400086002309, 400086002035, 309),
    (400086002310, 400086002, 400086002001, 400086002310, 400086002035, 310),
    (400086002311, 400086002, 400086002001, 400086002311, 400086002035, 311),
    (400086002312, 400086002, 400086002001, 400086002312, 400086002035, 312),
    (400086002313, 400086002, 400086002001, 400086002313, 400086002035, 313),
    (400086002314, 400086002, 400086002001, 400086002314, 400086002036, 314),
    (400086002315, 400086002, 400086002001, 400086002315, 400086002036, 315),
    (400086002316, 400086002, 400086002001, 400086002316, 400086002036, 316),
    (400086002317, 400086002, 400086002001, 400086002317, 400086002036, 317),
    (400086002318, 400086002, 400086002001, 400086002318, 400086002036, 318),
    (400086002319, 400086002, 400086002001, 400086002319, 400086002036, 319),
    (400086002320, 400086002, 400086002001, 400086002320, 400086002036, 320),
    (400086002321, 400086002, 400086002001, 400086002321, 400086002036, 321),
    (400086002322, 400086002, 400086002001, 400086002322, 400086002036, 322),
    (400086002323, 400086002, 400086002001, 400086002323, 400086002036, 323),
    (400086002324, 400086002, 400086002001, 400086002324, 400086002036, 324),
    (400086002325, 400086002, 400086002001, 400086002325, 400086002037, 325),
    (400086002326, 400086002, 400086002001, 400086002326, 400086002037, 326),
    (400086002327, 400086002, 400086002001, 400086002327, 400086002037, 327),
    (400086002328, 400086002, 400086002001, 400086002328, 400086002037, 328),
    (400086002329, 400086002, 400086002001, 400086002329, 400086002038, 329),
    (400086002330, 400086002, 400086002001, 400086002330, 400086002038, 330),
    (400086002331, 400086002, 400086002001, 400086002331, 400086002038, 331),
    (400086002332, 400086002, 400086002001, 400086002332, 400086002038, 332),
    (400086002333, 400086002, 400086002001, 400086002333, 400086002038, 333),
    (400086002334, 400086002, 400086002001, 400086002334, 400086002038, 334),
    (400086002335, 400086002, 400086002001, 400086002335, 400086002038, 335),
    (400086002336, 400086002, 400086002001, 400086002336, 400086002038, 336),
    (400086002337, 400086002, 400086002001, 400086002337, 400086002038, 337),
    (400086002338, 400086002, 400086002001, 400086002338, 400086002039, 338),
    (400086002339, 400086002, 400086002001, 400086002339, 400086002039, 339),
    (400086002340, 400086002, 400086002001, 400086002340, 400086002040, 340),
    (400086002341, 400086002, 400086002001, 400086002341, 400086002040, 341),
    (400086002342, 400086002, 400086002001, 400086002342, 400086002040, 342),
    (400086002343, 400086002, 400086002001, 400086002343, 400086002040, 343),
    (400086002344, 400086002, 400086002001, 400086002344, 400086002040, 344),
    (400086002345, 400086002, 400086002001, 400086002345, 400086002040, 345),
    (400086002346, 400086002, 400086002001, 400086002346, 400086002040, 346),
    (400086002347, 400086002, 400086002001, 400086002347, 400086002040, 347),
    (400086002348, 400086002, 400086002001, 400086002348, 400086002040, 348),
    (400086002349, 400086002, 400086002001, 400086002349, 400086002040, 349),
    (400086002350, 400086002, 400086002001, 400086002350, 400086002041, 350),
    (400086002351, 400086002, 400086002001, 400086002351, 400086002041, 351),
    (400086002352, 400086002, 400086002001, 400086002352, 400086002041, 352),
    (400086002353, 400086002, 400086002001, 400086002353, 400086002041, 353),
    (400086002354, 400086002, 400086002001, 400086002354, 400086002042, 354),
    (400086002355, 400086002, 400086002001, 400086002355, 400086002042, 355),
    (400086002356, 400086002, 400086002001, 400086002356, 400086002042, 356),
    (400086002357, 400086002, 400086002001, 400086002357, 400086002042, 357),
    (400086002358, 400086002, 400086002001, 400086002358, 400086002042, 358),
    (400086002359, 400086002, 400086002001, 400086002359, 400086002043, 359),
    (400086002360, 400086002, 400086002001, 400086002360, 400086002043, 360),
    (400086002361, 400086002, 400086002001, 400086002361, 400086002043, 361),
    (400086002362, 400086002, 400086002001, 400086002362, 400086002043, 362),
    (400086002363, 400086002, 400086002001, 400086002363, 400086002043, 363),
    (400086002364, 400086002, 400086002001, 400086002364, 400086002043, 364),
    (400086002365, 400086002, 400086002001, 400086002365, 400086002043, 365),
    (400086002366, 400086002, 400086002001, 400086002366, 400086002043, 366);

-- ----------------------------------------------------------------------------
-- 10. LOAD SUMMARY (printed by psql before COMMIT)
-- ----------------------------------------------------------------------------
SELECT 'menu_category' AS table_name, count(*) AS rows_loaded FROM menu_category WHERE restaurant_id = 400086002
UNION ALL SELECT 'menu_item', count(*) FROM menu_item WHERE restaurant_id = 400086002
UNION ALL SELECT 'menu_item_variant', count(*) FROM menu_item_variant v JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 400086002
UNION ALL SELECT 'menu_item_price', count(*) FROM menu_item_price p JOIN menu_item_variant v USING (variant_id) JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 400086002
UNION ALL SELECT 'menu_board_item', count(*) FROM menu_board_item WHERE restaurant_id = 400086002
UNION ALL SELECT 'items linked to a canonical dish', count(*) FROM menu_item WHERE restaurant_id = 400086002 AND canonical_dish_id IS NOT NULL
UNION ALL SELECT 'items needing review', count(*) FROM menu_item WHERE restaurant_id = 400086002 AND verification_status_code = 'needs_review';

COMMIT;

-- ============================================================================
-- BLOCK 1 - ROWS NEEDING REVIEW OR WITH CONFIDENCE < 0.80
-- ============================================================================
-- menu_item rows (0):
-- menu_item_price rows (21):
--   - price 400086002054  Paneer Chilli Grill / Regular = 320.00  [pages[2].sections[2].columns[0].items[2]]  conf 0.75: category header is 'W / B' but only one price is printed; unclear whether it applies to both breads (single Regular variant kept)
--   - price 400086002061  Marina Grill / Regular = 280.00  [pages[2].sections[2].columns[0].items[6]]  conf 0.75: category header is 'W / B' but only one price is printed; unclear whether it applies to both breads (single Regular variant kept)
--   - price 400086002062  Super Grill / Regular = 290.00  [pages[2].sections[2].columns[0].items[7]]  conf 0.75: category header is 'W / B' but only one price is printed; unclear whether it applies to both breads (single Regular variant kept)
--   - price 400086002233  Kung Pao Gravy / Paneer = 340.00  [pages[5].sections[3].columns[0].items[6]]  conf 0.75: price not printed for option 'Paneer'; filled with the maximum of the item's printed prices (340.00) per the owner's rule
--   - price 400086002291  Pudina Paratha / Naan / Kulcha / Kulcha = 120.00  [pages[6].sections[1].columns[0].items[6]]  conf 0.75: price not printed for option 'Kulcha'; filled with the maximum of the item's printed prices (120.00) per the owner's rule
--   - price 400086002294  Ajwain Paratha / Naan / Kulcha / Kulcha = 120.00  [pages[6].sections[1].columns[0].items[7]]  conf 0.70: price not printed for option 'Kulcha'; filled with the maximum of the item's printed prices (120.00) per the owner's rule
--   - price 400086002297  Methi Paratha / Naan / Kulcha / Kulcha = 120.00  [pages[6].sections[1].columns[0].items[8]]  conf 0.70: price not printed for option 'Kulcha'; filled with the maximum of the item's printed prices (120.00) per the owner's rule
--   - price 400086002300  Stuff Paneer Kulcha / Stuff Cheese Kulcha / Plain = 140.00  [pages[6].sections[1].columns[0].items[10]]  conf 0.75: OCR price labels (Plain / Stuff Cheese) do not match the two named options (Stuff Paneer Kulcha / Stuff Cheese Kulcha); labels kept verbatim
--   - price 400086002301  Stuff Paneer Kulcha / Stuff Cheese Kulcha / Stuff Cheese = 150.00  [pages[6].sections[1].columns[0].items[10]]  conf 0.75: OCR price labels (Plain / Stuff Cheese) do not match the two named options (Stuff Paneer Kulcha / Stuff Cheese Kulcha); labels kept verbatim
--   - price 400086002302  Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg. / Aloo = 150.00  [pages[6].sections[1].columns[0].items[11]]  conf 0.70: 4 options but only 2 prices printed; printed prices assigned to the first 2 options in order (mapping is a guess)
--   - price 400086002303  Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg. / Gobi = 160.00  [pages[6].sections[1].columns[0].items[11]]  conf 0.70: 4 options but only 2 prices printed; printed prices assigned to the first 2 options in order (mapping is a guess)
--   - price 400086002304  Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg. / Onion = 160.00  [pages[6].sections[1].columns[0].items[11]]  conf 0.60: price not printed for option 'Onion'; filled with the maximum of the item's printed prices (160.00) per the owner's rule
--   - price 400086002305  Kulcha Stuffing-: Aloo, Gobi, Onion Or Mix Veg. / Mix Veg. = 160.00  [pages[6].sections[1].columns[0].items[11]]  conf 0.60: price not printed for option 'Mix Veg.'; filled with the maximum of the item's printed prices (160.00) per the owner's rule
--   - price 400086002306  Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg. / Aloo = 150.00  [pages[6].sections[1].columns[0].items[12]]  conf 0.70: 4 options but only 2 prices printed; printed prices assigned to the first 2 options in order (mapping is a guess)
--   - price 400086002307  Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg. / Gobi = 160.00  [pages[6].sections[1].columns[0].items[12]]  conf 0.70: 4 options but only 2 prices printed; printed prices assigned to the first 2 options in order (mapping is a guess)
--   - price 400086002308  Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg. / Onion = 160.00  [pages[6].sections[1].columns[0].items[12]]  conf 0.60: price not printed for option 'Onion'; filled with the maximum of the item's printed prices (160.00) per the owner's rule
--   - price 400086002309  Stuffed Paratha-: Aloo, Gobi, Onion Or Mix Veg. / Mix Veg. = 160.00  [pages[6].sections[1].columns[0].items[12]]  conf 0.60: price not printed for option 'Mix Veg.'; filled with the maximum of the item's printed prices (160.00) per the owner's rule
--   - price 400086002310  Makai Roti / Bajra Roti / Missi Roti / Garlic Roti / Makai Roti = 80.00  [pages[6].sections[1].columns[0].items[13]]  conf 0.70: 4 options but only 2 prices printed; printed prices assigned to the first 2 options in order (mapping is a guess)
--   - price 400086002311  Makai Roti / Bajra Roti / Missi Roti / Garlic Roti / Bajra Roti = 90.00  [pages[6].sections[1].columns[0].items[13]]  conf 0.70: 4 options but only 2 prices printed; printed prices assigned to the first 2 options in order (mapping is a guess)
--   - price 400086002312  Makai Roti / Bajra Roti / Missi Roti / Garlic Roti / Missi Roti = 90.00  [pages[6].sections[1].columns[0].items[13]]  conf 0.60: price not printed for option 'Missi Roti'; filled with the maximum of the item's printed prices (90.00) per the owner's rule
--   - price 400086002313  Makai Roti / Bajra Roti / Missi Roti / Garlic Roti / Garlic Roti = 90.00  [pages[6].sections[1].columns[0].items[13]]  conf 0.60: price not printed for option 'Garlic Roti'; filled with the maximum of the item's printed prices (90.00) per the owner's rule

-- ============================================================================
-- BLOCK 2 - JSON CONTENT WITH NO SCHEMA COLUMN (kept here, not dropped)
-- ============================================================================
--   - Other outlets in the JSON header, not loaded (this script is Ghatkopar only): Thanekar +91 8433 8433 09, Mulund +91 8433 8433 63.
--   - JSON "price range": "600-800" (basis per person / for two not stated).
--   - Free-delivery radius: "2km" (minimum order 250 is loaded).
--   - Cover page (TFT01.jpg): "ORDER NOW", "PURE VEG", "TFT", "TASTE THE MYTH".
--   - Closing page (TFT10.jpg): "TFT Brings To You The Best Serve With The Best Taste & Of The Best Quality In Your Own Suburb. Meet Your Foody Life With TFT Right Now!"; "*45-55 min of patience will lead you to awesome food." (preparation-time note); "*Government Taxes as Applicable".
--   - Page images TFT01.jpg .. TFT10.jpg: no media storage URIs in the JSON, so media_asset / menu_extraction_image are not populated.
--   - JSON column_order is not stored (no column); sections follow JSON array order. On TFT06.jpg "ORIENTAL GRAVY & THAI CURRY" (column 1) appears after the column-2 sections in the array; array order kept.
--   - EXTRA TOPPINGS (Butter, Cheese, Mayonaise, Paneer, Sweet Corn, Veggies, Schezwan Sauce) are loaded as ordinary items; the JSON does not say which dishes they apply to, so no addon_group / menu_item_addon_group rows were created.
--   - Platters (Assorted Tandoor Platter, Assorted Lebanese Platter, Roti Ki Tokri, 4 in 1 Pizza) are loaded as plain items; no component items are established in the JSON, so no bundle rows.
--   - change_event_outbox is not written by this script (publisher integration is outside the JSON load).
