-- ============================================================================
-- HOTEL KILLEDAR -- MENU INSERT SCRIPT (PostgreSQL)
-- establishment_id = restaurant_id = source_id = 416520001, all supplied directly in the
-- source JSON. Every child table has its own counter starting at 416520001001.
-- 11 categories, 101 menu items, 111 variants.
--
-- LOOKUP CASING: per explicit instruction, every lookup code is UPPERCASE except
-- cuisine tags (cuisine_ + lowercase), matching khaustan_lookup_data_seed_
-- KhaustanRestaurantMenu.sql exactly (protein_type: CHICKEN/MUTTON/SEAFOOD;
-- platform_tag: HALAL/NO_BEEF; delivery_provider: ZOMATO/SWIGGY). This script does
-- not insert into any lookup table -- resolves existing rows only.
-- No delivery partners (JSON explicitly states 'No delivery partners') -- no restaurant_delivery_provider rows.
-- Fish Thali / Fry items priced 'APS' (as per season) -- is_market_price = TRUE on all of them, per the
-- menu's own note that availability is daily/seasonal.
--
-- 21 items flagged verification_status_code = 'needs_review'.
--
-- CANONICAL DISHES (revised): the previous version created 33 dishes with restaurant-scoped ids (416520001xxx). All 89 dishes were
-- re-checked against canonical_dish: 56 already existed exactly (unchanged), 23 are spelling / phonetic / word-order variants of
-- existing dishes (existing ids are used), and 10 are genuinely new and get ids in the category ranges (10938, 12524,
-- 16520-16521, 17221-17224, 60508-60509); their canonical_dish_name ids are 416520001090..416520001099.
-- PREREQUISITE: if the previous version of this script was loaded, its restaurant data (menu items etc.) must be deleted first. The
-- pre-flight DO block then removes the 33 now-unreferenced old-style canonical rows itself; if they are still referenced it stops
-- with a clear message. Source of truth for every decision: canonical_dish_reconciliation_killedar_416520001.csv
-- ============================================================================

--\connect "KhaustanRestaurantMenu"

BEGIN;

-- Guard: every protein_type code this script resolves must already exist (lookup is read-only).
DO $$
DECLARE v_missing text;
BEGIN
    SELECT string_agg(c, ', ') INTO v_missing FROM unnest(ARRAY['CHICKEN', 'MUTTON', 'SEAFOOD']) AS c
    WHERE NOT EXISTS (SELECT 1 FROM protein_type WHERE protein_type.code = c);
    IF v_missing IS NOT NULL THEN
        RAISE WARNING 'protein_type code(s) not found in lookup: % -- affected menu_item rows will have protein_type_id NULL. Codes are case-sensitive (UPPERCASE).', v_missing;
    END IF;
END $$;

-- Pre-flight: canonical_dish state must match what this script was generated against.
-- It is read-only EXCEPT for step 0, which removes the old-style canonical rows (ids 416520001001..416520001999) created by the
-- previous version of this script, and only when they are exactly the expected rows and are no longer referenced by any menu item.
DO $$
DECLARE v_n INT; v_bad TEXT; v_old INT;
BEGIN
    -- 0) old-style canonical rows from the previous version of this script
    SELECT count(*) INTO v_old FROM canonical_dish WHERE canonical_dish_id BETWEEN 416520001001 AND 416520001999;
    IF v_old > 0 THEN
        SELECT count(*) INTO v_n
        FROM (VALUES
        (416520001004, 'chanak'),
        (416520001005, 'tisare'),
        (416520001006, 'verle'),
        (416520001007, 'crabs'),
        (416520001008, 'bangada'),
        (416520001013, 'cream of soup'),
        (416520001019, 'chicken stick'),
        (416520001020, 'barbeque'),
        (416520001022, 'chicken lollipop masala'),
        (416520001024, 'hot & sweet'),
        (416520001028, 'baby corn chilli'),
        (416520001030, 'dragon veg'),
        (416520001031, 'veg crispy'),
        (416520001034, 'shezwan fried rice'),
        (416520001035, 'sandwich rice'),
        (416520001037, 'pizza rice'),
        (416520001038, 'singapore rice'),
        (416520001039, 'hongkong rice'),
        (416520001041, 'kabsa rice tandoori'),
        (416520001042, 'misba kabsa rice'),
        (416520001043, 'lollipop kabsa rice'),
        (416520001045, 'veg handi'),
        (416520001046, 'veg kolhapuri'),
        (416520001047, 'veg kadhai'),
        (416520001049, 'aloo matar'),
        (416520001050, 'paneer matar'),
        (416520001058, 'chicken kadhai'),
        (416520001062, 'murgh musallam'),
        (416520001064, 'veg biryani'),
        (416520001070, 'mutton kadhai'),
        (416520001079, 'bhakari'),
        (416520001086, 'harabhara kebab veg'),
        (416520001089, 'baby corn kebab')
        ) AS v(id, norm)
        JOIN canonical_dish d ON d.canonical_dish_id = v.id AND d.normalized_name = v.norm;
        IF v_n <> v_old THEN
            RAISE EXCEPTION 'Unexpected canonical_dish rows in the old-style id range 416520001001..416520001999 (% rows, % recognised) - review manually', v_old, v_n;
        END IF;
        IF EXISTS (SELECT 1 FROM menu_item WHERE canonical_dish_id BETWEEN 416520001001 AND 416520001999)
           OR EXISTS (SELECT 1 FROM brand_menu_template_item WHERE canonical_dish_id BETWEEN 416520001001 AND 416520001999) THEN
            RAISE EXCEPTION 'Old-style canonical_dish rows (416520001xxx) are still referenced by menu items - delete the previous Hotel Killedar load first (or run killedar_repoint_canonical_ids_OPTIONAL.sql)';
        END IF;
        IF EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id BETWEEN 416520001001 AND 416520001999
                   AND (canonical_dish_name_id NOT BETWEEN 416520001001 AND 416520001089 OR name_type_code <> 'primary')) THEN
            RAISE EXCEPTION 'Old-style canonical dishes have extra canonical_dish_name rows (aliases / other ids) - review manually';
        END IF;
        DELETE FROM canonical_dish_name WHERE canonical_dish_id BETWEEN 416520001001 AND 416520001999;
        DELETE FROM canonical_dish WHERE canonical_dish_id BETWEEN 416520001001 AND 416520001999;
        RAISE NOTICE 'Removed % unreferenced old-style canonical_dish rows created by the previous version of this script', v_old;
    END IF;
    -- 1) every EXISTING canonical dish referenced by the menu items must exist with the expected normalized_name
    SELECT count(*) INTO v_n
    FROM (VALUES
        (10044, 'baby corn chilly'),
        (10053, 'banjara kebab'),
        (10253, 'finger chips'),
        (10296, 'gobi manchurian'),
        (10310, 'hara bhara kabab'),
        (10405, 'malai kebab'),
        (10474, 'mushroom chilli'),
        (10490, 'mushroom tikka'),
        (10538, 'pahadi kebab'),
        (10555, 'paneer chilli'),
        (10631, 'paneer tikka'),
        (10753, 'seekh kebab'),
        (10871, 'veg. crispy'),
        (12071, 'chicken 65'),
        (12087, 'chicken barbeque dry'),
        (12113, 'chicken chilli'),
        (12123, 'chicken crispy'),
        (12165, 'chicken lollipop'),
        (12170, 'chicken lollypop masala'),
        (12288, 'chicken tikka'),
        (12363, 'murg tandoori kabsa'),
        (12512, 'tandoori chicken'),
        (13017, 'aloo mutter'),
        (13071, 'bhakri'),
        (13167, 'chilly rice'),
        (13189, 'clear soup'),
        (13207, 'cream of veg soup'),
        (13235, 'dal fry'),
        (13254, 'dal tadka'),
        (13309, 'fried rice'),
        (13352, 'hakka noodles'),
        (13367, 'hong kong rice'),
        (13371, 'hot & sour soup'),
        (13395, 'jeera rice'),
        (13409, 'kaju masala'),
        (13495, 'manchow soup'),
        (13552, 'mix veg'),
        (13592, 'mushroom masala'),
        (13644, 'packing rice'),
        (13744, 'schezwan fried rice'),
        (13793, 'steam rice'),
        (13865, 'tomato soup'),
        (13869, 'triple rice'),
        (13977, 'veg. biryani'),
        (14151, 'paneer mutter'),
        (14204, 'paneer tikka masala'),
        (16002, 'butter chicken'),
        (16013, 'chicken thali'),
        (16070, 'chicken stic'),
        (16110, 'chicken biryani'),
        (16194, 'chicken handi'),
        (16224, 'chicken kadai'),
        (16238, 'chicken kolhapuri'),
        (16297, 'chicken masala'),
        (16342, 'chicken patiala'),
        (16426, 'chicken tikka masala'),
        (16453, 'dragon chicken'),
        (16478, 'murg musallam'),
        (17002, 'bangda'),
        (17044, 'pomfret'),
        (17053, 'prawns'),
        (17212, 'surmai'),
        (18063, 'mutton bhuna'),
        (18065, 'mutton biryani'),
        (18101, 'mutton kadai'),
        (18132, 'mutton malvani'),
        (18134, 'mutton masala'),
        (23020, 'butter naan'),
        (23052, 'garlic naan'),
        (23061, 'kulcha'),
        (23080, 'naan'),
        (23085, 'paratha'),
        (23094, 'roti'),
        (60154, 'veg thali'),
        (60166, 'veg. dragon'),
        (60180, 'veg. handi'),
        (60198, 'veg. kadai'),
        (60208, 'veg. kolhapuri'),
        (60262, 'veg. singapore rice')
    ) AS v(id, norm)
    JOIN canonical_dish d ON d.canonical_dish_id = v.id AND d.normalized_name = v.norm;
    IF v_n <> 79 THEN
        RAISE EXCEPTION 'Only % of 79 referenced existing canonical_dish (id, normalized_name) pairs match the database - canonical_dish has changed since this script was generated; regenerate this script', v_n;
    END IF;
    -- 2) the 10 NEW dishes: id must be free (or already hold the same dish on a re-run) and the name must not exist under another id
    SELECT string_agg(v.id::text, ', ') INTO v_bad
    FROM (VALUES
        (17221, 'chanak'),
        (17222, 'tisare'),
        (17223, 'verle'),
        (17224, 'crabs'),
        (12524, 'chicken hot & sweet'),
        (16520, 'misba kabsa rice'),
        (16521, 'lollipop kabsa rice'),
        (60508, 'sandwich rice'),
        (60509, 'pizza rice'),
        (10938, 'baby corn kebab')
    ) AS v(id, norm)
    WHERE EXISTS (SELECT 1 FROM canonical_dish d WHERE d.canonical_dish_id = v.id AND d.normalized_name <> v.norm)
       OR EXISTS (SELECT 1 FROM canonical_dish d WHERE d.normalized_name = v.norm AND d.canonical_dish_id <> v.id);
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'New canonical_dish id/name conflict for id(s): % - the id is taken by another dish or the name already exists under another id (reuse that dish instead)', v_bad;
    END IF;
    -- 3) canonical_dish_name ids for the new dishes must be free
    IF EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_name_id BETWEEN 416520001090 AND 416520001099 AND canonical_dish_id NOT IN (17221, 17222, 17223, 17224, 12524, 16520, 16521, 60508, 60509, 10938)) THEN
        RAISE EXCEPTION 'canonical_dish_name ids 416520001090..416520001099 are already used by other dishes';
    END IF;
END $$;

-- ----------------------------------------------------------------------
-- Establishment & restaurant
-- ----------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2,
                            locality, city, state, postal_code, country_code, latitude, longitude, status_code)
SELECT 416520001, 'Hotel Killedar', 'hotel killedar', 'Opposite Kudal Bus Stand, Bhoslewadi', 'Near Kudal Court',
       'Kudal', 'Sindhudurg', 'Maharashtra', '416520', 'IN', 16.012037653188376, 73.68490588567104, 'active'
WHERE NOT EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 416520001);

INSERT INTO restaurant (restaurant_id, establishment_id, brand_id, display_name, normalized_name,
                         veg_nonveg_status, has_bar, bar_license_type, status_code, verification_status_code)
SELECT 416520001, 416520001, NULL, 'Hotel Killedar', 'hotel killedar',
       'veg_and_nonveg', FALSE, 'none', 'active', 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 416520001);

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT * FROM (VALUES
    (416520001001, 416520001, '7719040595', TRUE)
) AS v WHERE NOT EXISTS (SELECT 1 FROM restaurant_phone WHERE restaurant_id = 416520001);

INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
SELECT * FROM (VALUES
    (416520001001, 416520001, 1, 1, '10:00'::time, '23:00'::time),
    (416520001002, 416520001, 2, 1, '10:00'::time, '23:00'::time),
    (416520001003, 416520001, 3, 1, '10:00'::time, '23:00'::time),
    (416520001004, 416520001, 4, 1, '10:00'::time, '23:00'::time),
    (416520001005, 416520001, 5, 1, '10:00'::time, '23:00'::time),
    (416520001006, 416520001, 6, 1, '10:00'::time, '23:00'::time),
    (416520001007, 416520001, 7, 1, '10:00'::time, '23:00'::time)
) AS v WHERE NOT EXISTS (SELECT 1 FROM restaurant_hours WHERE restaurant_id = 416520001);

INSERT INTO source_record (source_id, source_type_code, source_uri)
SELECT 416520001, 'ai_menu_extraction', 'Hotel_Killedar_Menu.json'
WHERE NOT EXISTS (SELECT 1 FROM source_record WHERE source_id = 416520001);

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 416520001001, 416520001, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
WHERE NOT EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 416520001);

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 416520001001, 416520001, 'A La Carte', 'a_la_carte'
WHERE NOT EXISTS (SELECT 1 FROM menu_board WHERE menu_board_id = 416520001001);

-- Menu categories (11, in source order)
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
SELECT * FROM (VALUES
    (416520001001, 416520001, 'Fish Thali / Fry', 1),
    (416520001002, 416520001, 'Soups', 2),
    (416520001003, 416520001, 'Starter', 3),
    (416520001004, 416520001, 'Veg Starter', 4),
    (416520001005, 416520001, 'Rice & Noodles', 5),
    (416520001006, 416520001, 'Indian Main Course (Veg)', 6),
    (416520001007, 416520001, 'Indian Main Course', 7),
    (416520001008, 416520001, 'Biryani', 8),
    (416520001009, 416520001, 'Mutton', 9),
    (416520001010, 416520001, 'Tandoori', 10),
    (416520001011, 416520001, 'Kabab', 11)
) AS v WHERE NOT EXISTS (SELECT 1 FROM menu_category WHERE restaurant_id = 416520001);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT * FROM (VALUES
    (416520001, 416520001001, 416520001001, 1),
    (416520001, 416520001001, 416520001002, 2),
    (416520001, 416520001001, 416520001003, 3),
    (416520001, 416520001001, 416520001004, 4),
    (416520001, 416520001001, 416520001005, 5),
    (416520001, 416520001001, 416520001006, 6),
    (416520001, 416520001001, 416520001007, 7),
    (416520001, 416520001001, 416520001008, 8),
    (416520001, 416520001001, 416520001009, 9),
    (416520001, 416520001001, 416520001010, 10),
    (416520001, 416520001001, 416520001011, 11)
) AS v WHERE NOT EXISTS (SELECT 1 FROM menu_board_category WHERE restaurant_id = 416520001);

-- Canonical dishes -- revised convention (89 distinct dishes): 56 reuse existing rows, 23 are variants of existing dishes,
-- 10 are genuinely new and are created here with ids in the category ranges (no restaurant-scoped 416520001xxx ids).
-- Existing dishes need no insert: menu_item rows below carry their ids directly (verified by the pre-flight DO block).
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 17221, 'Chanak', 'chanak', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17221 OR normalized_name = 'chanak');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001090, 17221, 'en', 'Chanak', 'chanak', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17221) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 17221 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 17222, 'Tisare', 'tisare', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17222 OR normalized_name = 'tisare');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001091, 17222, 'en', 'Tisare', 'tisare', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17222) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 17222 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 17223, 'Verle', 'verle', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17223 OR normalized_name = 'verle');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001092, 17223, 'en', 'Verle', 'verle', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17223) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 17223 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 17224, 'Crabs', 'crabs', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17224 OR normalized_name = 'crabs');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001093, 17224, 'en', 'Crabs', 'crabs', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 17224) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 17224 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 12524, 'Chicken Hot & Sweet', 'chicken hot & sweet', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 12524 OR normalized_name = 'chicken hot & sweet');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001094, 12524, 'en', 'Chicken Hot & Sweet', 'chicken hot & sweet', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 12524) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 12524 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 16520, 'Misba Kabsa Rice', 'misba kabsa rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 16520 OR normalized_name = 'misba kabsa rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001095, 16520, 'en', 'Misba Kabsa Rice', 'misba kabsa rice', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 16520) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 16520 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 16521, 'Lollipop Kabsa Rice', 'lollipop kabsa rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 16521 OR normalized_name = 'lollipop kabsa rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001096, 16521, 'en', 'Lollipop Kabsa Rice', 'lollipop kabsa rice', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 16521) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 16521 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 60508, 'Sandwich Rice', 'sandwich rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 60508 OR normalized_name = 'sandwich rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001097, 60508, 'en', 'Sandwich Rice', 'sandwich rice', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 60508) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 60508 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 60509, 'Pizza Rice', 'pizza rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 60509 OR normalized_name = 'pizza rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001098, 60509, 'en', 'Pizza Rice', 'pizza rice', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 60509) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 60509 AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 10938, 'Baby Corn Kebab', 'baby corn kebab', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 10938 OR normalized_name = 'baby corn kebab');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 416520001099, 10938, 'en', 'Baby Corn Kebab', 'baby corn kebab', 'primary'
WHERE EXISTS (SELECT 1 FROM canonical_dish WHERE canonical_dish_id = 10938) AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_id = 10938 AND name_type_code = 'primary');

-- Menu items, variants, prices, board links, provenance (101 items / 111 variants)
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001001, 416520001, 416520001001, 17212,  -- canonical 'surmai': existing 17212 (unchanged)
       'Surmai', 'surmai', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001001);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001001, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001001);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001001, 416520001, 416520001001, 416520001001, 416520001001, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001001);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001001, 416520001001, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001001);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001001, 416520001001, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001001);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001002, 416520001, 416520001001, 17044,  -- canonical 'pomfret': existing 17044 (unchanged)
       'Pomfret', 'pomfret', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001002);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001002, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001002);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001002, 416520001, 416520001001, 416520001002, 416520001001, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001002);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001002, 416520001002, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001002);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001002, 416520001002, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001002);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001003, 416520001, 416520001001, 17053,  -- canonical 'prawns': existing 17053 (unchanged)
       'Prawns', 'prawns', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001003);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001003, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001003);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001003, 416520001, 416520001001, 416520001003, 416520001001, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001003);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001003, 416520001003, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001003);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001003, 416520001003, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001003);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001004, 416520001, 416520001001, 17221,  -- canonical 'chanak': was old-style 416520001004 -> NEW 17221 'Chanak'
       'Chanak', 'chanak', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001004);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001004, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001004);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001004, 416520001, 416520001001, 416520001004, 416520001001, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001004);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001004, 416520001004, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001004);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001004, 416520001004, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001004);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001005, 416520001, 416520001001, 17222,  -- canonical 'tisare': was old-style 416520001005 -> NEW 17222 'Tisare'
       'Tisare', 'tisare', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001005);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001005, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001005);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001005, 416520001, 416520001001, 416520001005, 416520001001, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001005);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001005, 416520001005, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001005);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001005, 416520001005, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001005);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001006, 416520001, 416520001001, 17223,  -- canonical 'verle': was old-style 416520001006 -> NEW 17223 'Verle'
       'Verle', 'verle', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001006);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001006, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001006);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001006, 416520001, 416520001001, 416520001006, 416520001001, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001006);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001006, 416520001006, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001006);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001006, 416520001006, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001006);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001007, 416520001, 416520001001, 17224,  -- canonical 'crabs': was old-style 416520001007 -> NEW 17224 'Crabs'
       'Crabs', 'crabs', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001007);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001007, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001007);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001007, 416520001, 416520001001, 416520001007, 416520001001, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001007);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001007, 416520001007, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001007);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001007, 416520001007, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001007);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001008, 416520001, 416520001001, 17002,  -- canonical 'bangada': was old-style 416520001008 -> existing 17002 'bangda'
       'Bangada', 'bangada', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001008);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001008, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001008);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001008, 416520001, 416520001001, 416520001008, 416520001001, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001008);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001008, 416520001008, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001008);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 416520001008, 416520001008, NULL, TRUE, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001008);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001009, 416520001, 416520001001, 16013,  -- canonical 'chicken thali': existing 16013 (unchanged)
       'Chicken Thali', 'chicken thali', 'Fish Thali / Fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001009);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001009, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001009);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001009, 416520001, 416520001001, 416520001009, 416520001001, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001009);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001009, 416520001009, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001009);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001009, 416520001009, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001009);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001010, 416520001, 416520001001, 60154,  -- canonical 'veg thali': existing 60154 (unchanged)
       'Veg Thali', 'veg thali', 'Fish Thali / Fry', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001010);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001010, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001010);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001010, 416520001, 416520001001, 416520001010, 416520001001, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001010);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001010, 416520001010, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001010);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001010, 416520001010, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001010);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001011, 416520001, 416520001002, 13495,  -- canonical 'manchow soup': existing 13495 (unchanged)
       'Manchow Soup', 'manchow soup', 'Soups', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001011);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001011, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001011);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001011, 416520001, 416520001001, 416520001011, 416520001002, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001011);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001011, 416520001011, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001011);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001011, 416520001011, 50.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001011);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001012, 416520001011, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001012);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001012, 416520001012, 70.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001012);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001012, 416520001, 416520001002, 13495,  -- canonical 'manchow soup': existing 13495 (unchanged)
       'Manchow Soup', 'manchow soup', 'Soups', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001012);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001012, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001012);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001012, 416520001, 416520001001, 416520001012, 416520001002, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001012);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001013, 416520001012, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001013);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001013, 416520001013, 60.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001013);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001014, 416520001012, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001014);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001014, 416520001014, 80.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001014);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001013, 416520001, 416520001002, 13865,  -- canonical 'tomato soup': existing 13865 (unchanged)
       'Tomato Soup', 'tomato soup', 'Soups', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001013);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001013, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001013);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001013, 416520001, 416520001001, 416520001013, 416520001002, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001013);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001015, 416520001013, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001015);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001015, 416520001015, 60.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001015);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001016, 416520001013, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001016);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001016, 416520001016, 80.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001016);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001014, 416520001, 416520001002, 13207,  -- canonical 'cream of soup': was old-style 416520001013 -> existing 13207 'cream of veg soup'
       'Cream of Soup', 'cream of soup', 'Soups', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001014);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001014, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001014);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001014, 416520001, 416520001001, 416520001014, 416520001002, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001014);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001017, 416520001014, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001017);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001017, 416520001017, 100.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001017);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001015, 416520001, 416520001002, 13207,  -- canonical 'cream of soup': was old-style 416520001013 -> existing 13207 'cream of veg soup'
       'Cream of Soup', 'cream of soup', 'Soups', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001015);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001015, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001015);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001015, 416520001, 416520001001, 416520001015, 416520001002, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001015);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001018, 416520001015, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001018);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001018, 416520001018, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001018);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001016, 416520001, 416520001002, 13189,  -- canonical 'clear soup': existing 13189 (unchanged)
       'Clear Soup', 'clear soup', 'Soups', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001016);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001016, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001016);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001016, 416520001, 416520001001, 416520001016, 416520001002, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001016);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001019, 416520001016, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001019);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001019, 416520001019, 50.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001019);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001020, 416520001016, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001020);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001020, 416520001020, 70.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001020);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001017, 416520001, 416520001002, 13189,  -- canonical 'clear soup': existing 13189 (unchanged)
       'Clear Soup', 'clear soup', 'Soups', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001017);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001017, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001017);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001017, 416520001, 416520001001, 416520001017, 416520001002, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001017);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001021, 416520001017, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001021);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001021, 416520001021, 60.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001021);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001022, 416520001017, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001022);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001022, 416520001022, 80.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001022);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001018, 416520001, 416520001002, 13371,  -- canonical 'hot & sour soup': existing 13371 (unchanged)
       'Hot & Sour Soup', 'hot & sour soup', 'Soups', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001018);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001018, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001018);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001018, 416520001, 416520001001, 416520001018, 416520001002, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001018);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001023, 416520001018, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001023);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001023, 416520001023, 50.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001023);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001024, 416520001018, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001024);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001024, 416520001024, 70.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001024);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001019, 416520001, 416520001002, 13371,  -- canonical 'hot & sour soup': existing 13371 (unchanged)
       'Hot & Sour Soup', 'hot & sour soup', 'Soups', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001019);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001019, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001019);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001019, 416520001, 416520001001, 416520001019, 416520001002, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001019);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001025, 416520001019, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001025);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001025, 416520001025, 80.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001025);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001026, 416520001019, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001026);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001026, 416520001026, 100.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001026);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001020, 416520001, 416520001003, 12113,  -- canonical 'chicken chilli': existing 12113 (unchanged)
       'Chicken Chilli', 'chicken chilli', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001020);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001020, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001020);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001020, 416520001, 416520001001, 416520001020, 416520001003, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001020);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001027, 416520001020, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001027);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001027, 416520001027, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001027);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001021, 416520001, 416520001003, 12123,  -- canonical 'chicken crispy': existing 12123 (unchanged)
       'Chicken Crispy', 'chicken crispy', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001021);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001021, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001021);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001021, 416520001, 416520001001, 416520001021, 416520001003, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001021);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001028, 416520001021, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001028);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001028, 416520001028, 190.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001028);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001022, 416520001, 416520001003, 12071,  -- canonical 'chicken 65': existing 12071 (unchanged)
       'Chicken 65', 'chicken 65', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001022);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001022, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001022);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001022, 416520001, 416520001001, 416520001022, 416520001003, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001022);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001029, 416520001022, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001029);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001029, 416520001029, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001029);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001023, 416520001, 416520001003, 16070,  -- canonical 'chicken stick': was old-style 416520001019 -> existing 16070 'chicken stic'
       'Chicken Stick', 'chicken stick', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001023);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001023, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001023);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001023, 416520001, 416520001001, 416520001023, 416520001003, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001023);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001030, 416520001023, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001030);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001030, 416520001030, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001030);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001024, 416520001, 416520001003, 12087,  -- canonical 'barbeque': was old-style 416520001020 -> existing 12087 'chicken barbeque dry'
       'Barbeque', 'barbeque', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001024);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001024, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001024);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001024, 416520001, 416520001001, 416520001024, 416520001003, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001024);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001031, 416520001024, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001031);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001031, 416520001031, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001031);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001025, 416520001, 416520001003, 12165,  -- canonical 'chicken lollipop': existing 12165 (unchanged)
       'Chicken Lollipop', 'chicken lollipop', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001025);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001025, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001025);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001025, 416520001, 416520001001, 416520001025, 416520001003, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001025);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001032, 416520001025, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001032);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001032, 416520001032, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001032);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001026, 416520001, 416520001003, 12170,  -- canonical 'chicken lollipop masala': was old-style 416520001022 -> existing 12170 'chicken lollypop masala'
       'Chicken Lollipop Masala', 'chicken lollipop masala', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001026);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001026, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001026);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001026, 416520001, 416520001001, 416520001026, 416520001003, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001026);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001033, 416520001026, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001033);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001033, 416520001033, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001033);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001027, 416520001, 416520001003, 16453,  -- canonical 'dragon chicken': existing 16453 (unchanged)
       'Dragon Chicken', 'dragon chicken', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001027);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001027, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001027);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001027, 416520001, 416520001001, 416520001027, 416520001003, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001027);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001034, 416520001027, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001034);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001034, 416520001034, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001034);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001028, 416520001, 416520001003, 12524,  -- canonical 'hot & sweet': was old-style 416520001024 -> NEW 12524 'Chicken Hot & Sweet'
       'Hot & Sweet', 'hot & sweet', 'Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001028);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001028, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001028);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001028, 416520001, 416520001001, 416520001028, 416520001003, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001028);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001035, 416520001028, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001035);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001035, 416520001035, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001035);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001029, 416520001, 416520001004, 10555,  -- canonical 'paneer chilli': existing 10555 (unchanged)
       'Paneer Chilli', 'paneer chilli', 'Veg Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001029);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001029, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001029);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001029, 416520001, 416520001001, 416520001029, 416520001004, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001029);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001036, 416520001029, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001036);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001036, 416520001036, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001036);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001030, 416520001, 416520001004, 10296,  -- canonical 'gobi manchurian': existing 10296 (unchanged)
       'Gobi Manchurian', 'gobi manchurian', 'Veg Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001030);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001030, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001030);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001030, 416520001, 416520001001, 416520001030, 416520001004, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001030);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001037, 416520001030, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001037);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001037, 416520001037, 140.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001037);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001031, 416520001, 416520001004, 10474,  -- canonical 'mushroom chilli': existing 10474 (unchanged)
       'Mushroom Chilli', 'mushroom chilli', 'Veg Starter', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001031);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001031, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001031);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001031, 416520001, 416520001001, 416520001031, 416520001004, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001031);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001038, 416520001031, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001038);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001038, 416520001038, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001038);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001032, 416520001, 416520001004, 10044,  -- canonical 'baby corn chilli': was old-style 416520001028 -> existing 10044 'baby corn chilly'
       'Baby Corn Chilli', 'baby corn chilli', 'Veg Starter', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001032);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001032, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001032);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001032, 416520001, 416520001001, 416520001032, 416520001004, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001032);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001039, 416520001032, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001039);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001039, 416520001039, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001039);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001033, 416520001, 416520001004, 10253,  -- canonical 'finger chips': existing 10253 (unchanged)
       'Finger Chips', 'finger chips', 'Veg Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001033);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001033, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001033);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001033, 416520001, 416520001001, 416520001033, 416520001004, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001033);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001040, 416520001033, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001040);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001040, 416520001040, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001040);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001034, 416520001, 416520001004, 60166,  -- canonical 'dragon veg': was old-style 416520001030 -> existing 60166 'veg. dragon'
       'Dragon Veg', 'dragon veg', 'Veg Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001034);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001034, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001034);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001034, 416520001, 416520001001, 416520001034, 416520001004, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001034);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001041, 416520001034, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001041);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001041, 416520001041, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001041);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001035, 416520001, 416520001004, 10871,  -- canonical 'veg crispy': was old-style 416520001031 -> existing 10871 'veg. crispy'
       'Veg Crispy', 'veg crispy', 'Veg Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001035);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001035, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001035);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001035, 416520001, 416520001001, 416520001035, 416520001004, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001035);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001042, 416520001035, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001042);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001042, 416520001042, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001042);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001036, 416520001, 416520001005, 13309,  -- canonical 'fried rice': existing 13309 (unchanged)
       'Fried Rice', 'fried rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001036);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001036, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001036);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001036, 416520001, 416520001001, 416520001036, 416520001005, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001036);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001043, 416520001036, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001043);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001043, 416520001043, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001043);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001037, 416520001, 416520001005, 13309,  -- canonical 'fried rice': existing 13309 (unchanged)
       'Fried Rice', 'fried rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001037);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001037, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001037);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001037, 416520001, 416520001001, 416520001037, 416520001005, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001037);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001044, 416520001037, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001044);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001044, 416520001044, 150.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001044);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001038, 416520001, 416520001005, 13352,  -- canonical 'hakka noodles': existing 13352 (unchanged)
       'Hakka Noodles', 'hakka noodles', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001038);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001038, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001038);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001038, 416520001, 416520001001, 416520001038, 416520001005, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001038);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001045, 416520001038, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001045);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001045, 416520001045, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001045);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001039, 416520001, 416520001005, 13352,  -- canonical 'hakka noodles': existing 13352 (unchanged)
       'Hakka Noodles', 'hakka noodles', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001039);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001039, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001039);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001039, 416520001, 416520001001, 416520001039, 416520001005, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001039);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001046, 416520001039, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001046);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001046, 416520001046, 140.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001046);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001040, 416520001, 416520001005, 13744,  -- canonical 'shezwan fried rice': was old-style 416520001034 -> existing 13744 'schezwan fried rice'
       'Shezwan Fried Rice', 'shezwan fried rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001040);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001040, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001040);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001040, 416520001, 416520001001, 416520001040, 416520001005, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001040);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001047, 416520001040, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001047);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001047, 416520001047, 130.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001047);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001041, 416520001, 416520001005, 13744,  -- canonical 'shezwan fried rice': was old-style 416520001034 -> existing 13744 'schezwan fried rice'
       'Shezwan Fried Rice', 'shezwan fried rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001041);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001041, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001041);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001041, 416520001, 416520001001, 416520001041, 416520001005, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001041);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001048, 416520001041, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001048);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001048, 416520001048, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001048);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001042, 416520001, 416520001005, 60508,  -- canonical 'sandwich rice': was old-style 416520001035 -> NEW 60508 'Sandwich Rice'
       'Sandwich Rice', 'sandwich rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001042);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001042, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001042);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001042, 416520001, 416520001001, 416520001042, 416520001005, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001042);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001049, 416520001042, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001049);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001049, 416520001049, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001049);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001043, 416520001, 416520001005, 60508,  -- canonical 'sandwich rice': was old-style 416520001035 -> NEW 60508 'Sandwich Rice'
       'Sandwich Rice', 'sandwich rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001043);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001043, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001043);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001043, 416520001, 416520001001, 416520001043, 416520001005, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001043);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001050, 416520001043, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001050);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001050, 416520001050, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001050);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001044, 416520001, 416520001005, 13644,  -- canonical 'packing rice': existing 13644 (unchanged)
       'Packing Rice', 'packing rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001044);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001044, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001044);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001044, 416520001, 416520001001, 416520001044, 416520001005, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001044);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001051, 416520001044, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001051);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001051, 416520001051, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001051);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001045, 416520001, 416520001005, 60509,  -- canonical 'pizza rice': was old-style 416520001037 -> NEW 60509 'Pizza Rice'
       'Pizza Rice', 'pizza rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001045);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001045, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001045);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001045, 416520001, 416520001001, 416520001045, 416520001005, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001045);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001052, 416520001045, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001052);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001052, 416520001052, 240.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001052);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001046, 416520001, 416520001005, 60509,  -- canonical 'pizza rice': was old-style 416520001037 -> NEW 60509 'Pizza Rice'
       'Pizza Rice', 'pizza rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001046);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001046, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001046);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001046, 416520001, 416520001001, 416520001046, 416520001005, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001046);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001053, 416520001046, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001053);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001053, 416520001053, 260.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001053);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001047, 416520001, 416520001005, 60262,  -- canonical 'singapore rice': was old-style 416520001038 -> existing 60262 'veg. singapore rice'
       'Singapore Rice', 'singapore rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001047);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001047, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001047);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001047, 416520001, 416520001001, 416520001047, 416520001005, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001047);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001054, 416520001047, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001054);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001054, 416520001054, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001054);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001048, 416520001, 416520001005, 60262,  -- canonical 'singapore rice': was old-style 416520001038 -> existing 60262 'veg. singapore rice'
       'Singapore Rice', 'singapore rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001048);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001048, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001048);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001048, 416520001, 416520001001, 416520001048, 416520001005, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001048);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001055, 416520001048, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001055);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001055, 416520001055, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001055);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001049, 416520001, 416520001005, 13367,  -- canonical 'hongkong rice': was old-style 416520001039 -> existing 13367 'hong kong rice'
       'Hongkong Rice', 'hongkong rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001049);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001049, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001049);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001049, 416520001, 416520001001, 416520001049, 416520001005, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001049);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001056, 416520001049, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001056);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001056, 416520001056, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001056);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001050, 416520001, 416520001005, 13367,  -- canonical 'hongkong rice': was old-style 416520001039 -> existing 13367 'hong kong rice'
       'Hongkong Rice', 'hongkong rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001050);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001050, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001050);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001050, 416520001, 416520001001, 416520001050, 416520001005, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001050);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001057, 416520001050, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001057);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001057, 416520001057, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001057);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001051, 416520001, 416520001005, 13869,  -- canonical 'triple rice': existing 13869 (unchanged)
       'Triple Rice', 'triple rice', 'Rice & Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001051);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001051, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001051);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001051, 416520001, 416520001001, 416520001051, 416520001005, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001051);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001058, 416520001051, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001058);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001058, 416520001058, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001058);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001052, 416520001, 416520001005, 13869,  -- canonical 'triple rice': existing 13869 (unchanged)
       'Triple Rice', 'triple rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001052);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001052, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001052);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001052, 416520001, 416520001001, 416520001052, 416520001005, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001052);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001059, 416520001052, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001059);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001059, 416520001059, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001059);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001053, 416520001, 416520001005, 12363,  -- canonical 'kabsa rice tandoori': was old-style 416520001041 -> existing 12363 'murg tandoori kabsa'
       'Kabsa Rice Tandoori', 'kabsa rice tandoori', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001053);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001053, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001053);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001053, 416520001, 416520001001, 416520001053, 416520001005, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001053);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001060, 416520001053, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001060);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001060, 416520001060, 800.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001060);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001054, 416520001, 416520001005, 16520,  -- canonical 'misba kabsa rice': was old-style 416520001042 -> NEW 16520 'Misba Kabsa Rice'
       'Misba Kabsa Rice', 'misba kabsa rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001054);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001054, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001054);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001054, 416520001, 416520001001, 416520001054, 416520001005, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001054);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001061, 416520001054, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001061);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001061, 416520001061, 900.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001061);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001055, 416520001, 416520001005, 16521,  -- canonical 'lollipop kabsa rice': was old-style 416520001043 -> NEW 16521 'Lollipop Kabsa Rice'
       'Lollipop Kabsa Rice', 'lollipop kabsa rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001055);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001055, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001055);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001055, 416520001, 416520001001, 416520001055, 416520001005, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001055);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001062, 416520001055, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001062);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001062, 416520001062, 600.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001062);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001056, 416520001, 416520001005, 13167,  -- canonical 'chilly rice': existing 13167 (unchanged)
       'Chilly Rice', 'chilly rice', 'Rice & Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001056);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001056, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001056);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001056, 416520001, 416520001001, 416520001056, 416520001005, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001056);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001063, 416520001056, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001063);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001063, 416520001063, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001063);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001057, 416520001, 416520001006, 60180,  -- canonical 'veg handi': was old-style 416520001045 -> existing 60180 'veg. handi'
       'Veg Handi', 'veg handi', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001057);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001057, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001057);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001057, 416520001, 416520001001, 416520001057, 416520001006, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001057);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001064, 416520001057, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001064);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001064, 416520001064, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001064);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001058, 416520001, 416520001006, 60208,  -- canonical 'veg kolhapuri': was old-style 416520001046 -> existing 60208 'veg. kolhapuri'
       'Veg Kolhapuri', 'veg kolhapuri', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001058);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001058, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001058);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001058, 416520001, 416520001001, 416520001058, 416520001006, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001058);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001065, 416520001058, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001065);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001065, 416520001065, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001065);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001059, 416520001, 416520001006, 60198,  -- canonical 'veg kadhai': was old-style 416520001047 -> existing 60198 'veg. kadai'
       'Veg Kadhai', 'veg kadhai', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001059);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001059, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001059);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001059, 416520001, 416520001001, 416520001059, 416520001006, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001059);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001066, 416520001059, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001066);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001066, 416520001066, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001066);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001060, 416520001, 416520001006, 14204,  -- canonical 'paneer tikka masala': existing 14204 (unchanged)
       'Paneer Tikka Masala', 'paneer tikka masala', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001060);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001060, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001060);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001060, 416520001, 416520001001, 416520001060, 416520001006, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001060);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001067, 416520001060, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001067);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001067, 416520001067, 240.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001067);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001061, 416520001, 416520001006, 13017,  -- canonical 'aloo matar': was old-style 416520001049 -> existing 13017 'aloo mutter'
       'Aloo Matar', 'aloo matar', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001061);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001061, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001061);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001061, 416520001, 416520001001, 416520001061, 416520001006, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001061);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001068, 416520001061, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001068);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001068, 416520001068, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001068);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001062, 416520001, 416520001006, 14151,  -- canonical 'paneer matar': was old-style 416520001050 -> existing 14151 'paneer mutter'
       'Paneer Matar', 'paneer matar', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001062);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001062, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001062);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001062, 416520001, 416520001001, 416520001062, 416520001006, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001062);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001069, 416520001062, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001069);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001069, 416520001069, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001069);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001063, 416520001, 416520001006, 13552,  -- canonical 'mix veg': existing 13552 (unchanged)
       'Mix Veg', 'mix veg', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001063);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001063, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001063);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001063, 416520001, 416520001001, 416520001063, 416520001006, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001063);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001070, 416520001063, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001070);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001070, 416520001070, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001070);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001064, 416520001, 416520001006, 13409,  -- canonical 'kaju masala': existing 13409 (unchanged)
       'Kaju Masala', 'kaju masala', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001064);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001064, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001064);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001064, 416520001, 416520001001, 416520001064, 416520001006, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001064);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001071, 416520001064, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001071);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001071, 416520001071, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001071);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001065, 416520001, 416520001006, 13235,  -- canonical 'dal fry': existing 13235 (unchanged)
       'Dal Fry', 'dal fry', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001065);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001065, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001065);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001065, 416520001, 416520001001, 416520001065, 416520001006, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001065);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001072, 416520001065, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001072);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001072, 416520001072, 160.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001072);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001066, 416520001, 416520001006, 13254,  -- canonical 'dal tadka': existing 13254 (unchanged)
       'Dal Tadka', 'dal tadka', 'Indian Main Course (Veg)', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001066);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001066, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001066);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001066, 416520001, 416520001001, 416520001066, 416520001006, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001066);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001073, 416520001066, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001073);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001073, 416520001073, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001073);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001067, 416520001, 416520001006, 13592,  -- canonical 'mushroom masala': existing 13592 (unchanged)
       'Mushroom Masala', 'mushroom masala', 'Indian Main Course (Veg)', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001067);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001067, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001067);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001067, 416520001, 416520001001, 416520001067, 416520001006, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001067);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001074, 416520001067, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001074);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001074, 416520001074, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001074);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001068, 416520001, 416520001007, 16297,  -- canonical 'chicken masala': existing 16297 (unchanged)
       'Chicken Masala', 'chicken masala', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001068);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001068, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001068);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001068, 416520001, 416520001001, 416520001068, 416520001007, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001068);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001075, 416520001068, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001075);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001075, 416520001075, 240.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001075);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001069, 416520001, 416520001007, 16194,  -- canonical 'chicken handi': existing 16194 (unchanged)
       'Chicken Handi', 'chicken handi', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001069);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001069, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001069);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001069, 416520001, 416520001001, 416520001069, 416520001007, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001069);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001076, 416520001069, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001076);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001076, 416520001076, 240.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001076);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001070, 416520001, 416520001007, 16224,  -- canonical 'chicken kadhai': was old-style 416520001058 -> existing 16224 'chicken kadai'
       'Chicken Kadhai', 'chicken kadhai', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001070);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001070, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001070);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001070, 416520001, 416520001001, 416520001070, 416520001007, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001070);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001077, 416520001070, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001077);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001077, 416520001077, 240.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001077);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001071, 416520001, 416520001007, 16002,  -- canonical 'butter chicken': existing 16002 (unchanged)
       'Butter Chicken', 'butter chicken', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001071);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001071, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001071);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001071, 416520001, 416520001001, 416520001071, 416520001007, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001071);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001078, 416520001071, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001078);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001078, 416520001078, 280.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001078);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001072, 416520001, 416520001007, 16238,  -- canonical 'chicken kolhapuri': existing 16238 (unchanged)
       'Chicken Kolhapuri', 'chicken kolhapuri', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001072);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001072, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001072);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001072, 416520001, 416520001001, 416520001072, 416520001007, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001072);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001079, 416520001072, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001079);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001079, 416520001079, 260.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001079);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001073, 416520001, 416520001007, 16426,  -- canonical 'chicken tikka masala': existing 16426 (unchanged)
       'Chicken Tikka Masala', 'chicken tikka masala', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001073);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001073, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001073);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001073, 416520001, 416520001001, 416520001073, 416520001007, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001073);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001080, 416520001073, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001080);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001080, 416520001080, 260.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001080);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001074, 416520001, 416520001007, 16478,  -- canonical 'murgh musallam': was old-style 416520001062 -> existing 16478 'murg musallam'
       'Murgh Musallam', 'murgh musallam', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001074);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001074, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001074);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001074, 416520001, 416520001001, 416520001074, 416520001007, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001074);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001081, 416520001074, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001081);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001081, 416520001081, 480.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001081);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001075, 416520001, 416520001007, 16342,  -- canonical 'chicken patiala': existing 16342 (unchanged)
       'Chicken Patiala', 'chicken patiala', 'Indian Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001075);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001075, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001075);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001075, 416520001, 416520001001, 416520001075, 416520001007, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001075);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001082, 416520001075, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001082);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001082, 416520001082, 250.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001082);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001076, 416520001, 416520001008, 13977,  -- canonical 'veg biryani': was old-style 416520001064 -> existing 13977 'veg. biryani'
       'Veg Biryani', 'veg biryani', 'Biryani', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001076);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001076, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001076);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001076, 416520001, 416520001001, 416520001076, 416520001008, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001076);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001083, 416520001076, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001083);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001083, 416520001083, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001083);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001077, 416520001, 416520001008, 16110,  -- canonical 'chicken biryani': existing 16110 (unchanged)
       'Chicken Biryani', 'chicken biryani', 'Biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001077);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001077, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001077);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001077, 416520001, 416520001001, 416520001077, 416520001008, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001077);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001084, 416520001077, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001084);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001084, 416520001084, 150.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001084);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001085, 416520001077, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001085);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001085, 416520001085, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001085);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001078, 416520001, 416520001008, 18065,  -- canonical 'mutton biryani': existing 18065 (unchanged)
       'Mutton Biryani', 'mutton biryani', 'Biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001078);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001078, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001078);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001078, 416520001, 416520001001, 416520001078, 416520001008, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001078);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001086, 416520001078, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001086);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001086, 416520001086, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001086);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001087, 416520001078, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001087);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001087, 416520001087, 260.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001087);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001079, 416520001, 416520001008, 13395,  -- canonical 'jeera rice': existing 13395 (unchanged)
       'Jeera Rice', 'jeera rice', 'Biryani', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001079);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001079, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001079);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001079, 416520001, 416520001001, 416520001079, 416520001008, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001079);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001088, 416520001079, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001088);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001088, 416520001088, 140.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001088);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001080, 416520001, 416520001008, 13793,  -- canonical 'steam rice': existing 13793 (unchanged)
       'Steam Rice', 'steam rice', 'Biryani', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001080);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001080, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001080);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001080, 416520001, 416520001001, 416520001080, 416520001008, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001080);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001089, 416520001080, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001089);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001089, 416520001089, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001089);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001081, 416520001, 416520001009, 18134,  -- canonical 'mutton masala': existing 18134 (unchanged)
       'Mutton Masala', 'mutton masala', 'Mutton', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001081);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001081, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001081);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001081, 416520001, 416520001001, 416520001081, 416520001009, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001081);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001090, 416520001081, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001090);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001090, 416520001090, 290.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001090);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001082, 416520001, 416520001009, 18101,  -- canonical 'mutton kadhai': was old-style 416520001070 -> existing 18101 'mutton kadai'
       'Mutton Kadhai', 'mutton kadhai', 'Mutton', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001082);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001082, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001082);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001082, 416520001, 416520001001, 416520001082, 416520001009, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001082);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001091, 416520001082, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001091);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001091, 416520001091, 290.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001091);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001083, 416520001, 416520001009, 18132,  -- canonical 'mutton malvani': existing 18132 (unchanged)
       'Mutton Malvani', 'mutton malvani', 'Mutton', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001083);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001083, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001083);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001083, 416520001, 416520001001, 416520001083, 416520001009, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001083);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001092, 416520001083, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001092);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001092, 416520001092, 280.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001092);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001084, 416520001, 416520001009, 18063,  -- canonical 'mutton bhuna': existing 18063 (unchanged)
       'Mutton Bhuna', 'mutton bhuna', 'Mutton', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001084);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001084, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001084);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001084, 416520001, 416520001001, 416520001084, 416520001009, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001084);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001093, 416520001084, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001093);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001093, 416520001093, 320.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001093);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001085, 416520001, 416520001010, 23094,  -- canonical 'roti': existing 23094 (unchanged)
       'Roti', 'roti', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001085);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001085, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001085);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001085, 416520001, 416520001001, 416520001085, 416520001010, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001085);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001094, 416520001085, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001094);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001094, 416520001094, 20.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001094);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001086, 416520001, 416520001010, 23080,  -- canonical 'naan': existing 23080 (unchanged)
       'Naan', 'naan', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001086);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001086, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001086);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001086, 416520001, 416520001001, 416520001086, 416520001010, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001086);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001095, 416520001086, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001095);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001095, 416520001095, 40.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001095);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001087, 416520001, 416520001010, 23020,  -- canonical 'butter naan': existing 23020 (unchanged)
       'Butter Naan', 'butter naan', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001087);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001087, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001087);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001087, 416520001, 416520001001, 416520001087, 416520001010, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001087);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001096, 416520001087, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001096);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001096, 416520001096, 60.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001096);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001088, 416520001, 416520001010, 23061,  -- canonical 'kulcha': existing 23061 (unchanged)
       'Kulcha', 'kulcha', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001088);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001088, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001088);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001088, 416520001, 416520001001, 416520001088, 416520001010, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001088);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001097, 416520001088, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001097);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001097, 416520001097, 60.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001097);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001089, 416520001, 416520001010, 23085,  -- canonical 'paratha': existing 23085 (unchanged)
       'Paratha', 'paratha', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001089);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001089, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001089);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001089, 416520001, 416520001001, 416520001089, 416520001010, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001089);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001098, 416520001089, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001098);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001098, 416520001098, 80.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001098);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001090, 416520001, 416520001010, 23052,  -- canonical 'garlic naan': existing 23052 (unchanged)
       'Garlic Naan', 'garlic naan', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001090);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001090, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001090);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001090, 416520001, 416520001001, 416520001090, 416520001010, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001090);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001099, 416520001090, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001099);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001099, 416520001099, 120.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001099);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001091, 416520001, 416520001010, 13071,  -- canonical 'bhakari': was old-style 416520001079 -> existing 13071 'bhakri'
       'Bhakari', 'bhakari', 'Tandoori', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001091);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001091, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001091);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001091, 416520001, 416520001001, 416520001091, 416520001010, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001091);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001100, 416520001091, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001100);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001100, 416520001100, 20.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001100);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001092, 416520001, 416520001011, 12512,  -- canonical 'tandoori chicken': existing 12512 (unchanged)
       'Tandoori Chicken', 'tandoori chicken', 'Kabab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001092);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001092, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001092);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001092, 416520001, 416520001001, 416520001092, 416520001011, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001092);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001101, 416520001092, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001101);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001101, 416520001101, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001101);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001102, 416520001092, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001102);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001102, 416520001102, 400.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001102);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001093, 416520001, 416520001011, 12288,  -- canonical 'chicken tikka': existing 12288 (unchanged)
       'Chicken Tikka', 'chicken tikka', 'Kabab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001093);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001093, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001093);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001093, 416520001, 416520001001, 416520001093, 416520001011, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001093);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001103, 416520001093, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001103);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001103, 416520001103, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001103);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001094, 416520001, 416520001011, 10753,  -- canonical 'seekh kebab': existing 10753 (unchanged)
       'Seekh Kebab', 'seekh kebab', 'Kabab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001094);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001094, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001094);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001094, 416520001, 416520001001, 416520001094, 416520001011, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001094);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001104, 416520001094, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001104);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001104, 416520001104, 240.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001104);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001095, 416520001, 416520001011, 10053,  -- canonical 'banjara kebab': existing 10053 (unchanged)
       'Banjara Kebab', 'banjara kebab', 'Kabab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001095);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001095, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001095);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001095, 416520001, 416520001001, 416520001095, 416520001011, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001095);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001105, 416520001095, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001105);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001105, 416520001105, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001105);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001096, 416520001, 416520001011, 10405,  -- canonical 'malai kebab': existing 10405 (unchanged)
       'Malai Kebab', 'malai kebab', 'Kabab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001096);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001096, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001096);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001096, 416520001, 416520001001, 416520001096, 416520001011, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001096);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001106, 416520001096, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001106);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001106, 416520001106, 260.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001106);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001097, 416520001, 416520001011, 10538,  -- canonical 'pahadi kebab': existing 10538 (unchanged)
       'Pahadi Kebab', 'pahadi kebab', 'Kabab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001097);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001097, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001097);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001097, 416520001, 416520001001, 416520001097, 416520001011, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001097);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001107, 416520001097, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001107);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001107, 416520001107, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001107);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001098, 416520001, 416520001011, 10310,  -- canonical 'harabhara kebab veg': was old-style 416520001086 -> existing 10310 'hara bhara kabab'
       'Harabhara Kebab Veg', 'harabhara kebab veg', 'Kabab', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001098);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001098, 416520001, 416520001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001098);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001098, 416520001, 416520001001, 416520001098, 416520001011, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001098);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001108, 416520001098, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001108);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001108, 416520001108, 180.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001108);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001099, 416520001, 416520001011, 10490,  -- canonical 'mushroom tikka': existing 10490 (unchanged)
       'Mushroom Tikka', 'mushroom tikka', 'Kabab', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001099);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001099, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001099);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001099, 416520001, 416520001001, 416520001099, 416520001011, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001099);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001109, 416520001099, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001109);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001109, 416520001109, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001109);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001100, 416520001, 416520001011, 10631,  -- canonical 'paneer tikka': existing 10631 (unchanged)
       'Paneer Tikka', 'paneer tikka', 'Kabab', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001100);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001100, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001100);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001100, 416520001, 416520001001, 416520001100, 416520001011, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001100);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001110, 416520001100, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001110);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001110, 416520001110, 220.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001110);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 416520001101, 416520001, 416520001011, 10938,  -- canonical 'baby corn kebab': was old-style 416520001089 -> NEW 10938 'Baby Corn Kebab'
       'Baby Corn Kebab', 'baby corn kebab', 'Kabab', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 416520001101);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 416520001101, 416520001, 416520001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 416520001101);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 416520001101, 416520001, 416520001001, 416520001101, 416520001011, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 416520001101);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 416520001111, 416520001101, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 416520001111);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 416520001111, 416520001111, 200.00, 416520001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 416520001111);

ROLLBACK;

SELECT
    (SELECT COUNT(*) FROM menu_category WHERE restaurant_id = 416520001) AS categories,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 416520001) AS items,
    (SELECT COUNT(*) FROM menu_item_variant miv JOIN menu_item mi ON mi.menu_item_id=miv.menu_item_id WHERE mi.restaurant_id=416520001) AS variants,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id=416520001 AND verification_status_code='needs_review') AS flagged_for_review,
    (SELECT COUNT(*) FROM menu_item_availability mia JOIN menu_item mi ON mi.menu_item_id=mia.menu_item_id WHERE mi.restaurant_id=416520001) AS availability_rows;