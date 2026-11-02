-- ============================================================================
-- SMOKERY -- MENU INSERT SCRIPT (PostgreSQL)
-- Generated directly from Smokery_Restaurant_Menu_Transcription.docx against
-- khaustan-full-platform-postgresql.sql, following the schema-resolved docx->
-- Postgres extraction methodology.
-- 239 distinct dishes -> 335 menu_item rows (50 dishes
-- split across multiple protein options via split_group_key) -> 343 variants,
-- across 26 real menu_category rows.
--
-- ID convention (per explicit request, supersedes the shared-sequence approach used
-- for the previous restaurant): establishment_id = restaurant_id = 400070006.
-- Every other table this script inserts into gets its OWN independent counter,
-- starting at 400070006001 (<restaurant_id> + '001') and incrementing by 1 per row within
-- that table -- so menu_category, menu_item, menu_item_variant, menu_item_price,
-- menu_board_item, canonical_dish, canonical_dish_name, restaurant_phone, and
-- restaurant_tag each independently start at 400070006001. No menu_item_availability rows
-- are needed on this menu (no day/time-restricted items found), so that counter is
-- unused. menu_item_source has no id of its own -- its (menu_item_id, source_id) key
-- naturally reuses each row's own menu_item_id. menu_board_category has no id column
-- either (its key is restaurant_id + menu_board_id + menu_category_id).
--
-- Modeling notes (unchanged from the previous version of this file):
-- * Menu categories are now REAL menu_category rows (not deferred raw_category_text) --
--   26 categories, one per section header actually printed on the menu. The 'SMOKERY --
--   SOURCE IMAGE nn' page-top marker in the source document is a scan-batch label, not a
--   menu section, and was never treated as one; raw_category_text still holds the real
--   section header verbatim as well, so both the curated link and the source text exist.
-- * VEG./CHICKEN/SEAFOOD/MUTTON table columns are a PROTEIN SPLIT (separate menu_item
--   rows sharing one split_group_key and canonical_dish), not a portion-size variant --
--   confirmed via split_group_key on the delivered file's dishes like Korean Pot.
-- * 'Anda Curry' is priced under this menu's 'CHI.' column but 'Anda' is Hindi for egg --
--   classified food_classification_code='egg', protein_type_id NULL, overriding the
--   column header.
-- * "All prices exclusive of Govt. Taxes" is stated explicitly -- tax_inclusion_code =
--   'exclusive' is set on every price row.
-- * 'HALAL' and 'No Colour No Ajinomoto' are restaurant-level claims -> restaurant_tag
--   rows ('halal' reused from Cafe Sahil, 'no_msg' newly created), not per-item tags.
--
-- 26 items flagged verification_status_code = 'needs_review' -- see each
-- item's own comment for the specific reason.
-- ============================================================================

--\connect "KhaustanRestaurantMenu"

BEGIN;

DO $$
DECLARE
    v_protein_chicken  BIGINT;
    v_protein_mutton   BIGINT;
    v_protein_seafood  BIGINT;
    v_tag_halal        BIGINT;
    v_tag_no_msg       BIGINT;
BEGIN
    IF EXISTS (SELECT 1 FROM restaurant WHERE normalized_name = 'smokery') THEN
        RAISE NOTICE 'Smokery already exists -- nothing inserted. Delete the existing rows first if you want to reload.';
        RETURN;
    END IF;

    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2,
                                locality, city, state, postal_code, country_code, latitude, longitude, status_code)
    VALUES (400070006, 'Smokery', 'smokery', 'Aero View Housing Society, Shop No. 1, Ground Floor', 'Near Sahara Hotel',
            'Kurla (West)', 'Mumbai', 'Maharashtra', '400070', 'IN', 19.079495450087073, 72.87998937090535, 'active');

    INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name,
                             veg_nonveg_status, has_bar, status_code, verification_status_code)
    VALUES (400070006, 400070006, 'Smokery', 'smokery',
            'veg_and_nonveg', FALSE, 'active', 'needs_review');

    INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary, is_personal_number)
    VALUES
        (400070006001, 400070006, '8369564201', TRUE, FALSE),  -- Home Delivery 1
        (400070006002, 400070006, '8433785836', FALSE, FALSE);  -- Home Delivery 2

    INSERT INTO source_record (source_id, source_type_code, source_uri)
    VALUES (400070006, 'ai_menu_extraction', 'Smokery_Restaurant_Menu_Transcription.docx');

    INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
    VALUES (400070006, 400070006, 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

    -- Protein type lookup (idempotent -- shared; already exist from earlier restaurants,
    -- so these IF NOT EXISTS branches don't actually fire here)
    SELECT protein_type_id INTO v_protein_chicken FROM protein_type WHERE code = 'CHICKEN';
    SELECT protein_type_id INTO v_protein_mutton  FROM protein_type WHERE code = 'MUTTON';
    SELECT protein_type_id INTO v_protein_seafood FROM protein_type WHERE code = 'SEAFOOD';

    -- Restaurant-level identity tags: HALAL (existing, restaurant_filter scope) and
    -- No Added MSG/Colour (new, same scope)
    SELECT tag_id INTO v_tag_halal  FROM platform_tag WHERE tag_code = 'HALAL';
    SELECT tag_id INTO v_tag_no_msg FROM platform_tag WHERE tag_code = 'NO_MSG';
    INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
    VALUES
        (400070006001, 400070006, v_tag_halal, TRUE),
        (400070006002, 400070006, v_tag_no_msg, TRUE),
        (400070006003, 400070006, (SELECT tag_id FROM platform_tag WHERE tag_code = 'NO_AJINOMOTO'), TRUE),
        (400070006004, 400070006, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_chinese'), TRUE),
        (400070006005, 400070006, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_tandoori'), TRUE),
        (400070006006, 400070006, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_oriental'), TRUE);

    INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
    VALUES (400070006, 400070006, 'A La Carte', 'a_la_carte');

    -- ----------------------------------------------------------------------
    -- Menu categories (26 real rows, curated from the section headers)
    -- ----------------------------------------------------------------------
    INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
    VALUES
        (400070006001, 400070006, 'Salad / Papad / Raita', 1),
        (400070006002, 400070006, 'Dessert', 2),
        (400070006003, 400070006, 'Beverages', 3),
        (400070006004, 400070006, 'Thai Curries / Chinese Pot', 4),
        (400070006005, 400070006, 'Rice & Noodles', 5),
        (400070006006, 400070006, 'Chinese Starters Non-Veg', 6),
        (400070006007, 400070006, 'Tandoor Lamb Kabab', 7),
        (400070006008, 400070006, 'Chinese Lamb Starters', 8),
        (400070006009, 400070006, 'Seafood Tandoori Starter', 9),
        (400070006010, 400070006, 'Biryani''s & Rice''s', 10),
        (400070006011, 400070006, 'Tandoor Bread', 11),
        (400070006012, 400070006, 'Indian Main Course', 12),
        (400070006013, 400070006, 'Indian Vegetables Main Course', 13),
        (400070006014, 400070006, 'Chinese Main Course', 14),
        (400070006015, 400070006, 'Seafood Chinese Starters', 15),
        (400070006016, 400070006, 'Goan Main Course', 16),
        (400070006017, 400070006, 'Hyderabadi Main Course', 17),
        (400070006018, 400070006, 'Dal', 18),
        (400070006019, 400070006, 'Indian Shorba', 19),
        (400070006020, 400070006, 'Chinese Soup', 20),
        (400070006021, 400070006, 'Sushi', 21),
        (400070006022, 400070006, 'Dimsum', 22),
        (400070006023, 400070006, 'Ramen Bowl', 23),
        (400070006024, 400070006, 'Tandoor Starter Vegetable', 24),
        (400070006025, 400070006, 'Chinese Starters Vegetable', 25),
        (400070006026, 400070006, 'Tandoor Starter Non-Veg', 26);

    INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
    VALUES
        (400070006, 400070006, 400070006001, 1),
        (400070006, 400070006, 400070006002, 2),
        (400070006, 400070006, 400070006003, 3),
        (400070006, 400070006, 400070006004, 4),
        (400070006, 400070006, 400070006005, 5),
        (400070006, 400070006, 400070006006, 6),
        (400070006, 400070006, 400070006007, 7),
        (400070006, 400070006, 400070006008, 8),
        (400070006, 400070006, 400070006009, 9),
        (400070006, 400070006, 400070006010, 10),
        (400070006, 400070006, 400070006011, 11),
        (400070006, 400070006, 400070006012, 12),
        (400070006, 400070006, 400070006013, 13),
        (400070006, 400070006, 400070006014, 14),
        (400070006, 400070006, 400070006015, 15),
        (400070006, 400070006, 400070006016, 16),
        (400070006, 400070006, 400070006017, 17),
        (400070006, 400070006, 400070006018, 18),
        (400070006, 400070006, 400070006019, 19),
        (400070006, 400070006, 400070006020, 20),
        (400070006, 400070006, 400070006021, 21),
        (400070006, 400070006, 400070006022, 22),
        (400070006, 400070006, 400070006023, 23),
        (400070006, 400070006, 400070006024, 24),
        (400070006, 400070006, 400070006025, 25),
        (400070006, 400070006, 400070006026, 26);

    -- ----------------------------------------------------------------------
    -- Canonical dishes (239 distinct names -- shared/global table, matched by
    -- normalized name; several are expected to already exist from Sahara Hotel, e.g.
    -- Butter Chicken, Dal Fry, Dal Tadka)
    -- ----------------------------------------------------------------------
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006001, 'Green Salad', 'green salad', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006001, canonical_dish_id, 'en', 'Green Salad', 'green salad', 'primary'
    FROM canonical_dish WHERE normalized_name = 'green salad'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'green salad' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006002, 'Mix Raita', 'mix raita', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix raita');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006002, canonical_dish_id, 'en', 'Mix Raita', 'mix raita', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mix raita'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix raita' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006003, 'Pineapple Raita', 'pineapple raita', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple raita');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006003, canonical_dish_id, 'en', 'Pineapple Raita', 'pineapple raita', 'primary'
    FROM canonical_dish WHERE normalized_name = 'pineapple raita'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pineapple raita' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006004, 'Boondi Raita', 'boondi raita', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boondi raita');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006004, canonical_dish_id, 'en', 'Boondi Raita', 'boondi raita', 'primary'
    FROM canonical_dish WHERE normalized_name = 'boondi raita'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'boondi raita' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006005, 'Lassi', 'lassi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lassi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006005, canonical_dish_id, 'en', 'Lassi', 'lassi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'lassi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'lassi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006006, 'Butter Milk', 'butter milk', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter milk');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006006, canonical_dish_id, 'en', 'Butter Milk', 'butter milk', 'primary'
    FROM canonical_dish WHERE normalized_name = 'butter milk'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter milk' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006007, 'Roasted Papad', 'roasted papad', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roasted papad');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006007, canonical_dish_id, 'en', 'Roasted Papad', 'roasted papad', 'primary'
    FROM canonical_dish WHERE normalized_name = 'roasted papad'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'roasted papad' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006008, 'Fry Papad', 'fry papad', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fry papad');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006008, canonical_dish_id, 'en', 'Fry Papad', 'fry papad', 'primary'
    FROM canonical_dish WHERE normalized_name = 'fry papad'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'fry papad' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006009, 'Masala Papad', 'masala papad', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006009, canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary'
    FROM canonical_dish WHERE normalized_name = 'masala papad'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'masala papad' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006010, 'Gulab Jamun', 'gulab jamun', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gulab jamun');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006010, canonical_dish_id, 'en', 'Gulab Jamun', 'gulab jamun', 'primary'
    FROM canonical_dish WHERE normalized_name = 'gulab jamun'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'gulab jamun' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006011, 'Khubani Ka Meetha', 'khubani ka meetha', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'khubani ka meetha');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006011, canonical_dish_id, 'en', 'Khubani Ka Meetha', 'khubani ka meetha', 'primary'
    FROM canonical_dish WHERE normalized_name = 'khubani ka meetha'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'khubani ka meetha' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006012, 'Tub Tim Krob', 'tub tim krob', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tub tim krob');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006012, canonical_dish_id, 'en', 'Tub Tim Krob', 'tub tim krob', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tub tim krob'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tub tim krob' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006013, 'Package Drinking Water', 'package drinking water', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'package drinking water');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006013, canonical_dish_id, 'en', 'Package Drinking Water', 'package drinking water', 'primary'
    FROM canonical_dish WHERE normalized_name = 'package drinking water'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'package drinking water' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006014, 'Soft Drink', 'soft drink', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soft drink');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006014, canonical_dish_id, 'en', 'Soft Drink', 'soft drink', 'primary'
    FROM canonical_dish WHERE normalized_name = 'soft drink'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'soft drink' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006015, 'Korean Pot', 'korean pot', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean pot');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006015, canonical_dish_id, 'en', 'Korean Pot', 'korean pot', 'primary'
    FROM canonical_dish WHERE normalized_name = 'korean pot'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'korean pot' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006016, 'Oyster Chilli Pot', 'oyster chilli pot', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'oyster chilli pot');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006016, canonical_dish_id, 'en', 'Oyster Chilli Pot', 'oyster chilli pot', 'primary'
    FROM canonical_dish WHERE normalized_name = 'oyster chilli pot'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'oyster chilli pot' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006017, 'Sapo Pot', 'sapo pot', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sapo pot');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006017, canonical_dish_id, 'en', 'Sapo Pot', 'sapo pot', 'primary'
    FROM canonical_dish WHERE normalized_name = 'sapo pot'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sapo pot' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006018, 'Caramel Chilli Pot', 'caramel chilli pot', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'caramel chilli pot');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006018, canonical_dish_id, 'en', 'Caramel Chilli Pot', 'caramel chilli pot', 'primary'
    FROM canonical_dish WHERE normalized_name = 'caramel chilli pot'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'caramel chilli pot' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006019, 'Hot Basil Pot', 'hot basil pot', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot basil pot');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006019, canonical_dish_id, 'en', 'Hot Basil Pot', 'hot basil pot', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hot basil pot'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hot basil pot' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006020, 'Thai Green Curry', 'thai green curry', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai green curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006020, canonical_dish_id, 'en', 'Thai Green Curry', 'thai green curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'thai green curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'thai green curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006021, 'Thai Red Curry', 'thai red curry', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai red curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006021, canonical_dish_id, 'en', 'Thai Red Curry', 'thai red curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'thai red curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'thai red curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006022, 'Singapuri Curry', 'singapuri curry', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapuri curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006022, canonical_dish_id, 'en', 'Singapuri Curry', 'singapuri curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'singapuri curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'singapuri curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006023, 'Khao Suey Curry', 'khao suey curry', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'khao suey curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006023, canonical_dish_id, 'en', 'Khao Suey Curry', 'khao suey curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'khao suey curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'khao suey curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006024, 'Smokery Burma Rice', 'smokery burma rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'smokery burma rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006024, canonical_dish_id, 'en', 'Smokery Burma Rice', 'smokery burma rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'smokery burma rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'smokery burma rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006025, 'Nasi Goreng', 'nasi goreng', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nasi goreng');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006025, canonical_dish_id, 'en', 'Nasi Goreng', 'nasi goreng', 'primary'
    FROM canonical_dish WHERE normalized_name = 'nasi goreng'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'nasi goreng' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006026, 'Singapore Fried Rice', 'singapore fried rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore fried rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006026, canonical_dish_id, 'en', 'Singapore Fried Rice', 'singapore fried rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'singapore fried rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'singapore fried rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006027, 'Chilli Garlic Fried Rice', 'chilli garlic fried rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli garlic fried rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006027, canonical_dish_id, 'en', 'Chilli Garlic Fried Rice', 'chilli garlic fried rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli garlic fried rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli garlic fried rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006028, 'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'burnt garlic fried rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006028, canonical_dish_id, 'en', 'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'burnt garlic fried rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'burnt garlic fried rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006029, 'Schezwan Fried Rice', 'schezwan fried rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan fried rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006029, canonical_dish_id, 'en', 'Schezwan Fried Rice', 'schezwan fried rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'schezwan fried rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'schezwan fried rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006030, 'Classic Fried Rice', 'classic fried rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'classic fried rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006030, canonical_dish_id, 'en', 'Classic Fried Rice', 'classic fried rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'classic fried rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'classic fried rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006031, 'Pad Thai Noodles', 'pad thai noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pad thai noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006031, canonical_dish_id, 'en', 'Pad Thai Noodles', 'pad thai noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'pad thai noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pad thai noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006032, 'Singapore Noodles', 'singapore noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006032, canonical_dish_id, 'en', 'Singapore Noodles', 'singapore noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'singapore noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'singapore noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006033, 'Drunken Noodles', 'drunken noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'drunken noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006033, canonical_dish_id, 'en', 'Drunken Noodles', 'drunken noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'drunken noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'drunken noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006034, 'Chilli Garlic Noodles', 'chilli garlic noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli garlic noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006034, canonical_dish_id, 'en', 'Chilli Garlic Noodles', 'chilli garlic noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli garlic noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli garlic noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006035, 'Burnt Garlic Noodles', 'burnt garlic noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'burnt garlic noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006035, canonical_dish_id, 'en', 'Burnt Garlic Noodles', 'burnt garlic noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'burnt garlic noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'burnt garlic noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006036, 'Pan Fried Noodles', 'pan fried noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pan fried noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006036, canonical_dish_id, 'en', 'Pan Fried Noodles', 'pan fried noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'pan fried noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pan fried noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006037, 'Szechuan Noodles', 'szechuan noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'szechuan noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006037, canonical_dish_id, 'en', 'Szechuan Noodles', 'szechuan noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'szechuan noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'szechuan noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006038, 'Malaysian Noodles', 'malaysian noodles', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malaysian noodles');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006038, canonical_dish_id, 'en', 'Malaysian Noodles', 'malaysian noodles', 'primary'
    FROM canonical_dish WHERE normalized_name = 'malaysian noodles'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'malaysian noodles' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006039, 'Pad Krapow Gai in Wonton Cups', 'pad krapow gai in wonton cups', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pad krapow gai in wonton cups');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006039, canonical_dish_id, 'en', 'Pad Krapow Gai in Wonton Cups', 'pad krapow gai in wonton cups', 'primary'
    FROM canonical_dish WHERE normalized_name = 'pad krapow gai in wonton cups'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pad krapow gai in wonton cups' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006040, 'Koji Chicken', 'koji chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'koji chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006040, canonical_dish_id, 'en', 'Koji Chicken', 'koji chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'koji chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'koji chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006041, 'Crispy Chicken Schezwan Pepper', 'crispy chicken schezwan pepper', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy chicken schezwan pepper');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006041, canonical_dish_id, 'en', 'Crispy Chicken Schezwan Pepper', 'crispy chicken schezwan pepper', 'primary'
    FROM canonical_dish WHERE normalized_name = 'crispy chicken schezwan pepper'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'crispy chicken schezwan pepper' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006042, 'Assorted Pepper Chicken Chilli', 'assorted pepper chicken chilli', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'assorted pepper chicken chilli');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006042, canonical_dish_id, 'en', 'Assorted Pepper Chicken Chilli', 'assorted pepper chicken chilli', 'primary'
    FROM canonical_dish WHERE normalized_name = 'assorted pepper chicken chilli'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'assorted pepper chicken chilli' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006043, 'Ginger Chicken', 'ginger chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ginger chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006043, canonical_dish_id, 'en', 'Ginger Chicken', 'ginger chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'ginger chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'ginger chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006044, 'Exotic Thai Chicken', 'exotic thai chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'exotic thai chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006044, canonical_dish_id, 'en', 'Exotic Thai Chicken', 'exotic thai chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'exotic thai chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'exotic thai chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006045, 'Chicken in Japanese Sauce', 'chicken in japanese sauce', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken in japanese sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006045, canonical_dish_id, 'en', 'Chicken in Japanese Sauce', 'chicken in japanese sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken in japanese sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken in japanese sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006046, 'Chilli Oyster Chicken', 'chilli oyster chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli oyster chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006046, canonical_dish_id, 'en', 'Chilli Oyster Chicken', 'chilli oyster chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli oyster chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli oyster chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006047, 'Honey Mustard Chicken', 'honey mustard chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'honey mustard chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006047, canonical_dish_id, 'en', 'Honey Mustard Chicken', 'honey mustard chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'honey mustard chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'honey mustard chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006048, 'Orange Celery Chicken', 'orange celery chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'orange celery chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006048, canonical_dish_id, 'en', 'Orange Celery Chicken', 'orange celery chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'orange celery chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'orange celery chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006049, 'Wok Fried Chicken in Salt & Pepper', 'wok fried chicken in salt & pepper', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok fried chicken in salt & pepper');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006049, canonical_dish_id, 'en', 'Wok Fried Chicken in Salt & Pepper', 'wok fried chicken in salt & pepper', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok fried chicken in salt & pepper'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok fried chicken in salt & pepper' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006050, 'Korean Fried Chicken Wings in Spicy Gochujang', 'korean fried chicken wings in spicy gochujang', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean fried chicken wings in spicy gochujang');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006050, canonical_dish_id, 'en', 'Korean Fried Chicken Wings in Spicy Gochujang', 'korean fried chicken wings in spicy gochujang', 'primary'
    FROM canonical_dish WHERE normalized_name = 'korean fried chicken wings in spicy gochujang'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'korean fried chicken wings in spicy gochujang' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006051, 'Popcorn Chicken in Korean Sauce', 'popcorn chicken in korean sauce', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'popcorn chicken in korean sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006051, canonical_dish_id, 'en', 'Popcorn Chicken in Korean Sauce', 'popcorn chicken in korean sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'popcorn chicken in korean sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'popcorn chicken in korean sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006052, 'Poh Pia Tod', 'poh pia tod', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'poh pia tod');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006052, canonical_dish_id, 'en', 'Poh Pia Tod', 'poh pia tod', 'primary'
    FROM canonical_dish WHERE normalized_name = 'poh pia tod'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'poh pia tod' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006053, 'Chicken Lollipop', 'chicken lollipop', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollipop');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006053, canonical_dish_id, 'en', 'Chicken Lollipop', 'chicken lollipop', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken lollipop'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lollipop' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006054, 'Mutton Peshwari Seekh Kabab', 'mutton peshwari seekh kabab', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton peshwari seekh kabab');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006054, canonical_dish_id, 'en', 'Mutton Peshwari Seekh Kabab', 'mutton peshwari seekh kabab', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton peshwari seekh kabab'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton peshwari seekh kabab' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006055, 'Zaika-E-Nawabi Boti', 'zaika-e-nawabi boti', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'zaika-e-nawabi boti');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006055, canonical_dish_id, 'en', 'Zaika-E-Nawabi Boti', 'zaika-e-nawabi boti', 'primary'
    FROM canonical_dish WHERE normalized_name = 'zaika-e-nawabi boti'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'zaika-e-nawabi boti' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006056, 'Mutton Sikandari Raan-E-Boti', 'mutton sikandari raan-e-boti', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton sikandari raan-e-boti');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006056, canonical_dish_id, 'en', 'Mutton Sikandari Raan-E-Boti', 'mutton sikandari raan-e-boti', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton sikandari raan-e-boti'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton sikandari raan-e-boti' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006057, 'Mutton Nalli Barra', 'mutton nalli barra', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton nalli barra');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006057, canonical_dish_id, 'en', 'Mutton Nalli Barra', 'mutton nalli barra', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton nalli barra'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton nalli barra' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006058, 'Mutton Chaap Barra', 'mutton chaap barra', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton chaap barra');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006058, canonical_dish_id, 'en', 'Mutton Chaap Barra', 'mutton chaap barra', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton chaap barra'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton chaap barra' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006059, 'Smokery Special Lamb Platter', 'smokery special lamb platter', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'smokery special lamb platter');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006059, canonical_dish_id, 'en', 'Smokery Special Lamb Platter', 'smokery special lamb platter', 'primary'
    FROM canonical_dish WHERE normalized_name = 'smokery special lamb platter'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'smokery special lamb platter' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006060, 'Konjee Crispy Lamb', 'konjee crispy lamb', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'konjee crispy lamb');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006060, canonical_dish_id, 'en', 'Konjee Crispy Lamb', 'konjee crispy lamb', 'primary'
    FROM canonical_dish WHERE normalized_name = 'konjee crispy lamb'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'konjee crispy lamb' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006061, 'Wok Fried Lamb with Schezwan Pepper', 'wok fried lamb with schezwan pepper', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok fried lamb with schezwan pepper');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006061, canonical_dish_id, 'en', 'Wok Fried Lamb with Schezwan Pepper', 'wok fried lamb with schezwan pepper', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok fried lamb with schezwan pepper'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok fried lamb with schezwan pepper' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006062, 'Crispy Lamb with Dry Red Chilli & Garlic', 'crispy lamb with dry red chilli & garlic', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy lamb with dry red chilli & garlic');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006062, canonical_dish_id, 'en', 'Crispy Lamb with Dry Red Chilli & Garlic', 'crispy lamb with dry red chilli & garlic', 'primary'
    FROM canonical_dish WHERE normalized_name = 'crispy lamb with dry red chilli & garlic'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'crispy lamb with dry red chilli & garlic' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006063, 'Mongolian Lamb Stir-Fry', 'mongolian lamb stir-fry', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mongolian lamb stir-fry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006063, canonical_dish_id, 'en', 'Mongolian Lamb Stir-Fry', 'mongolian lamb stir-fry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mongolian lamb stir-fry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mongolian lamb stir-fry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006064, 'Fish Ajwain Tikka', 'fish ajwain tikka', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish ajwain tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006064, canonical_dish_id, 'en', 'Fish Ajwain Tikka', 'fish ajwain tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'fish ajwain tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'fish ajwain tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006065, 'Tawa Fried Fish', 'tawa fried fish', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tawa fried fish');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006065, canonical_dish_id, 'en', 'Tawa Fried Fish', 'tawa fried fish', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tawa fried fish'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tawa fried fish' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006066, 'Jhinga Dum Nisha', 'jhinga dum nisha', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jhinga dum nisha');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006066, canonical_dish_id, 'en', 'Jhinga Dum Nisha', 'jhinga dum nisha', 'primary'
    FROM canonical_dish WHERE normalized_name = 'jhinga dum nisha'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'jhinga dum nisha' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006067, 'Tandoori Schezwan Prawns', 'tandoori schezwan prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori schezwan prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006067, canonical_dish_id, 'en', 'Tandoori Schezwan Prawns', 'tandoori schezwan prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tandoori schezwan prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori schezwan prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006068, 'Hyderabadi Mutton Dum Biryani', 'hyderabadi mutton dum biryani', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hyderabadi mutton dum biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006068, canonical_dish_id, 'en', 'Hyderabadi Mutton Dum Biryani', 'hyderabadi mutton dum biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hyderabadi mutton dum biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hyderabadi mutton dum biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006069, 'Hyderabadi Chicken Dum Biryani', 'hyderabadi chicken dum biryani', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hyderabadi chicken dum biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006069, canonical_dish_id, 'en', 'Hyderabadi Chicken Dum Biryani', 'hyderabadi chicken dum biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hyderabadi chicken dum biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hyderabadi chicken dum biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006070, 'Tandoori Butter Chicken Biryani', 'tandoori butter chicken biryani', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter chicken biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006070, canonical_dish_id, 'en', 'Tandoori Butter Chicken Biryani', 'tandoori butter chicken biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tandoori butter chicken biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori butter chicken biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006071, 'Murgh Afghani Biryani', 'murgh afghani biryani', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh afghani biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006071, canonical_dish_id, 'en', 'Murgh Afghani Biryani', 'murgh afghani biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh afghani biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh afghani biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006072, 'Prawns Biryani', 'prawns biryani', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006072, canonical_dish_id, 'en', 'Prawns Biryani', 'prawns biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'prawns biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006073, 'Vegetable Biryani', 'vegetable biryani', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006073, canonical_dish_id, 'en', 'Vegetable Biryani', 'vegetable biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'vegetable biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vegetable biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006074, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006074, canonical_dish_id, 'en', 'Paneer Tikka Biryani', 'paneer tikka biryani', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka biryani' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006075, 'Green Peas Pulao', 'green peas pulao', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas pulao');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006075, canonical_dish_id, 'en', 'Green Peas Pulao', 'green peas pulao', 'primary'
    FROM canonical_dish WHERE normalized_name = 'green peas pulao'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'green peas pulao' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006076, 'Vegetable Pulao', 'vegetable pulao', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable pulao');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006076, canonical_dish_id, 'en', 'Vegetable Pulao', 'vegetable pulao', 'primary'
    FROM canonical_dish WHERE normalized_name = 'vegetable pulao'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vegetable pulao' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006077, 'Biryani Rice', 'biryani rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'biryani rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006077, canonical_dish_id, 'en', 'Biryani Rice', 'biryani rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'biryani rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'biryani rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006078, 'Jeera Rice', 'jeera rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006078, canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'jeera rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'jeera rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006079, 'Steamed Rice', 'steamed rice', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steamed rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006079, canonical_dish_id, 'en', 'Steamed Rice', 'steamed rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'steamed rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'steamed rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006080, 'Hyderabadi Mandi', 'hyderabadi mandi', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hyderabadi mandi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006080, canonical_dish_id, 'en', 'Hyderabadi Mandi', 'hyderabadi mandi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hyderabadi mandi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hyderabadi mandi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006081, 'Smokery Raan Mandi', 'smokery raan mandi', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'smokery raan mandi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006081, canonical_dish_id, 'en', 'Smokery Raan Mandi', 'smokery raan mandi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'smokery raan mandi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'smokery raan mandi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006082, 'Murgh Hyderabadi Kabsa Rice', 'murgh hyderabadi kabsa rice', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh hyderabadi kabsa rice');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006082, canonical_dish_id, 'en', 'Murgh Hyderabadi Kabsa Rice', 'murgh hyderabadi kabsa rice', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh hyderabadi kabsa rice'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh hyderabadi kabsa rice' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006083, 'Assorted Chinese Kabsa', 'assorted chinese kabsa', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'assorted chinese kabsa');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006083, canonical_dish_id, 'en', 'Assorted Chinese Kabsa', 'assorted chinese kabsa', 'primary'
    FROM canonical_dish WHERE normalized_name = 'assorted chinese kabsa'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'assorted chinese kabsa' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006084, 'Smokery Special Thaal', 'smokery special thaal', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'smokery special thaal');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006084, canonical_dish_id, 'en', 'Smokery Special Thaal', 'smokery special thaal', 'primary'
    FROM canonical_dish WHERE normalized_name = 'smokery special thaal'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'smokery special thaal' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006085, 'Roti', 'roti', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roti');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006085, canonical_dish_id, 'en', 'Roti', 'roti', 'primary'
    FROM canonical_dish WHERE normalized_name = 'roti'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'roti' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006086, 'Butter Roti', 'butter roti', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter roti');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006086, canonical_dish_id, 'en', 'Butter Roti', 'butter roti', 'primary'
    FROM canonical_dish WHERE normalized_name = 'butter roti'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter roti' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006087, 'Lacha Paratha', 'lacha paratha', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lacha paratha');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006087, canonical_dish_id, 'en', 'Lacha Paratha', 'lacha paratha', 'primary'
    FROM canonical_dish WHERE normalized_name = 'lacha paratha'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'lacha paratha' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006088, 'Zaatar Cheese Naan', 'zaatar cheese naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'zaatar cheese naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006088, canonical_dish_id, 'en', 'Zaatar Cheese Naan', 'zaatar cheese naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'zaatar cheese naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'zaatar cheese naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006089, 'Zaatar Naan', 'zaatar naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'zaatar naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006089, canonical_dish_id, 'en', 'Zaatar Naan', 'zaatar naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'zaatar naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'zaatar naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006090, 'Activated Charcoal Naan', 'activated charcoal naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'activated charcoal naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006090, canonical_dish_id, 'en', 'Activated Charcoal Naan', 'activated charcoal naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'activated charcoal naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'activated charcoal naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006091, 'Butter Naan', 'butter naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006091, canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'butter naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006092, 'Naan', 'naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006092, canonical_dish_id, 'en', 'Naan', 'naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006093, 'Garlic Naan', 'garlic naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006093, canonical_dish_id, 'en', 'Garlic Naan', 'garlic naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'garlic naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'garlic naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006094, 'Cheese Garlic Naan', 'cheese garlic naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese garlic naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006094, canonical_dish_id, 'en', 'Cheese Garlic Naan', 'cheese garlic naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'cheese garlic naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'cheese garlic naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006095, 'Chilli Naan', 'chilli naan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli naan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006095, canonical_dish_id, 'en', 'Chilli Naan', 'chilli naan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli naan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli naan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006096, 'Kulcha', 'kulcha', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006096, canonical_dish_id, 'en', 'Kulcha', 'kulcha', 'primary'
    FROM canonical_dish WHERE normalized_name = 'kulcha'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kulcha' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006097, 'Chilli Kulcha', 'chilli kulcha', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli kulcha');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006097, canonical_dish_id, 'en', 'Chilli Kulcha', 'chilli kulcha', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli kulcha'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli kulcha' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006098, 'Taftan', 'taftan', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'taftan');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006098, canonical_dish_id, 'en', 'Taftan', 'taftan', 'primary'
    FROM canonical_dish WHERE normalized_name = 'taftan'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'taftan' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006099, 'Rumali Roti', 'rumali roti', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rumali roti');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006099, canonical_dish_id, 'en', 'Rumali Roti', 'rumali roti', 'primary'
    FROM canonical_dish WHERE normalized_name = 'rumali roti'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'rumali roti' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006100, 'Tandoori Basket', 'tandoori basket', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori basket');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006100, canonical_dish_id, 'en', 'Tandoori Basket', 'tandoori basket', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tandoori basket'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori basket' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006101, 'Butter Chicken', 'butter chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006101, canonical_dish_id, 'en', 'Butter Chicken', 'butter chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'butter chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006102, 'Murgh Kadai', 'murgh kadai', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh kadai');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006102, canonical_dish_id, 'en', 'Murgh Kadai', 'murgh kadai', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh kadai'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh kadai' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006103, 'Murgh Adraki', 'murgh adraki', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh adraki');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006103, canonical_dish_id, 'en', 'Murgh Adraki', 'murgh adraki', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh adraki'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh adraki' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006104, 'Murgh Hari Mirch Ka Kheema', 'murgh hari mirch ka kheema', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh hari mirch ka kheema');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006104, canonical_dish_id, 'en', 'Murgh Hari Mirch Ka Kheema', 'murgh hari mirch ka kheema', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh hari mirch ka kheema'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh hari mirch ka kheema' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006105, 'Murgh Mumtaz', 'murgh mumtaz', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh mumtaz');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006105, canonical_dish_id, 'en', 'Murgh Mumtaz', 'murgh mumtaz', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh mumtaz'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh mumtaz' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006106, 'Chicken Tikka Masala', 'chicken tikka masala', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka masala');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006106, canonical_dish_id, 'en', 'Chicken Tikka Masala', 'chicken tikka masala', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken tikka masala'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tikka masala' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006107, 'Chicken Farcha', 'chicken farcha', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken farcha');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006107, canonical_dish_id, 'en', 'Chicken Farcha', 'chicken farcha', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken farcha'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken farcha' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006108, 'Chicken Lababdar', 'chicken lababdar', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lababdar');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006108, canonical_dish_id, 'en', 'Chicken Lababdar', 'chicken lababdar', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken lababdar'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lababdar' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006109, 'Anda Curry', 'anda curry', 'egg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'anda curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006109, canonical_dish_id, 'en', 'Anda Curry', 'anda curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'anda curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'anda curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006110, 'Nalli Nihari', 'nalli nihari', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nalli nihari');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006110, canonical_dish_id, 'en', 'Nalli Nihari', 'nalli nihari', 'primary'
    FROM canonical_dish WHERE normalized_name = 'nalli nihari'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'nalli nihari' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006111, 'Mutton Rogan Josh', 'mutton rogan josh', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rogan josh');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006111, canonical_dish_id, 'en', 'Mutton Rogan Josh', 'mutton rogan josh', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton rogan josh'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton rogan josh' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006112, 'Mutton Pepper Fried', 'mutton pepper fried', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton pepper fried');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006112, canonical_dish_id, 'en', 'Mutton Pepper Fried', 'mutton pepper fried', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton pepper fried'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton pepper fried' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006113, 'Mutton Raan Masala', 'mutton raan masala', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton raan masala');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006113, canonical_dish_id, 'en', 'Mutton Raan Masala', 'mutton raan masala', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton raan masala'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton raan masala' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006114, 'Mutton Laal Maas', 'mutton laal maas', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton laal maas');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006114, canonical_dish_id, 'en', 'Mutton Laal Maas', 'mutton laal maas', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton laal maas'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton laal maas' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006115, 'Mutton Rezala', 'mutton rezala', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rezala');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006115, canonical_dish_id, 'en', 'Mutton Rezala', 'mutton rezala', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton rezala'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton rezala' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006116, 'Mutton Rara', 'mutton rara', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rara');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006116, canonical_dish_id, 'en', 'Mutton Rara', 'mutton rara', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton rara'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton rara' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006117, 'Paneer Kadai', 'paneer kadai', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006117, canonical_dish_id, 'en', 'Paneer Kadai', 'paneer kadai', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paneer kadai'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer kadai' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006118, 'Paneer Jalfrezi', 'paneer jalfrezi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer jalfrezi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006118, canonical_dish_id, 'en', 'Paneer Jalfrezi', 'paneer jalfrezi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paneer jalfrezi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer jalfrezi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006119, 'Paneer Makhanwala', 'paneer makhanwala', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhanwala');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006119, canonical_dish_id, 'en', 'Paneer Makhanwala', 'paneer makhanwala', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paneer makhanwala'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer makhanwala' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006120, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006120, canonical_dish_id, 'en', 'Paneer Tikka Masala', 'paneer tikka masala', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paneer tikka masala'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka masala' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006121, 'Palak Paneer', 'palak paneer', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak paneer');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006121, canonical_dish_id, 'en', 'Palak Paneer', 'palak paneer', 'primary'
    FROM canonical_dish WHERE normalized_name = 'palak paneer'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'palak paneer' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006122, 'Methi Chaman', 'methi chaman', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi chaman');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006122, canonical_dish_id, 'en', 'Methi Chaman', 'methi chaman', 'primary'
    FROM canonical_dish WHERE normalized_name = 'methi chaman'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'methi chaman' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006123, 'Mix Vegetable Handi', 'mix vegetable handi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix vegetable handi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006123, canonical_dish_id, 'en', 'Mix Vegetable Handi', 'mix vegetable handi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mix vegetable handi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix vegetable handi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006124, 'Vegetable Nawabi Khorma', 'vegetable nawabi khorma', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable nawabi khorma');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006124, canonical_dish_id, 'en', 'Vegetable Nawabi Khorma', 'vegetable nawabi khorma', 'primary'
    FROM canonical_dish WHERE normalized_name = 'vegetable nawabi khorma'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vegetable nawabi khorma' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006125, 'Vegetable Kadai', 'vegetable kadai', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable kadai');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006125, canonical_dish_id, 'en', 'Vegetable Kadai', 'vegetable kadai', 'primary'
    FROM canonical_dish WHERE normalized_name = 'vegetable kadai'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vegetable kadai' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006126, 'Mushroom Masala', 'mushroom masala', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom masala');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006126, canonical_dish_id, 'en', 'Mushroom Masala', 'mushroom masala', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mushroom masala'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom masala' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006127, 'Methi Matar Malai', 'methi matar malai', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi matar malai');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006127, canonical_dish_id, 'en', 'Methi Matar Malai', 'methi matar malai', 'primary'
    FROM canonical_dish WHERE normalized_name = 'methi matar malai'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'methi matar malai' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006128, 'Chilli Oyster Sauce', 'chilli oyster sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli oyster sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006128, canonical_dish_id, 'en', 'Chilli Oyster Sauce', 'chilli oyster sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli oyster sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli oyster sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006129, 'Black Bean Coriander Sauce', 'black bean coriander sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black bean coriander sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006129, canonical_dish_id, 'en', 'Black Bean Coriander Sauce', 'black bean coriander sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'black bean coriander sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'black bean coriander sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006130, 'Caramel Chilli Sauce', 'caramel chilli sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'caramel chilli sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006130, canonical_dish_id, 'en', 'Caramel Chilli Sauce', 'caramel chilli sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'caramel chilli sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'caramel chilli sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006131, 'Cantonese Sauce', 'cantonese sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cantonese sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006131, canonical_dish_id, 'en', 'Cantonese Sauce', 'cantonese sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'cantonese sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'cantonese sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006132, 'Korean Chilli Sauce', 'korean chilli sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean chilli sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006132, canonical_dish_id, 'en', 'Korean Chilli Sauce', 'korean chilli sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'korean chilli sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'korean chilli sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006133, 'Sapo Sauce', 'sapo sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sapo sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006133, canonical_dish_id, 'en', 'Sapo Sauce', 'sapo sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'sapo sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sapo sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006134, 'Mapo Tofu', 'mapo tofu', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mapo tofu');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006134, canonical_dish_id, 'en', 'Mapo Tofu', 'mapo tofu', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mapo tofu'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mapo tofu' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006135, 'Hunan Chilli', 'hunan chilli', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hunan chilli');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006135, canonical_dish_id, 'en', 'Hunan Chilli', 'hunan chilli', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hunan chilli'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hunan chilli' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006136, 'Hot Garlic Sauce', 'hot garlic sauce', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot garlic sauce');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006136, canonical_dish_id, 'en', 'Hot Garlic Sauce', 'hot garlic sauce', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hot garlic sauce'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hot garlic sauce' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006137, 'Tempura Prawns', 'tempura prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tempura prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006137, canonical_dish_id, 'en', 'Tempura Prawns', 'tempura prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tempura prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tempura prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006138, 'Goong Samrot', 'goong samrot', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'goong samrot');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006138, canonical_dish_id, 'en', 'Goong Samrot', 'goong samrot', 'primary'
    FROM canonical_dish WHERE normalized_name = 'goong samrot'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'goong samrot' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006139, 'Wok Fried Fish in Salt & Pepper', 'wok fried fish in salt & pepper', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok fried fish in salt & pepper');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006139, canonical_dish_id, 'en', 'Wok Fried Fish in Salt & Pepper', 'wok fried fish in salt & pepper', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok fried fish in salt & pepper'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok fried fish in salt & pepper' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006140, 'Wok Fried Prawns in Salt & Pepper', 'wok fried prawns in salt & pepper', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok fried prawns in salt & pepper');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006140, canonical_dish_id, 'en', 'Wok Fried Prawns in Salt & Pepper', 'wok fried prawns in salt & pepper', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok fried prawns in salt & pepper'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok fried prawns in salt & pepper' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006141, 'Pad Krapow Goong', 'pad krapow goong', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pad krapow goong');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006141, canonical_dish_id, 'en', 'Pad Krapow Goong', 'pad krapow goong', 'primary'
    FROM canonical_dish WHERE normalized_name = 'pad krapow goong'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pad krapow goong' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006142, 'Butter Garlic Fish', 'butter garlic fish', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter garlic fish');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006142, canonical_dish_id, 'en', 'Butter Garlic Fish', 'butter garlic fish', 'primary'
    FROM canonical_dish WHERE normalized_name = 'butter garlic fish'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter garlic fish' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006143, 'Butter Garlic Prawns', 'butter garlic prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter garlic prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006143, canonical_dish_id, 'en', 'Butter Garlic Prawns', 'butter garlic prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'butter garlic prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter garlic prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006144, 'Cantonese Style Fried Fish Balls', 'cantonese style fried fish balls', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cantonese style fried fish balls');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006144, canonical_dish_id, 'en', 'Cantonese Style Fried Fish Balls', 'cantonese style fried fish balls', 'primary'
    FROM canonical_dish WHERE normalized_name = 'cantonese style fried fish balls'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'cantonese style fried fish balls' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006145, 'Wok Ginger Scallion Fish', 'wok ginger scallion fish', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok ginger scallion fish');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006145, canonical_dish_id, 'en', 'Wok Ginger Scallion Fish', 'wok ginger scallion fish', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok ginger scallion fish'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok ginger scallion fish' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006146, 'Wok Ginger Scallion Prawns', 'wok ginger scallion prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok ginger scallion prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006146, canonical_dish_id, 'en', 'Wok Ginger Scallion Prawns', 'wok ginger scallion prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok ginger scallion prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok ginger scallion prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006147, 'Thermidor Prawns', 'thermidor prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thermidor prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006147, canonical_dish_id, 'en', 'Thermidor Prawns', 'thermidor prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'thermidor prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'thermidor prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006148, 'Chilli to Pepper Fish', 'chilli to pepper fish', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli to pepper fish');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006148, canonical_dish_id, 'en', 'Chilli to Pepper Fish', 'chilli to pepper fish', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli to pepper fish'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli to pepper fish' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006149, 'Chilli to Pepper Prawns', 'chilli to pepper prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli to pepper prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006149, canonical_dish_id, 'en', 'Chilli to Pepper Prawns', 'chilli to pepper prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli to pepper prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli to pepper prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006150, 'Thai Prawns', 'thai prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006150, canonical_dish_id, 'en', 'Thai Prawns', 'thai prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'thai prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'thai prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006151, 'Crackling Fish', 'crackling fish', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crackling fish');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006151, canonical_dish_id, 'en', 'Crackling Fish', 'crackling fish', 'primary'
    FROM canonical_dish WHERE normalized_name = 'crackling fish'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'crackling fish' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006152, 'Crackling Prawns', 'crackling prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crackling prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006152, canonical_dish_id, 'en', 'Crackling Prawns', 'crackling prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'crackling prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'crackling prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006153, 'Garlic Pepper Fish', 'garlic pepper fish', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic pepper fish');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006153, canonical_dish_id, 'en', 'Garlic Pepper Fish', 'garlic pepper fish', 'primary'
    FROM canonical_dish WHERE normalized_name = 'garlic pepper fish'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'garlic pepper fish' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006154, 'Garlic Pepper Prawns', 'garlic pepper prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic pepper prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006154, canonical_dish_id, 'en', 'Garlic Pepper Prawns', 'garlic pepper prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'garlic pepper prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'garlic pepper prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006155, 'Balchao Prawns', 'balchao prawns', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'balchao prawns');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006155, canonical_dish_id, 'en', 'Balchao Prawns', 'balchao prawns', 'primary'
    FROM canonical_dish WHERE normalized_name = 'balchao prawns'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'balchao prawns' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006156, 'Fish Goan Curry', 'fish goan curry', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish goan curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006156, canonical_dish_id, 'en', 'Fish Goan Curry', 'fish goan curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'fish goan curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'fish goan curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006157, 'Prawns Goan Curry', 'prawns goan curry', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns goan curry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006157, canonical_dish_id, 'en', 'Prawns Goan Curry', 'prawns goan curry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'prawns goan curry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns goan curry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006158, 'Vindaloo Mutton', 'vindaloo mutton', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vindaloo mutton');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006158, canonical_dish_id, 'en', 'Vindaloo Mutton', 'vindaloo mutton', 'primary'
    FROM canonical_dish WHERE normalized_name = 'vindaloo mutton'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vindaloo mutton' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006159, 'Chicken Xacuti', 'chicken xacuti', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken xacuti');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006159, canonical_dish_id, 'en', 'Chicken Xacuti', 'chicken xacuti', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken xacuti'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken xacuti' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006160, 'Prawns Roasted Coconut Gravy', 'prawns roasted coconut gravy', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns roasted coconut gravy');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006160, canonical_dish_id, 'en', 'Prawns Roasted Coconut Gravy', 'prawns roasted coconut gravy', 'primary'
    FROM canonical_dish WHERE normalized_name = 'prawns roasted coconut gravy'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns roasted coconut gravy' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006161, 'Chicken Cafreal', 'chicken cafreal', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken cafreal');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006161, canonical_dish_id, 'en', 'Chicken Cafreal', 'chicken cafreal', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chicken cafreal'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken cafreal' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006162, 'Murgh Zaika', 'murgh zaika', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh zaika');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006162, canonical_dish_id, 'en', 'Murgh Zaika', 'murgh zaika', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh zaika'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh zaika' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006163, 'Murgh Pasanda', 'murgh pasanda', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh pasanda');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006163, canonical_dish_id, 'en', 'Murgh Pasanda', 'murgh pasanda', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh pasanda'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh pasanda' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006164, 'Murgh Pakiza', 'murgh pakiza', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh pakiza');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006164, canonical_dish_id, 'en', 'Murgh Pakiza', 'murgh pakiza', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh pakiza'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh pakiza' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006165, 'Pepper Chicken', 'pepper chicken', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pepper chicken');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006165, canonical_dish_id, 'en', 'Pepper Chicken', 'pepper chicken', 'primary'
    FROM canonical_dish WHERE normalized_name = 'pepper chicken'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pepper chicken' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006166, 'Murgh Badami Khorma', 'murgh badami khorma', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh badami khorma');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006166, canonical_dish_id, 'en', 'Murgh Badami Khorma', 'murgh badami khorma', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh badami khorma'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh badami khorma' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006167, 'Dum Ka Murgh', 'dum ka murgh', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dum ka murgh');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006167, canonical_dish_id, 'en', 'Dum Ka Murgh', 'dum ka murgh', 'primary'
    FROM canonical_dish WHERE normalized_name = 'dum ka murgh'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dum ka murgh' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006168, 'Murgh Sufiyana', 'murgh sufiyana', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh sufiyana');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006168, canonical_dish_id, 'en', 'Murgh Sufiyana', 'murgh sufiyana', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh sufiyana'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh sufiyana' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006169, 'Murgh Nizami Handi', 'murgh nizami handi', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh nizami handi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006169, canonical_dish_id, 'en', 'Murgh Nizami Handi', 'murgh nizami handi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh nizami handi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh nizami handi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006170, 'Mutton Hyderabadi Khorma', 'mutton hyderabadi khorma', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hyderabadi khorma');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006170, canonical_dish_id, 'en', 'Mutton Hyderabadi Khorma', 'mutton hyderabadi khorma', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton hyderabadi khorma'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton hyderabadi khorma' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006171, 'Mutton Stew', 'mutton stew', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton stew');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006171, canonical_dish_id, 'en', 'Mutton Stew', 'mutton stew', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton stew'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton stew' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006172, 'Mutton Dum Ka Kheema', 'mutton dum ka kheema', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dum ka kheema');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006172, canonical_dish_id, 'en', 'Mutton Dum Ka Kheema', 'mutton dum ka kheema', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mutton dum ka kheema'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton dum ka kheema' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006173, 'Dal Bukhara', 'dal bukhara', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal bukhara');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006173, canonical_dish_id, 'en', 'Dal Bukhara', 'dal bukhara', 'primary'
    FROM canonical_dish WHERE normalized_name = 'dal bukhara'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal bukhara' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006174, 'Dal Fry', 'dal fry', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006174, canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary'
    FROM canonical_dish WHERE normalized_name = 'dal fry'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal fry' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006175, 'Dal Tadka', 'dal tadka', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006175, canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'dal tadka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal tadka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006176, 'Dal Khichdi', 'dal khichdi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006176, canonical_dish_id, 'en', 'Dal Khichdi', 'dal khichdi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'dal khichdi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal khichdi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006177, 'Murgh Shorba', 'murgh shorba', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh shorba');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006177, canonical_dish_id, 'en', 'Murgh Shorba', 'murgh shorba', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh shorba'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh shorba' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006178, 'Paya Shorba', 'paya shorba', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paya shorba');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006178, canonical_dish_id, 'en', 'Paya Shorba', 'paya shorba', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paya shorba'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paya shorba' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006179, 'Hyderabadi Mutton Shorba', 'hyderabadi mutton shorba', 'non_veg', v_protein_mutton
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hyderabadi mutton shorba');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006179, canonical_dish_id, 'en', 'Hyderabadi Mutton Shorba', 'hyderabadi mutton shorba', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hyderabadi mutton shorba'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hyderabadi mutton shorba' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006180, 'Tomato Dhaniya Ka Shorba', 'tomato dhaniya ka shorba', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato dhaniya ka shorba');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006180, canonical_dish_id, 'en', 'Tomato Dhaniya Ka Shorba', 'tomato dhaniya ka shorba', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tomato dhaniya ka shorba'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tomato dhaniya ka shorba' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006181, 'Tom Yum Soup', 'tom yum soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tom yum soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006181, canonical_dish_id, 'en', 'Tom Yum Soup', 'tom yum soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tom yum soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tom yum soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006182, 'Tom Kha Soup', 'tom kha soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tom kha soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006182, canonical_dish_id, 'en', 'Tom Kha Soup', 'tom kha soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tom kha soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tom kha soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006183, 'Mandu-Guk Dumpling Soup', 'mandu-guk dumpling soup', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mandu-guk dumpling soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006183, canonical_dish_id, 'en', 'Mandu-Guk Dumpling Soup', 'mandu-guk dumpling soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mandu-guk dumpling soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mandu-guk dumpling soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006184, 'Manchow Soup', 'manchow soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'manchow soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006184, canonical_dish_id, 'en', 'Manchow Soup', 'manchow soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'manchow soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'manchow soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006185, 'Laksa Noodle Soup', 'laksa noodle soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laksa noodle soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006185, canonical_dish_id, 'en', 'Laksa Noodle Soup', 'laksa noodle soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'laksa noodle soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'laksa noodle soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006186, 'Hot & Sour Soup', 'hot & sour soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot & sour soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006186, canonical_dish_id, 'en', 'Hot & Sour Soup', 'hot & sour soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hot & sour soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hot & sour soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006187, 'Roasted Pepper Sweet Corn Soup', 'roasted pepper sweet corn soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roasted pepper sweet corn soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006187, canonical_dish_id, 'en', 'Roasted Pepper Sweet Corn Soup', 'roasted pepper sweet corn soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'roasted pepper sweet corn soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'roasted pepper sweet corn soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006188, 'Clear Soup', 'clear soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'clear soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006188, canonical_dish_id, 'en', 'Clear Soup', 'clear soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'clear soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'clear soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006189, 'Lemon Coriander Soup', 'lemon coriander soup', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon coriander soup');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006189, canonical_dish_id, 'en', 'Lemon Coriander Soup', 'lemon coriander soup', 'primary'
    FROM canonical_dish WHERE normalized_name = 'lemon coriander soup'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'lemon coriander soup' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006190, 'Dynamite Tempura Prawns Sushi', 'dynamite tempura prawns sushi', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dynamite tempura prawns sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006190, canonical_dish_id, 'en', 'Dynamite Tempura Prawns Sushi', 'dynamite tempura prawns sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'dynamite tempura prawns sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dynamite tempura prawns sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006191, 'Tempura Prawns Sushi', 'tempura prawns sushi', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tempura prawns sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006191, canonical_dish_id, 'en', 'Tempura Prawns Sushi', 'tempura prawns sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tempura prawns sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tempura prawns sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006192, 'Prawns California Sushi', 'prawns california sushi', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns california sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006192, canonical_dish_id, 'en', 'Prawns California Sushi', 'prawns california sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'prawns california sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns california sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006193, 'Teriyaki Prawns Sushi', 'teriyaki prawns sushi', 'non_veg', v_protein_seafood
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'teriyaki prawns sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006193, canonical_dish_id, 'en', 'Teriyaki Prawns Sushi', 'teriyaki prawns sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'teriyaki prawns sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'teriyaki prawns sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006194, 'Takuan Maki', 'takuan maki', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'takuan maki');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006194, canonical_dish_id, 'en', 'Takuan Maki', 'takuan maki', 'primary'
    FROM canonical_dish WHERE normalized_name = 'takuan maki'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'takuan maki' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006195, 'Asparagus Tempura Sushi', 'asparagus tempura sushi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'asparagus tempura sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006195, canonical_dish_id, 'en', 'Asparagus Tempura Sushi', 'asparagus tempura sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'asparagus tempura sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'asparagus tempura sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006196, 'Tempura Avocado Sushi', 'tempura avocado sushi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tempura avocado sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006196, canonical_dish_id, 'en', 'Tempura Avocado Sushi', 'tempura avocado sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'tempura avocado sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tempura avocado sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006197, 'Avocado Sesame Cheese Sushi', 'avocado sesame cheese sushi', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'avocado sesame cheese sushi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006197, canonical_dish_id, 'en', 'Avocado Sesame Cheese Sushi', 'avocado sesame cheese sushi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'avocado sesame cheese sushi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'avocado sesame cheese sushi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006198, 'Soupy Dim Sum', 'soupy dim sum', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soupy dim sum');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006198, canonical_dish_id, 'en', 'Soupy Dim Sum', 'soupy dim sum', 'primary'
    FROM canonical_dish WHERE normalized_name = 'soupy dim sum'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'soupy dim sum' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006199, 'Sui Mai', 'sui mai', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sui mai');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006199, canonical_dish_id, 'en', 'Sui Mai', 'sui mai', 'primary'
    FROM canonical_dish WHERE normalized_name = 'sui mai'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sui mai' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006200, 'Har Gow', 'har gow', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'har gow');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006200, canonical_dish_id, 'en', 'Har Gow', 'har gow', 'primary'
    FROM canonical_dish WHERE normalized_name = 'har gow'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'har gow' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006201, 'Potstickers', 'potstickers', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'potstickers');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006201, canonical_dish_id, 'en', 'Potstickers', 'potstickers', 'primary'
    FROM canonical_dish WHERE normalized_name = 'potstickers'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'potstickers' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006202, 'Crystal Dumpling', 'crystal dumpling', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crystal dumpling');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006202, canonical_dish_id, 'en', 'Crystal Dumpling', 'crystal dumpling', 'primary'
    FROM canonical_dish WHERE normalized_name = 'crystal dumpling'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'crystal dumpling' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006203, 'Steamed Korean Bao', 'steamed korean bao', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steamed korean bao');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006203, canonical_dish_id, 'en', 'Steamed Korean Bao', 'steamed korean bao', 'primary'
    FROM canonical_dish WHERE normalized_name = 'steamed korean bao'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'steamed korean bao' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006204, 'Crispy Chicken Bao with Pickled Carrot, Spicy Mayo', 'crispy chicken bao with pickled carrot, spicy mayo', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy chicken bao with pickled carrot, spicy mayo');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006204, canonical_dish_id, 'en', 'Crispy Chicken Bao with Pickled Carrot, Spicy Mayo', 'crispy chicken bao with pickled carrot, spicy mayo', 'primary'
    FROM canonical_dish WHERE normalized_name = 'crispy chicken bao with pickled carrot, spicy mayo'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'crispy chicken bao with pickled carrot, spicy mayo' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006205, 'Cheung Fun', 'cheung fun', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheung fun');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006205, canonical_dish_id, 'en', 'Cheung Fun', 'cheung fun', 'primary'
    FROM canonical_dish WHERE normalized_name = 'cheung fun'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'cheung fun' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006206, 'Fried Wonton', 'fried wonton', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fried wonton');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006206, canonical_dish_id, 'en', 'Fried Wonton', 'fried wonton', 'primary'
    FROM canonical_dish WHERE normalized_name = 'fried wonton'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'fried wonton' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006207, 'Mizumi Ramen', 'mizumi ramen', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mizumi ramen');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006207, canonical_dish_id, 'en', 'Mizumi Ramen', 'mizumi ramen', 'primary'
    FROM canonical_dish WHERE normalized_name = 'mizumi ramen'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mizumi ramen' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006208, 'Miso Ramen', 'miso ramen', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'miso ramen');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006208, canonical_dish_id, 'en', 'Miso Ramen', 'miso ramen', 'primary'
    FROM canonical_dish WHERE normalized_name = 'miso ramen'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'miso ramen' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006209, 'Spicy Kimchi Ramen', 'spicy kimchi ramen', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spicy kimchi ramen');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006209, canonical_dish_id, 'en', 'Spicy Kimchi Ramen', 'spicy kimchi ramen', 'primary'
    FROM canonical_dish WHERE normalized_name = 'spicy kimchi ramen'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'spicy kimchi ramen' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006210, 'Creamy Ramen Bowl', 'creamy ramen bowl', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'creamy ramen bowl');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006210, canonical_dish_id, 'en', 'Creamy Ramen Bowl', 'creamy ramen bowl', 'primary'
    FROM canonical_dish WHERE normalized_name = 'creamy ramen bowl'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'creamy ramen bowl' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006211, 'Thai Ramen', 'thai ramen', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai ramen');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006211, canonical_dish_id, 'en', 'Thai Ramen', 'thai ramen', 'primary'
    FROM canonical_dish WHERE normalized_name = 'thai ramen'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'thai ramen' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006212, 'Chilli Basil Pesto Tikka', 'chilli basil pesto tikka', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli basil pesto tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006212, canonical_dish_id, 'en', 'Chilli Basil Pesto Tikka', 'chilli basil pesto tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'chilli basil pesto tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chilli basil pesto tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006213, 'Paneer Peri Peri Tikka', 'paneer peri peri tikka', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer peri peri tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006213, canonical_dish_id, 'en', 'Paneer Peri Peri Tikka', 'paneer peri peri tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'paneer peri peri tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer peri peri tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006214, 'Shaslik Paneer Tikka', 'shaslik paneer tikka', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shaslik paneer tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006214, canonical_dish_id, 'en', 'Shaslik Paneer Tikka', 'shaslik paneer tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'shaslik paneer tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'shaslik paneer tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006215, 'Peshawari Paneer Tikka', 'peshawari paneer tikka', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peshawari paneer tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006215, canonical_dish_id, 'en', 'Peshawari Paneer Tikka', 'peshawari paneer tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'peshawari paneer tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'peshawari paneer tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006216, 'Firdausi Aloo', 'firdausi aloo', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'firdausi aloo');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006216, canonical_dish_id, 'en', 'Firdausi Aloo', 'firdausi aloo', 'primary'
    FROM canonical_dish WHERE normalized_name = 'firdausi aloo'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'firdausi aloo' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006217, 'Makhmali Mushroom Tikka', 'makhmali mushroom tikka', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'makhmali mushroom tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006217, canonical_dish_id, 'en', 'Makhmali Mushroom Tikka', 'makhmali mushroom tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'makhmali mushroom tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'makhmali mushroom tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006218, 'Lotus Stem Honey Chilli', 'lotus stem honey chilli', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lotus stem honey chilli');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006218, canonical_dish_id, 'en', 'Lotus Stem Honey Chilli', 'lotus stem honey chilli', 'primary'
    FROM canonical_dish WHERE normalized_name = 'lotus stem honey chilli'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'lotus stem honey chilli' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006219, 'Assorted Pepper Cottage Cheese Chilli', 'assorted pepper cottage cheese chilli', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'assorted pepper cottage cheese chilli');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006219, canonical_dish_id, 'en', 'Assorted Pepper Cottage Cheese Chilli', 'assorted pepper cottage cheese chilli', 'primary'
    FROM canonical_dish WHERE normalized_name = 'assorted pepper cottage cheese chilli'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'assorted pepper cottage cheese chilli' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006220, 'Singapore Cottage Cheese', 'singapore cottage cheese', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore cottage cheese');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006220, canonical_dish_id, 'en', 'Singapore Cottage Cheese', 'singapore cottage cheese', 'primary'
    FROM canonical_dish WHERE normalized_name = 'singapore cottage cheese'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'singapore cottage cheese' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006221, 'Vegetable Manchurian', 'vegetable manchurian', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable manchurian');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006221, canonical_dish_id, 'en', 'Vegetable Manchurian', 'vegetable manchurian', 'primary'
    FROM canonical_dish WHERE normalized_name = 'vegetable manchurian'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vegetable manchurian' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006222, 'Honey Chilli Potato', 'honey chilli potato', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'honey chilli potato');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006222, canonical_dish_id, 'en', 'Honey Chilli Potato', 'honey chilli potato', 'primary'
    FROM canonical_dish WHERE normalized_name = 'honey chilli potato'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'honey chilli potato' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006223, 'Schezwan Chilli Baby Corn', 'schezwan chilli baby corn', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan chilli baby corn');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006223, canonical_dish_id, 'en', 'Schezwan Chilli Baby Corn', 'schezwan chilli baby corn', 'primary'
    FROM canonical_dish WHERE normalized_name = 'schezwan chilli baby corn'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'schezwan chilli baby corn' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006224, 'Assorted Pepper Mushroom Chilli', 'assorted pepper mushroom chilli', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'assorted pepper mushroom chilli');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006224, canonical_dish_id, 'en', 'Assorted Pepper Mushroom Chilli', 'assorted pepper mushroom chilli', 'primary'
    FROM canonical_dish WHERE normalized_name = 'assorted pepper mushroom chilli'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'assorted pepper mushroom chilli' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006225, 'Corn Pistolo', 'corn pistolo', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'corn pistolo');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006225, canonical_dish_id, 'en', 'Corn Pistolo', 'corn pistolo', 'primary'
    FROM canonical_dish WHERE normalized_name = 'corn pistolo'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'corn pistolo' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006226, 'Wok Fried Vegetables in Salt & Pepper', 'wok fried vegetables in salt & pepper', 'veg', NULL
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'wok fried vegetables in salt & pepper');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006226, canonical_dish_id, 'en', 'Wok Fried Vegetables in Salt & Pepper', 'wok fried vegetables in salt & pepper', 'primary'
    FROM canonical_dish WHERE normalized_name = 'wok fried vegetables in salt & pepper'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'wok fried vegetables in salt & pepper' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006227, 'Murgh Noor-E-Malai', 'murgh noor-e-malai', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh noor-e-malai');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006227, canonical_dish_id, 'en', 'Murgh Noor-E-Malai', 'murgh noor-e-malai', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh noor-e-malai'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh noor-e-malai' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006228, 'Murgh Cilantro Tikka', 'murgh cilantro tikka', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh cilantro tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006228, canonical_dish_id, 'en', 'Murgh Cilantro Tikka', 'murgh cilantro tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh cilantro tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh cilantro tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006229, 'Hyderabadi Nizami Kabab', 'hyderabadi nizami kabab', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hyderabadi nizami kabab');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006229, canonical_dish_id, 'en', 'Hyderabadi Nizami Kabab', 'hyderabadi nizami kabab', 'primary'
    FROM canonical_dish WHERE normalized_name = 'hyderabadi nizami kabab'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hyderabadi nizami kabab' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006230, 'Murgh Awadhi Cheese Kabab', 'murgh awadhi cheese kabab', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh awadhi cheese kabab');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006230, canonical_dish_id, 'en', 'Murgh Awadhi Cheese Kabab', 'murgh awadhi cheese kabab', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh awadhi cheese kabab'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh awadhi cheese kabab' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006231, 'Murgh-E-Siyah Mirch', 'murgh-e-siyah mirch', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh-e-siyah mirch');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006231, canonical_dish_id, 'en', 'Murgh-E-Siyah Mirch', 'murgh-e-siyah mirch', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh-e-siyah mirch'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh-e-siyah mirch' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006232, 'Murgh Dahi Lasooni Khaas', 'murgh dahi lasooni khaas', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh dahi lasooni khaas');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006232, canonical_dish_id, 'en', 'Murgh Dahi Lasooni Khaas', 'murgh dahi lasooni khaas', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh dahi lasooni khaas'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh dahi lasooni khaas' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006233, 'Murgh Nawabi Tangdi', 'murgh nawabi tangdi', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh nawabi tangdi');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006233, canonical_dish_id, 'en', 'Murgh Nawabi Tangdi', 'murgh nawabi tangdi', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh nawabi tangdi'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh nawabi tangdi' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006234, 'Murgh Moroccan Kabab', 'murgh moroccan kabab', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh moroccan kabab');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006234, canonical_dish_id, 'en', 'Murgh Moroccan Kabab', 'murgh moroccan kabab', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh moroccan kabab'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh moroccan kabab' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006235, 'Kashmiri Tandoori Murgh', 'kashmiri tandoori murgh', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kashmiri tandoori murgh');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006235, canonical_dish_id, 'en', 'Kashmiri Tandoori Murgh', 'kashmiri tandoori murgh', 'primary'
    FROM canonical_dish WHERE normalized_name = 'kashmiri tandoori murgh'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kashmiri tandoori murgh' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006236, 'Murgh Classic Tandoori Tikka', 'murgh classic tandoori tikka', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh classic tandoori tikka');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006236, canonical_dish_id, 'en', 'Murgh Classic Tandoori Tikka', 'murgh classic tandoori tikka', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh classic tandoori tikka'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh classic tandoori tikka' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006237, 'Murgh Peshawari Seekh Kabab', 'murgh peshawari seekh kabab', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh peshawari seekh kabab');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006237, canonical_dish_id, 'en', 'Murgh Peshawari Seekh Kabab', 'murgh peshawari seekh kabab', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh peshawari seekh kabab'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh peshawari seekh kabab' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006238, 'Murgh Angara Kabab', 'murgh angara kabab', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murgh angara kabab');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006238, canonical_dish_id, 'en', 'Murgh Angara Kabab', 'murgh angara kabab', 'primary'
    FROM canonical_dish WHERE normalized_name = 'murgh angara kabab'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'murgh angara kabab' AND name_type_code = 'primary');
    INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
    SELECT 400070006239, 'Smokery Special Kabab Platter', 'smokery special kabab platter', 'non_veg', v_protein_chicken
    WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'smokery special kabab platter');
    INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
    SELECT 400070006239, canonical_dish_id, 'en', 'Smokery Special Kabab Platter', 'smokery special kabab platter', 'primary'
    FROM canonical_dish WHERE normalized_name = 'smokery special kabab platter'
    AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'smokery special kabab platter' AND name_type_code = 'primary');

    -- ----------------------------------------------------------------------
    -- Menu items, variants, prices, provenance (335 items / 343 variants)
    -- ----------------------------------------------------------------------
    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006001, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'green salad'),
           'Green Salad', 'green salad', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006001, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006001, 400070006, 400070006, 400070006001, 400070006001, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006001, 400070006001, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006001, 400070006001, 89.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006002, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix raita'),
           'Mix Raita', 'mix raita', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006002, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006002, 400070006, 400070006, 400070006002, 400070006001, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006002, 400070006002, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006002, 400070006002, 69.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006003, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pineapple raita'),
           'Pineapple Raita', 'pineapple raita', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006003, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006003, 400070006, 400070006, 400070006003, 400070006001, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006003, 400070006003, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006003, 400070006003, 69.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006004, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'boondi raita'),
           'Boondi Raita', 'boondi raita', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006004, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006004, 400070006, 400070006, 400070006004, 400070006001, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006004, 400070006004, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006004, 400070006004, 69.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006005, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lassi'),
           'Lassi', 'lassi', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006005, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006005, 400070006, 400070006, 400070006005, 400070006001, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006005, 400070006005, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006005, 400070006005, 69.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006006, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter milk'),
           'Butter Milk', 'butter milk', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006006, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006006, 400070006, 400070006, 400070006006, 400070006001, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006006, 400070006006, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006006, 400070006006, 59.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006007, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roasted papad'),
           'Roasted Papad', 'roasted papad', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006007, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006007, 400070006, 400070006, 400070006007, 400070006001, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006007, 400070006007, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006007, 400070006007, 20.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006008, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fry papad'),
           'Fry Papad', 'fry papad', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006008, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006008, 400070006, 400070006, 400070006008, 400070006001, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006008, 400070006008, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006008, 400070006008, 25.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006009, 400070006, 400070006001,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'masala papad'),
           'Masala Papad', 'masala papad', 'Salad / Papad / Raita', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006009, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006009, 400070006, 400070006, 400070006009, 400070006001, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006009, 400070006009, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006009, 400070006009, 40.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006010, 400070006, 400070006002,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'gulab jamun'),
           'Gulab Jamun', 'gulab jamun', 'Dessert', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006010, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006010, 400070006, 400070006, 400070006010, 400070006002, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006010, 400070006010, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006010, 400070006010, 149.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006011, 400070006, 400070006002,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'khubani ka meetha'),
           'Khubani Ka Meetha', 'khubani ka meetha', 'Dessert', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006011, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006011, 400070006, 400070006, 400070006011, 400070006002, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006011, 400070006011, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006011, 400070006011, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006012, 400070006, 400070006002,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tub tim krob'),
           'Tub Tim Krob', 'tub tim krob', 'Dessert', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006012, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006012, 400070006, 400070006, 400070006012, 400070006002, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006012, 400070006012, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006012, 400070006012, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006013, 400070006, 400070006003,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'package drinking water'),
           'Package Drinking Water', 'package drinking water', 'Beverages', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006013, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006013, 400070006, 400070006, 400070006013, 400070006003, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006013, 400070006013, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006013, 400070006013, 30.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006014, 400070006, 400070006003,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'soft drink'),
           'Soft Drink', 'soft drink', 'Beverages', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006014, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006014, 400070006, 400070006, 400070006014, 400070006003, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006014, 400070006014, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006014, 400070006014, 60.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006015, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean pot'),
           'Korean Pot', 'korean pot', 'Thai Curries / Chinese Pot', 'veg', NULL, '2de051aa503771ce8d003424ae0ba615', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006015, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006015, 400070006, 400070006, 400070006015, 400070006004, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006015, 400070006015, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006015, 400070006015, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006016, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean pot'),
           'Korean Pot', 'korean pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, '2de051aa503771ce8d003424ae0ba615', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006016, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006016, 400070006, 400070006, 400070006016, 400070006004, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006016, 400070006016, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006016, 400070006016, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006017, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean pot'),
           'Korean Pot', 'korean pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, '2de051aa503771ce8d003424ae0ba615', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006017, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006017, 400070006, 400070006, 400070006017, 400070006004, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006017, 400070006017, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006017, 400070006017, 429.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006018, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'oyster chilli pot'),
           'Oyster Chilli Pot', 'oyster chilli pot', 'Thai Curries / Chinese Pot', 'veg', NULL, '543aed5bf8eb00405642c2c550a7ee53', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006018, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006018, 400070006, 400070006, 400070006018, 400070006004, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006018, 400070006018, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006018, 400070006018, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006019, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'oyster chilli pot'),
           'Oyster Chilli Pot', 'oyster chilli pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, '543aed5bf8eb00405642c2c550a7ee53', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006019, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006019, 400070006, 400070006, 400070006019, 400070006004, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006019, 400070006019, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006019, 400070006019, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006020, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'oyster chilli pot'),
           'Oyster Chilli Pot', 'oyster chilli pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, '543aed5bf8eb00405642c2c550a7ee53', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006020, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006020, 400070006, 400070006, 400070006020, 400070006004, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006020, 400070006020, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006020, 400070006020, 429.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006021, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sapo pot'),
           'Sapo Pot', 'sapo pot', 'Thai Curries / Chinese Pot', 'veg', NULL, 'e7e64bb76ce313ced60c9b6eccce9cae', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006021, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006021, 400070006, 400070006, 400070006021, 400070006004, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006021, 400070006021, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006021, 400070006021, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006022, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sapo pot'),
           'Sapo Pot', 'sapo pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'e7e64bb76ce313ced60c9b6eccce9cae', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006022, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006022, 400070006, 400070006, 400070006022, 400070006004, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006022, 400070006022, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006022, 400070006022, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006023, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sapo pot'),
           'Sapo Pot', 'sapo pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'e7e64bb76ce313ced60c9b6eccce9cae', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006023, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006023, 400070006, 400070006, 400070006023, 400070006004, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006023, 400070006023, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006023, 400070006023, 429.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006024, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel chilli pot'),
           'Caramel Chilli Pot', 'caramel chilli pot', 'Thai Curries / Chinese Pot', 'veg', NULL, 'a1132c71c7bdeadab1bacf28ed3d21df', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006024, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006024, 400070006, 400070006, 400070006024, 400070006004, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006024, 400070006024, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006024, 400070006024, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006025, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel chilli pot'),
           'Caramel Chilli Pot', 'caramel chilli pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'a1132c71c7bdeadab1bacf28ed3d21df', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006025, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006025, 400070006, 400070006, 400070006025, 400070006004, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006025, 400070006025, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006025, 400070006025, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006026, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel chilli pot'),
           'Caramel Chilli Pot', 'caramel chilli pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'a1132c71c7bdeadab1bacf28ed3d21df', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006026, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006026, 400070006, 400070006, 400070006026, 400070006004, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006026, 400070006026, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006026, 400070006026, 429.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006027, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot basil pot'),
           'Hot Basil Pot', 'hot basil pot', 'Thai Curries / Chinese Pot', 'veg', NULL, 'e2d4ae520e3bb116da3bee664399eaec', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006027, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006027, 400070006, 400070006, 400070006027, 400070006004, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006027, 400070006027, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006027, 400070006027, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006028, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot basil pot'),
           'Hot Basil Pot', 'hot basil pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'e2d4ae520e3bb116da3bee664399eaec', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006028, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006028, 400070006, 400070006, 400070006028, 400070006004, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006028, 400070006028, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006028, 400070006028, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006029, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot basil pot'),
           'Hot Basil Pot', 'hot basil pot', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'e2d4ae520e3bb116da3bee664399eaec', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006029, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006029, 400070006, 400070006, 400070006029, 400070006004, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006029, 400070006029, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006029, 400070006029, 429.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006030, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai green curry'),
           'Thai Green Curry', 'thai green curry', 'Thai Curries / Chinese Pot', 'veg', NULL, 'ffb6ef88b0bca0d04fdde51b78ddb49f', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006030, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006030, 400070006, 400070006, 400070006030, 400070006004, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006030, 400070006030, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006030, 400070006030, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006031, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai green curry'),
           'Thai Green Curry', 'thai green curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'ffb6ef88b0bca0d04fdde51b78ddb49f', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006031, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006031, 400070006, 400070006, 400070006031, 400070006004, 17);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006031, 400070006031, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006031, 400070006031, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006032, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai green curry'),
           'Thai Green Curry', 'thai green curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'ffb6ef88b0bca0d04fdde51b78ddb49f', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006032, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006032, 400070006, 400070006, 400070006032, 400070006004, 18);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006032, 400070006032, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006032, 400070006032, 489.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006033, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai red curry'),
           'Thai Red Curry', 'thai red curry', 'Thai Curries / Chinese Pot', 'veg', NULL, '66fd69eafadb9affd9865b61b968a954', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006033, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006033, 400070006, 400070006, 400070006033, 400070006004, 19);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006033, 400070006033, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006033, 400070006033, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006034, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai red curry'),
           'Thai Red Curry', 'thai red curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, '66fd69eafadb9affd9865b61b968a954', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006034, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006034, 400070006, 400070006, 400070006034, 400070006004, 20);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006034, 400070006034, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006034, 400070006034, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006035, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai red curry'),
           'Thai Red Curry', 'thai red curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, '66fd69eafadb9affd9865b61b968a954', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006035, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006035, 400070006, 400070006, 400070006035, 400070006004, 21);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006035, 400070006035, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006035, 400070006035, 489.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006036, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapuri curry'),
           'Singapuri Curry', 'singapuri curry', 'Thai Curries / Chinese Pot', 'veg', NULL, 'cc17c9c1c3d9487bb3dd73aa3d70cfa8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006036, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006036, 400070006, 400070006, 400070006036, 400070006004, 22);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006036, 400070006036, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006036, 400070006036, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006037, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapuri curry'),
           'Singapuri Curry', 'singapuri curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'cc17c9c1c3d9487bb3dd73aa3d70cfa8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006037, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006037, 400070006, 400070006, 400070006037, 400070006004, 23);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006037, 400070006037, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006037, 400070006037, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006038, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapuri curry'),
           'Singapuri Curry', 'singapuri curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'cc17c9c1c3d9487bb3dd73aa3d70cfa8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006038, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006038, 400070006, 400070006, 400070006038, 400070006004, 24);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006038, 400070006038, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006038, 400070006038, 489.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006039, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'khao suey curry'),
           'Khao Suey Curry', 'khao suey curry', 'Thai Curries / Chinese Pot', 'veg', NULL, 'e146e3a657cd2b00b21e8cbd74d8d5f8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006039, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006039, 400070006, 400070006, 400070006039, 400070006004, 25);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006039, 400070006039, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006039, 400070006039, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006040, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'khao suey curry'),
           'Khao Suey Curry', 'khao suey curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'e146e3a657cd2b00b21e8cbd74d8d5f8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006040, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006040, 400070006, 400070006, 400070006040, 400070006004, 26);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006040, 400070006040, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006040, 400070006040, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006041, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'khao suey curry'),
           'Khao Suey Curry', 'khao suey curry', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'e146e3a657cd2b00b21e8cbd74d8d5f8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006041, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006041, 400070006, 400070006, 400070006041, 400070006004, 27);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006041, 400070006041, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006041, 400070006041, 489.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006042, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery burma rice'),
           'Smokery Burma Rice', 'smokery burma rice', 'Thai Curries / Chinese Pot', 'veg', NULL, 'e0baa0e055647dae12ee9ca5aee6e5f8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006042, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006042, 400070006, 400070006, 400070006042, 400070006004, 28);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006042, 400070006042, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006042, 400070006042, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006043, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery burma rice'),
           'Smokery Burma Rice', 'smokery burma rice', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_chicken, 'e0baa0e055647dae12ee9ca5aee6e5f8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006043, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006043, 400070006, 400070006, 400070006043, 400070006004, 29);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006043, 400070006043, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006043, 400070006043, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006044, 400070006, 400070006004,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery burma rice'),
           'Smokery Burma Rice', 'smokery burma rice', 'Thai Curries / Chinese Pot', 'non_veg', v_protein_seafood, 'e0baa0e055647dae12ee9ca5aee6e5f8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006044, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006044, 400070006, 400070006, 400070006044, 400070006004, 30);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006044, 400070006044, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006044, 400070006044, 489.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006045, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'nasi goreng'),
           'Nasi Goreng', 'nasi goreng', 'Rice & Noodles', 'veg', NULL, '21c405458d111f161774a733d22ccaed', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006045, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006045, 400070006, 400070006, 400070006045, 400070006005, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006045, 400070006045, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006045, 400070006045, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006046, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'nasi goreng'),
           'Nasi Goreng', 'nasi goreng', 'Rice & Noodles', 'non_veg', v_protein_chicken, '21c405458d111f161774a733d22ccaed', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006046, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006046, 400070006, 400070006, 400070006046, 400070006005, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006046, 400070006046, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006046, 400070006046, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006047, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'nasi goreng'),
           'Nasi Goreng', 'nasi goreng', 'Rice & Noodles', 'non_veg', v_protein_seafood, '21c405458d111f161774a733d22ccaed', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006047, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006047, 400070006, 400070006, 400070006047, 400070006005, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006047, 400070006047, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006047, 400070006047, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006048, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore fried rice'),
           'Singapore Fried Rice', 'singapore fried rice', 'Rice & Noodles', 'veg', NULL, '12e53a35e2e4ffdfd15d52cf1a8754b8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006048, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006048, 400070006, 400070006, 400070006048, 400070006005, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006048, 400070006048, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006048, 400070006048, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006049, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore fried rice'),
           'Singapore Fried Rice', 'singapore fried rice', 'Rice & Noodles', 'non_veg', v_protein_chicken, '12e53a35e2e4ffdfd15d52cf1a8754b8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006049, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006049, 400070006, 400070006, 400070006049, 400070006005, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006049, 400070006049, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006049, 400070006049, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006050, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore fried rice'),
           'Singapore Fried Rice', 'singapore fried rice', 'Rice & Noodles', 'non_veg', v_protein_seafood, '12e53a35e2e4ffdfd15d52cf1a8754b8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006050, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006050, 400070006, 400070006, 400070006050, 400070006005, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006050, 400070006050, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006050, 400070006050, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006051, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli garlic fried rice'),
           'Chilli Garlic Fried Rice', 'chilli garlic fried rice', 'Rice & Noodles', 'veg', NULL, '33fa58c0de5324752726814e6ed156cd', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006051, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006051, 400070006, 400070006, 400070006051, 400070006005, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006051, 400070006051, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006051, 400070006051, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006052, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli garlic fried rice'),
           'Chilli Garlic Fried Rice', 'chilli garlic fried rice', 'Rice & Noodles', 'non_veg', v_protein_chicken, '33fa58c0de5324752726814e6ed156cd', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006052, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006052, 400070006, 400070006, 400070006052, 400070006005, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006052, 400070006052, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006052, 400070006052, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006053, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli garlic fried rice'),
           'Chilli Garlic Fried Rice', 'chilli garlic fried rice', 'Rice & Noodles', 'non_veg', v_protein_seafood, '33fa58c0de5324752726814e6ed156cd', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006053, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006053, 400070006, 400070006, 400070006053, 400070006005, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006053, 400070006053, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006053, 400070006053, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006054, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'burnt garlic fried rice'),
           'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'Rice & Noodles', 'veg', NULL, '77d999eef954d22f6034f0349867b4c5', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006054, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006054, 400070006, 400070006, 400070006054, 400070006005, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006054, 400070006054, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006054, 400070006054, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006055, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'burnt garlic fried rice'),
           'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'Rice & Noodles', 'non_veg', v_protein_chicken, '77d999eef954d22f6034f0349867b4c5', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006055, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006055, 400070006, 400070006, 400070006055, 400070006005, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006055, 400070006055, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006055, 400070006055, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006056, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'burnt garlic fried rice'),
           'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'Rice & Noodles', 'non_veg', v_protein_seafood, '77d999eef954d22f6034f0349867b4c5', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006056, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006056, 400070006, 400070006, 400070006056, 400070006005, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006056, 400070006056, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006056, 400070006056, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006057, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'schezwan fried rice'),
           'Schezwan Fried Rice', 'schezwan fried rice', 'Rice & Noodles', 'veg', NULL, '0a59f4f8d389ae166280a02d1b6356f3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006057, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006057, 400070006, 400070006, 400070006057, 400070006005, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006057, 400070006057, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006057, 400070006057, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006058, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'schezwan fried rice'),
           'Schezwan Fried Rice', 'schezwan fried rice', 'Rice & Noodles', 'non_veg', v_protein_chicken, '0a59f4f8d389ae166280a02d1b6356f3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006058, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006058, 400070006, 400070006, 400070006058, 400070006005, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006058, 400070006058, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006058, 400070006058, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006059, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'schezwan fried rice'),
           'Schezwan Fried Rice', 'schezwan fried rice', 'Rice & Noodles', 'non_veg', v_protein_seafood, '0a59f4f8d389ae166280a02d1b6356f3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006059, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006059, 400070006, 400070006, 400070006059, 400070006005, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006059, 400070006059, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006059, 400070006059, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006060, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'classic fried rice'),
           'Classic Fried Rice', 'classic fried rice', 'Rice & Noodles', 'veg', NULL, '356a862f0d439ee5b1cbbee3bb6b8124', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006060, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006060, 400070006, 400070006, 400070006060, 400070006005, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006060, 400070006060, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006060, 400070006060, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006061, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'classic fried rice'),
           'Classic Fried Rice', 'classic fried rice', 'Rice & Noodles', 'non_veg', v_protein_chicken, '356a862f0d439ee5b1cbbee3bb6b8124', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006061, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006061, 400070006, 400070006, 400070006061, 400070006005, 17);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006061, 400070006061, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006061, 400070006061, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006062, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'classic fried rice'),
           'Classic Fried Rice', 'classic fried rice', 'Rice & Noodles', 'non_veg', v_protein_seafood, '356a862f0d439ee5b1cbbee3bb6b8124', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006062, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006062, 400070006, 400070006, 400070006062, 400070006005, 18);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006062, 400070006062, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006062, 400070006062, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006063, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pad thai noodles'),
           'Pad Thai Noodles', 'pad thai noodles', 'Rice & Noodles', 'veg', NULL, '4bb9f17caf7d2b74c0ef42a8343f7daf', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006063, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006063, 400070006, 400070006, 400070006063, 400070006005, 19);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006063, 400070006063, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006063, 400070006063, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006064, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pad thai noodles'),
           'Pad Thai Noodles', 'pad thai noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, '4bb9f17caf7d2b74c0ef42a8343f7daf', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006064, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006064, 400070006, 400070006, 400070006064, 400070006005, 20);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006064, 400070006064, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006064, 400070006064, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006065, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pad thai noodles'),
           'Pad Thai Noodles', 'pad thai noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, '4bb9f17caf7d2b74c0ef42a8343f7daf', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006065, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006065, 400070006, 400070006, 400070006065, 400070006005, 21);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006065, 400070006065, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006065, 400070006065, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006066, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore noodles'),
           'Singapore Noodles', 'singapore noodles', 'Rice & Noodles', 'veg', NULL, 'b6b23fa4e80f06a6453effba9099f1d0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006066, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006066, 400070006, 400070006, 400070006066, 400070006005, 22);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006066, 400070006066, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006066, 400070006066, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006067, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore noodles'),
           'Singapore Noodles', 'singapore noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, 'b6b23fa4e80f06a6453effba9099f1d0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006067, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006067, 400070006, 400070006, 400070006067, 400070006005, 23);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006067, 400070006067, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006067, 400070006067, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006068, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore noodles'),
           'Singapore Noodles', 'singapore noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, 'b6b23fa4e80f06a6453effba9099f1d0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006068, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006068, 400070006, 400070006, 400070006068, 400070006005, 24);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006068, 400070006068, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006068, 400070006068, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006069, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'drunken noodles'),
           'Drunken Noodles', 'drunken noodles', 'Rice & Noodles', 'veg', NULL, 'd33a532597cf227e3e557d7dc32eb44b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006069, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006069, 400070006, 400070006, 400070006069, 400070006005, 25);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006069, 400070006069, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006069, 400070006069, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006070, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'drunken noodles'),
           'Drunken Noodles', 'drunken noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, 'd33a532597cf227e3e557d7dc32eb44b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006070, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006070, 400070006, 400070006, 400070006070, 400070006005, 26);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006070, 400070006070, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006070, 400070006070, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006071, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'drunken noodles'),
           'Drunken Noodles', 'drunken noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, 'd33a532597cf227e3e557d7dc32eb44b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006071, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006071, 400070006, 400070006, 400070006071, 400070006005, 27);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006071, 400070006071, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006071, 400070006071, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006072, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli garlic noodles'),
           'Chilli Garlic Noodles', 'chilli garlic noodles', 'Rice & Noodles', 'veg', NULL, '11a646ae2542caa2ddde51fe8ce5e8cc', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006072, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006072, 400070006, 400070006, 400070006072, 400070006005, 28);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006072, 400070006072, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006072, 400070006072, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006073, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli garlic noodles'),
           'Chilli Garlic Noodles', 'chilli garlic noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, '11a646ae2542caa2ddde51fe8ce5e8cc', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006073, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006073, 400070006, 400070006, 400070006073, 400070006005, 29);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006073, 400070006073, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006073, 400070006073, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006074, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli garlic noodles'),
           'Chilli Garlic Noodles', 'chilli garlic noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, '11a646ae2542caa2ddde51fe8ce5e8cc', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006074, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006074, 400070006, 400070006, 400070006074, 400070006005, 30);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006074, 400070006074, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006074, 400070006074, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006075, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'burnt garlic noodles'),
           'Burnt Garlic Noodles', 'burnt garlic noodles', 'Rice & Noodles', 'veg', NULL, '84e9fcc602a93c01a60ce786a2c0e82b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006075, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006075, 400070006, 400070006, 400070006075, 400070006005, 31);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006075, 400070006075, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006075, 400070006075, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006076, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'burnt garlic noodles'),
           'Burnt Garlic Noodles', 'burnt garlic noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, '84e9fcc602a93c01a60ce786a2c0e82b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006076, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006076, 400070006, 400070006, 400070006076, 400070006005, 32);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006076, 400070006076, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006076, 400070006076, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006077, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'burnt garlic noodles'),
           'Burnt Garlic Noodles', 'burnt garlic noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, '84e9fcc602a93c01a60ce786a2c0e82b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006077, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006077, 400070006, 400070006, 400070006077, 400070006005, 33);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006077, 400070006077, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006077, 400070006077, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006078, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pan fried noodles'),
           'Pan Fried Noodles', 'pan fried noodles', 'Rice & Noodles', 'veg', NULL, '8c787798d0943e8a2f66b0a624bd142b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006078, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006078, 400070006, 400070006, 400070006078, 400070006005, 34);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006078, 400070006078, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006078, 400070006078, 269.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006079, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pan fried noodles'),
           'Pan Fried Noodles', 'pan fried noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, '8c787798d0943e8a2f66b0a624bd142b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006079, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006079, 400070006, 400070006, 400070006079, 400070006005, 35);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006079, 400070006079, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006079, 400070006079, 309.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006080, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pan fried noodles'),
           'Pan Fried Noodles', 'pan fried noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, '8c787798d0943e8a2f66b0a624bd142b', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006080, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006080, 400070006, 400070006, 400070006080, 400070006005, 36);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006080, 400070006080, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006080, 400070006080, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006081, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'szechuan noodles'),
           'Szechuan Noodles', 'szechuan noodles', 'Rice & Noodles', 'veg', NULL, '3c58a7f0f00817e3bad34f5388677523', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006081, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006081, 400070006, 400070006, 400070006081, 400070006005, 37);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006081, 400070006081, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006081, 400070006081, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006082, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'szechuan noodles'),
           'Szechuan Noodles', 'szechuan noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, '3c58a7f0f00817e3bad34f5388677523', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006082, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006082, 400070006, 400070006, 400070006082, 400070006005, 38);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006082, 400070006082, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006082, 400070006082, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006083, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'szechuan noodles'),
           'Szechuan Noodles', 'szechuan noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, '3c58a7f0f00817e3bad34f5388677523', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006083, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006083, 400070006, 400070006, 400070006083, 400070006005, 39);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006083, 400070006083, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006083, 400070006083, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006084, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'malaysian noodles'),
           'Malaysian Noodles', 'malaysian noodles', 'Rice & Noodles', 'veg', NULL, '387720d426ac0371a64be75c8f15d8ee', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006084, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006084, 400070006, 400070006, 400070006084, 400070006005, 40);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006084, 400070006084, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006084, 400070006084, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006085, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'malaysian noodles'),
           'Malaysian Noodles', 'malaysian noodles', 'Rice & Noodles', 'non_veg', v_protein_chicken, '387720d426ac0371a64be75c8f15d8ee', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006085, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006085, 400070006, 400070006, 400070006085, 400070006005, 41);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006085, 400070006085, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006085, 400070006085, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006086, 400070006, 400070006005,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'malaysian noodles'),
           'Malaysian Noodles', 'malaysian noodles', 'Rice & Noodles', 'non_veg', v_protein_seafood, '387720d426ac0371a64be75c8f15d8ee', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006086, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006086, 400070006, 400070006, 400070006086, 400070006005, 42);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006086, 400070006086, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006086, 400070006086, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006087, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pad krapow gai in wonton cups'),
           'Pad Krapow Gai in Wonton Cups', 'pad krapow gai in wonton cups', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006087, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006087, 400070006, 400070006, 400070006087, 400070006006, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006087, 400070006087, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006087, 400070006087, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006088, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'koji chicken'),
           'Koji Chicken', 'koji chicken', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006088, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006088, 400070006, 400070006, 400070006088, 400070006006, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006088, 400070006088, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006088, 400070006088, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006089, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crispy chicken schezwan pepper'),
           'Crispy Chicken Schezwan Pepper', 'crispy chicken schezwan pepper', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006089, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006089, 400070006, 400070006, 400070006089, 400070006006, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006089, 400070006089, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006089, 400070006089, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006090, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'assorted pepper chicken chilli'),
           'Assorted Pepper Chicken Chilli', 'assorted pepper chicken chilli', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006090, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006090, 400070006, 400070006, 400070006090, 400070006006, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006090, 400070006090, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006090, 400070006090, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006091, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'ginger chicken'),
           'Ginger Chicken', 'ginger chicken', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006091, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006091, 400070006, 400070006, 400070006091, 400070006006, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006091, 400070006091, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006091, 400070006091, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006092, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'exotic thai chicken'),
           'Exotic Thai Chicken', 'exotic thai chicken', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006092, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006092, 400070006, 400070006, 400070006092, 400070006006, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006092, 400070006092, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006092, 400070006092, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006093, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken in japanese sauce'),
           'Chicken in Japanese Sauce', 'chicken in japanese sauce', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006093, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006093, 400070006, 400070006, 400070006093, 400070006006, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006093, 400070006093, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006093, 400070006093, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006094, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli oyster chicken'),
           'Chilli Oyster Chicken', 'chilli oyster chicken', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006094, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006094, 400070006, 400070006, 400070006094, 400070006006, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006094, 400070006094, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006094, 400070006094, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006095, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'honey mustard chicken'),
           'Honey Mustard Chicken', 'honey mustard chicken', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006095, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006095, 400070006, 400070006, 400070006095, 400070006006, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006095, 400070006095, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006095, 400070006095, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006096, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'orange celery chicken'),
           'Orange Celery Chicken', 'orange celery chicken', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006096, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006096, 400070006, 400070006, 400070006096, 400070006006, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006096, 400070006096, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006096, 400070006096, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006097, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok fried chicken in salt & pepper'),
           'Wok Fried Chicken in Salt & Pepper', 'wok fried chicken in salt & pepper', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006097, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006097, 400070006, 400070006, 400070006097, 400070006006, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006097, 400070006097, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006097, 400070006097, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006098, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean fried chicken wings in spicy gochujang'),
           'Korean Fried Chicken Wings in Spicy Gochujang', 'korean fried chicken wings in spicy gochujang', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006098, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006098, 400070006, 400070006, 400070006098, 400070006006, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006098, 400070006098, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006098, 400070006098, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006099, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'popcorn chicken in korean sauce'),
           'Popcorn Chicken in Korean Sauce', 'popcorn chicken in korean sauce', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006099, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006099, 400070006, 400070006, 400070006099, 400070006006, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006099, 400070006099, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006099, 400070006099, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006100, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'poh pia tod'),
           'Poh Pia Tod', 'poh pia tod', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006100, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006100, 400070006, 400070006, 400070006100, 400070006006, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006100, 400070006100, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006100, 400070006100, 319.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006101, 400070006, 400070006006,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lollipop'),
           'Chicken Lollipop', 'chicken lollipop', 'Chinese Starters Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006101, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006101, 400070006, 400070006, 400070006101, 400070006006, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006101, 400070006101, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006101, 400070006101, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006102, 400070006, 400070006007,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton peshwari seekh kabab'),
           'Mutton Peshwari Seekh Kabab', 'mutton peshwari seekh kabab', 'Tandoor Lamb Kabab', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006102, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006102, 400070006, 400070006, 400070006102, 400070006007, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006102, 400070006102, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006102, 400070006102, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006103, 400070006, 400070006007,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'zaika-e-nawabi boti'),
           'Zaika-E-Nawabi Boti', 'zaika-e-nawabi boti', 'Tandoor Lamb Kabab', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006103, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006103, 400070006, 400070006, 400070006103, 400070006007, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006103, 400070006103, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006103, 400070006103, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006104, 400070006, 400070006007,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton sikandari raan-e-boti'),
           'Mutton Sikandari Raan-E-Boti', 'mutton sikandari raan-e-boti', 'Tandoor Lamb Kabab', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006104, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006104, 400070006, 400070006, 400070006104, 400070006007, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006104, 400070006104, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006104, 400070006104, 2099.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006105, 400070006, 400070006007,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton nalli barra'),
           'Mutton Nalli Barra', 'mutton nalli barra', 'Tandoor Lamb Kabab', 'non_veg', v_protein_mutton, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006105, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006105, 400070006, 400070006, 400070006105, 400070006007, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006105, 400070006105, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006105, 400070006105, 1049.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006106, 400070006, 400070006007,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton chaap barra'),
           'Mutton Chaap Barra', 'mutton chaap barra', 'Tandoor Lamb Kabab', 'non_veg', v_protein_mutton, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006106, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006106, 400070006, 400070006, 400070006106, 400070006007, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006106, 400070006106, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006106, 400070006106, 799.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006107, 400070006, 400070006007,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery special lamb platter'),
           'Smokery Special Lamb Platter', 'smokery special lamb platter', 'Tandoor Lamb Kabab', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006107, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006107, 400070006, 400070006, 400070006107, 400070006007, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006107, 400070006107, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006107, 400070006107, 2499.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006108, 400070006, 400070006008,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'konjee crispy lamb'),
           'Konjee Crispy Lamb', 'konjee crispy lamb', 'Chinese Lamb Starters', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006108, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006108, 400070006, 400070006, 400070006108, 400070006008, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006108, 400070006108, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006108, 400070006108, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006109, 400070006, 400070006008,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok fried lamb with schezwan pepper'),
           'Wok Fried Lamb with Schezwan Pepper', 'wok fried lamb with schezwan pepper', 'Chinese Lamb Starters', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006109, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006109, 400070006, 400070006, 400070006109, 400070006008, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006109, 400070006109, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006109, 400070006109, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006110, 400070006, 400070006008,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crispy lamb with dry red chilli & garlic'),
           'Crispy Lamb with Dry Red Chilli & Garlic', 'crispy lamb with dry red chilli & garlic', 'Chinese Lamb Starters', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006110, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006110, 400070006, 400070006, 400070006110, 400070006008, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006110, 400070006110, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006110, 400070006110, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006111, 400070006, 400070006008,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mongolian lamb stir-fry'),
           'Mongolian Lamb Stir-Fry', 'mongolian lamb stir-fry', 'Chinese Lamb Starters', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006111, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006111, 400070006, 400070006, 400070006111, 400070006008, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006111, 400070006111, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006111, 400070006111, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006112, 400070006, 400070006009,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fish ajwain tikka'),
           'Fish Ajwain Tikka', 'fish ajwain tikka', 'Seafood Tandoori Starter', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006112, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006112, 400070006, 400070006, 400070006112, 400070006009, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006112, 400070006112, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006112, 400070006112, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006113, 400070006, 400070006009,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tawa fried fish'),
           'Tawa Fried Fish', 'tawa fried fish', 'Seafood Tandoori Starter', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006113, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006113, 400070006, 400070006, 400070006113, 400070006009, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006113, 400070006113, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006113, 400070006113, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006114, 400070006, 400070006009,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'jhinga dum nisha'),
           'Jhinga Dum Nisha', 'jhinga dum nisha', 'Seafood Tandoori Starter', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006114, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006114, 400070006, 400070006, 400070006114, 400070006009, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006114, 400070006114, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006114, 400070006114, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006115, 400070006, 400070006009,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori schezwan prawns'),
           'Tandoori Schezwan Prawns', 'tandoori schezwan prawns', 'Seafood Tandoori Starter', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006115, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006115, 400070006, 400070006, 400070006115, 400070006009, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006115, 400070006115, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006115, 400070006115, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006116, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi mutton dum biryani'),
           'Hyderabadi Mutton Dum Biryani', 'hyderabadi mutton dum biryani', 'Biryani''s & Rice''s', 'non_veg', v_protein_mutton, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006116, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006116, 400070006, 400070006, 400070006116, 400070006010, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006116, 400070006116, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006116, 400070006116, 499.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006117, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi chicken dum biryani'),
           'Hyderabadi Chicken Dum Biryani', 'hyderabadi chicken dum biryani', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006117, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006117, 400070006, 400070006, 400070006117, 400070006010, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006117, 400070006117, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006117, 400070006117, 349.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006118, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori butter chicken biryani'),
           'Tandoori Butter Chicken Biryani', 'tandoori butter chicken biryani', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006118, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006118, 400070006, 400070006, 400070006118, 400070006010, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006118, 400070006118, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006118, 400070006118, 349.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006119, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh afghani biryani'),
           'Murgh Afghani Biryani', 'murgh afghani biryani', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006119, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006119, 400070006, 400070006, 400070006119, 400070006010, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006119, 400070006119, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006119, 400070006119, 349.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006120, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns biryani'),
           'Prawns Biryani', 'prawns biryani', 'Biryani''s & Rice''s', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006120, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006120, 400070006, 400070006, 400070006120, 400070006010, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006120, 400070006120, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006120, 400070006120, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006121, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vegetable biryani'),
           'Vegetable Biryani', 'vegetable biryani', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006121, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006121, 400070006, 400070006, 400070006121, 400070006010, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006121, 400070006121, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006121, 400070006121, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006122, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani'),
           'Paneer Tikka Biryani', 'paneer tikka biryani', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006122, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006122, 400070006, 400070006, 400070006122, 400070006010, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006122, 400070006122, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006122, 400070006122, 349.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006123, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'green peas pulao'),
           'Green Peas Pulao', 'green peas pulao', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006123, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006123, 400070006, 400070006, 400070006123, 400070006010, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006123, 400070006123, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006123, 400070006123, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006124, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vegetable pulao'),
           'Vegetable Pulao', 'vegetable pulao', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006124, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006124, 400070006, 400070006, 400070006124, 400070006010, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006124, 400070006124, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006124, 400070006124, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006125, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'biryani rice'),
           'Biryani Rice', 'biryani rice', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006125, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006125, 400070006, 400070006, 400070006125, 400070006010, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006125, 400070006125, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006125, 400070006125, 149.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006126, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'jeera rice'),
           'Jeera Rice', 'jeera rice', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006126, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006126, 400070006, 400070006, 400070006126, 400070006010, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006126, 400070006126, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006126, 400070006126, 149.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006127, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'steamed rice'),
           'Steamed Rice', 'steamed rice', 'Biryani''s & Rice''s', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006127, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006127, 400070006, 400070006, 400070006127, 400070006010, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006127, 400070006127, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006127, 400070006127, 139.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006128, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi mandi'),
           'Hyderabadi Mandi', 'hyderabadi mandi', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, '627057a64e1b1a52822e43a2238324d8', 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006128, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006128, 400070006, 400070006, 400070006128, 400070006010, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006128, 400070006128, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006128, 400070006128, 999.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006129, 400070006128, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006129, 400070006129, 1899.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006129, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi mandi'),
           'Hyderabadi Mandi', 'hyderabadi mandi', 'Biryani''s & Rice''s', 'non_veg', v_protein_mutton, '627057a64e1b1a52822e43a2238324d8', 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006129, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006129, 400070006, 400070006, 400070006129, 400070006010, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006130, 400070006129, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006130, 400070006130, 1299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006131, 400070006129, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006131, 400070006131, 2299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006130, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery raan mandi'),
           'Smokery Raan Mandi', 'smokery raan mandi', 'Biryani''s & Rice''s', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006130, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006130, 400070006, 400070006, 400070006130, 400070006010, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006132, 400070006130, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006132, 400070006132, 2399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006131, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh hyderabadi kabsa rice'),
           'Murgh Hyderabadi Kabsa Rice', 'murgh hyderabadi kabsa rice', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006131, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006131, 400070006, 400070006, 400070006131, 400070006010, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006133, 400070006131, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006133, 400070006133, 999.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006134, 400070006131, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006134, 400070006134, 1899.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006132, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'assorted chinese kabsa'),
           'Assorted Chinese Kabsa', 'assorted chinese kabsa', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006132, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006132, 400070006, 400070006, 400070006132, 400070006010, 17);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006135, 400070006132, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006135, 400070006135, 999.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006136, 400070006132, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006136, 400070006136, 1899.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006133, 400070006, 400070006010,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery special thaal'),
           'Smokery Special Thaal', 'smokery special thaal', 'Biryani''s & Rice''s', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006133, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006133, 400070006, 400070006, 400070006133, 400070006010, 18);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006137, 400070006133, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006137, 400070006137, 2499.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006138, 400070006133, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006138, 400070006138, 4499.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006134, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roti'),
           'Roti', 'roti', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006134, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006134, 400070006, 400070006, 400070006134, 400070006011, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006139, 400070006134, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006139, 400070006139, 30.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006135, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter roti'),
           'Butter Roti', 'butter roti', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006135, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006135, 400070006, 400070006, 400070006135, 400070006011, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006140, 400070006135, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006140, 400070006140, 35.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006136, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lacha paratha'),
           'Lacha Paratha', 'lacha paratha', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006136, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006136, 400070006, 400070006, 400070006136, 400070006011, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006141, 400070006136, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006141, 400070006141, 40.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006137, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'zaatar cheese naan'),
           'Zaatar Cheese Naan', 'zaatar cheese naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006137, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006137, 400070006, 400070006, 400070006137, 400070006011, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006142, 400070006137, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006142, 400070006142, 99.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006138, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'zaatar naan'),
           'Zaatar Naan', 'zaatar naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006138, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006138, 400070006, 400070006, 400070006138, 400070006011, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006143, 400070006138, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006143, 400070006143, 79.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006139, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'activated charcoal naan'),
           'Activated Charcoal Naan', 'activated charcoal naan', 'Tandoor Bread', 'veg', NULL, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006139, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006139, 400070006, 400070006, 400070006139, 400070006011, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006144, 400070006139, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006144, 400070006144, 79.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006140, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter naan'),
           'Butter Naan', 'butter naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006140, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006140, 400070006, 400070006, 400070006140, 400070006011, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006145, 400070006140, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006145, 400070006145, 40.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006141, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'naan'),
           'Naan', 'naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006141, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006141, 400070006, 400070006, 400070006141, 400070006011, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006146, 400070006141, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006146, 400070006146, 45.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006142, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'garlic naan'),
           'Garlic Naan', 'garlic naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006142, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006142, 400070006, 400070006, 400070006142, 400070006011, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006147, 400070006142, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006147, 400070006147, 60.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006143, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheese garlic naan'),
           'Cheese Garlic Naan', 'cheese garlic naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006143, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006143, 400070006, 400070006, 400070006143, 400070006011, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006148, 400070006143, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006148, 400070006148, 70.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006144, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli naan'),
           'Chilli Naan', 'chilli naan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006144, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006144, 400070006, 400070006, 400070006144, 400070006011, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006149, 400070006144, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006149, 400070006149, 45.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006145, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kulcha'),
           'Kulcha', 'kulcha', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006145, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006145, 400070006, 400070006, 400070006145, 400070006011, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006150, 400070006145, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006150, 400070006150, 45.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006146, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli kulcha'),
           'Chilli Kulcha', 'chilli kulcha', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006146, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006146, 400070006, 400070006, 400070006146, 400070006011, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006151, 400070006146, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006151, 400070006151, 45.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006147, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'taftan'),
           'Taftan', 'taftan', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006147, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006147, 400070006, 400070006, 400070006147, 400070006011, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006152, 400070006147, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006152, 400070006152, 70.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006148, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'rumali roti'),
           'Rumali Roti', 'rumali roti', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006148, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006148, 400070006, 400070006, 400070006148, 400070006011, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006153, 400070006148, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006153, 400070006153, 40.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006149, 400070006, 400070006011,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori basket'),
           'Tandoori Basket', 'tandoori basket', 'Tandoor Bread', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006149, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006149, 400070006, 400070006, 400070006149, 400070006011, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006154, 400070006149, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006154, 400070006154, 179.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006150, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter chicken'),
           'Butter Chicken', 'butter chicken', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006150, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006150, 400070006, 400070006, 400070006150, 400070006012, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006155, 400070006150, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006155, 400070006155, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006151, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh kadai'),
           'Murgh Kadai', 'murgh kadai', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006151, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006151, 400070006, 400070006, 400070006151, 400070006012, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006156, 400070006151, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006156, 400070006156, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006152, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh adraki'),
           'Murgh Adraki', 'murgh adraki', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006152, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006152, 400070006, 400070006, 400070006152, 400070006012, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006157, 400070006152, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006157, 400070006157, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006153, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh hari mirch ka kheema'),
           'Murgh Hari Mirch Ka Kheema', 'murgh hari mirch ka kheema', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006153, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006153, 400070006, 400070006, 400070006153, 400070006012, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006158, 400070006153, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006158, 400070006158, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006154, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh mumtaz'),
           'Murgh Mumtaz', 'murgh mumtaz', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006154, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006154, 400070006, 400070006, 400070006154, 400070006012, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006159, 400070006154, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006159, 400070006159, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006155, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tikka masala'),
           'Chicken Tikka Masala', 'chicken tikka masala', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006155, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006155, 400070006, 400070006, 400070006155, 400070006012, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006160, 400070006155, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006160, 400070006160, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006156, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken farcha'),
           'Chicken Farcha', 'chicken farcha', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006156, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006156, 400070006, 400070006, 400070006156, 400070006012, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006161, 400070006156, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006161, 400070006161, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006157, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lababdar'),
           'Chicken Lababdar', 'chicken lababdar', 'Indian Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006157, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006157, 400070006, 400070006, 400070006157, 400070006012, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006162, 400070006157, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006162, 400070006162, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006158, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'anda curry'),
           'Anda Curry', 'anda curry', 'Indian Main Course', 'egg', NULL, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006158, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006158, 400070006, 400070006, 400070006158, 400070006012, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006163, 400070006158, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006163, 400070006163, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006159, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'nalli nihari'),
           'Nalli Nihari', 'nalli nihari', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006159, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006159, 400070006, 400070006, 400070006159, 400070006012, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006164, 400070006159, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006164, 400070006164, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006160, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton rogan josh'),
           'Mutton Rogan Josh', 'mutton rogan josh', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006160, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006160, 400070006, 400070006, 400070006160, 400070006012, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006165, 400070006160, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006165, 400070006165, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006161, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton pepper fried'),
           'Mutton Pepper Fried', 'mutton pepper fried', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006161, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006161, 400070006, 400070006, 400070006161, 400070006012, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006166, 400070006161, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006166, 400070006166, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006162, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton raan masala'),
           'Mutton Raan Masala', 'mutton raan masala', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006162, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006162, 400070006, 400070006, 400070006162, 400070006012, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006167, 400070006162, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006167, 400070006167, 2099.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006163, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton laal maas'),
           'Mutton Laal Maas', 'mutton laal maas', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006163, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006163, 400070006, 400070006, 400070006163, 400070006012, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006168, 400070006163, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006168, 400070006168, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006164, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton rezala'),
           'Mutton Rezala', 'mutton rezala', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006164, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006164, 400070006, 400070006, 400070006164, 400070006012, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006169, 400070006164, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006169, 400070006169, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006165, 400070006, 400070006012,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton rara'),
           'Mutton Rara', 'mutton rara', 'Indian Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006165, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006165, 400070006, 400070006, 400070006165, 400070006012, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006170, 400070006165, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006170, 400070006170, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006166, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kadai'),
           'Paneer Kadai', 'paneer kadai', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006166, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006166, 400070006, 400070006, 400070006166, 400070006013, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006171, 400070006166, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006171, 400070006171, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006167, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer jalfrezi'),
           'Paneer Jalfrezi', 'paneer jalfrezi', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006167, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006167, 400070006, 400070006, 400070006167, 400070006013, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006172, 400070006167, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006172, 400070006172, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006168, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer makhanwala'),
           'Paneer Makhanwala', 'paneer makhanwala', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006168, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006168, 400070006, 400070006, 400070006168, 400070006013, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006173, 400070006168, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006173, 400070006173, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006169, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka masala'),
           'Paneer Tikka Masala', 'paneer tikka masala', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006169, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006169, 400070006, 400070006, 400070006169, 400070006013, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006174, 400070006169, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006174, 400070006174, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006170, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'palak paneer'),
           'Palak Paneer', 'palak paneer', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006170, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006170, 400070006, 400070006, 400070006170, 400070006013, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006175, 400070006170, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006175, 400070006175, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006171, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'methi chaman'),
           'Methi Chaman', 'methi chaman', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006171, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006171, 400070006, 400070006, 400070006171, 400070006013, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006176, 400070006171, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006176, 400070006176, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006172, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix vegetable handi'),
           'Mix Vegetable Handi', 'mix vegetable handi', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006172, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006172, 400070006, 400070006, 400070006172, 400070006013, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006177, 400070006172, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006177, 400070006177, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006173, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vegetable nawabi khorma'),
           'Vegetable Nawabi Khorma', 'vegetable nawabi khorma', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006173, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006173, 400070006, 400070006, 400070006173, 400070006013, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006178, 400070006173, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006178, 400070006178, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006174, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vegetable kadai'),
           'Vegetable Kadai', 'vegetable kadai', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006174, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006174, 400070006, 400070006, 400070006174, 400070006013, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006179, 400070006174, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006179, 400070006179, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006175, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom masala'),
           'Mushroom Masala', 'mushroom masala', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006175, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006175, 400070006, 400070006, 400070006175, 400070006013, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006180, 400070006175, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006180, 400070006180, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006176, 400070006, 400070006013,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'methi matar malai'),
           'Methi Matar Malai', 'methi matar malai', 'Indian Vegetables Main Course', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006176, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006176, 400070006, 400070006, 400070006176, 400070006013, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006181, 400070006176, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006181, 400070006181, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006177, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli oyster sauce'),
           'Chilli Oyster Sauce', 'chilli oyster sauce', 'Chinese Main Course', 'veg', NULL, 'f96f740c7793a4a7722e8a5ee76de11a', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006177, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006177, 400070006, 400070006, 400070006177, 400070006014, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006182, 400070006177, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006182, 400070006182, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006178, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli oyster sauce'),
           'Chilli Oyster Sauce', 'chilli oyster sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, 'f96f740c7793a4a7722e8a5ee76de11a', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006178, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006178, 400070006, 400070006, 400070006178, 400070006014, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006183, 400070006178, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006183, 400070006183, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006179, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli oyster sauce'),
           'Chilli Oyster Sauce', 'chilli oyster sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, 'f96f740c7793a4a7722e8a5ee76de11a', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006179, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006179, 400070006, 400070006, 400070006179, 400070006014, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006184, 400070006179, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006184, 400070006184, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006180, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'black bean coriander sauce'),
           'Black Bean Coriander Sauce', 'black bean coriander sauce', 'Chinese Main Course', 'veg', NULL, '14f98603a21892bf822db00dec1d2f62', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006180, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006180, 400070006, 400070006, 400070006180, 400070006014, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006185, 400070006180, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006185, 400070006185, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006181, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'black bean coriander sauce'),
           'Black Bean Coriander Sauce', 'black bean coriander sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, '14f98603a21892bf822db00dec1d2f62', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006181, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006181, 400070006, 400070006, 400070006181, 400070006014, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006186, 400070006181, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006186, 400070006186, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006182, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'black bean coriander sauce'),
           'Black Bean Coriander Sauce', 'black bean coriander sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, '14f98603a21892bf822db00dec1d2f62', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006182, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006182, 400070006, 400070006, 400070006182, 400070006014, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006187, 400070006182, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006187, 400070006187, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006183, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel chilli sauce'),
           'Caramel Chilli Sauce', 'caramel chilli sauce', 'Chinese Main Course', 'veg', NULL, 'c3caeae0af3e7082a0f2e43fef5960e8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006183, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006183, 400070006, 400070006, 400070006183, 400070006014, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006188, 400070006183, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006188, 400070006188, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006184, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel chilli sauce'),
           'Caramel Chilli Sauce', 'caramel chilli sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, 'c3caeae0af3e7082a0f2e43fef5960e8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006184, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006184, 400070006, 400070006, 400070006184, 400070006014, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006189, 400070006184, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006189, 400070006189, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006185, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel chilli sauce'),
           'Caramel Chilli Sauce', 'caramel chilli sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, 'c3caeae0af3e7082a0f2e43fef5960e8', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006185, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006185, 400070006, 400070006, 400070006185, 400070006014, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006190, 400070006185, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006190, 400070006190, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006186, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cantonese sauce'),
           'Cantonese Sauce', 'cantonese sauce', 'Chinese Main Course', 'veg', NULL, 'f4b7e72741be6accc0b8d27225abed28', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006186, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006186, 400070006, 400070006, 400070006186, 400070006014, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006191, 400070006186, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006191, 400070006191, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006187, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cantonese sauce'),
           'Cantonese Sauce', 'cantonese sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, 'f4b7e72741be6accc0b8d27225abed28', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006187, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006187, 400070006, 400070006, 400070006187, 400070006014, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006192, 400070006187, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006192, 400070006192, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006188, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cantonese sauce'),
           'Cantonese Sauce', 'cantonese sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, 'f4b7e72741be6accc0b8d27225abed28', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006188, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006188, 400070006, 400070006, 400070006188, 400070006014, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006193, 400070006188, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006193, 400070006193, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006189, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean chilli sauce'),
           'Korean Chilli Sauce', 'korean chilli sauce', 'Chinese Main Course', 'veg', NULL, '3f20d5ec03b75a4bc5e5e7c50f61d72c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006189, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006189, 400070006, 400070006, 400070006189, 400070006014, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006194, 400070006189, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006194, 400070006194, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006190, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean chilli sauce'),
           'Korean Chilli Sauce', 'korean chilli sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, '3f20d5ec03b75a4bc5e5e7c50f61d72c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006190, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006190, 400070006, 400070006, 400070006190, 400070006014, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006195, 400070006190, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006195, 400070006195, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006191, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'korean chilli sauce'),
           'Korean Chilli Sauce', 'korean chilli sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, '3f20d5ec03b75a4bc5e5e7c50f61d72c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006191, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006191, 400070006, 400070006, 400070006191, 400070006014, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006196, 400070006191, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006196, 400070006196, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006192, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sapo sauce'),
           'Sapo Sauce', 'sapo sauce', 'Chinese Main Course', 'veg', NULL, 'bd3345c755a2d778239bc7095e562952', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006192, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006192, 400070006, 400070006, 400070006192, 400070006014, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006197, 400070006192, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006197, 400070006197, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006193, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sapo sauce'),
           'Sapo Sauce', 'sapo sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, 'bd3345c755a2d778239bc7095e562952', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006193, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006193, 400070006, 400070006, 400070006193, 400070006014, 17);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006198, 400070006193, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006198, 400070006198, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006194, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sapo sauce'),
           'Sapo Sauce', 'sapo sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, 'bd3345c755a2d778239bc7095e562952', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006194, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006194, 400070006, 400070006, 400070006194, 400070006014, 18);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006199, 400070006194, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006199, 400070006199, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006195, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mapo tofu'),
           'Mapo Tofu', 'mapo tofu', 'Chinese Main Course', 'veg', NULL, 'deacff10c8130a1fa004edc13c2515b6', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006195, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006195, 400070006, 400070006, 400070006195, 400070006014, 19);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006200, 400070006195, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006200, 400070006200, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006196, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mapo tofu'),
           'Mapo Tofu', 'mapo tofu', 'Chinese Main Course', 'non_veg', v_protein_chicken, 'deacff10c8130a1fa004edc13c2515b6', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006196, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006196, 400070006, 400070006, 400070006196, 400070006014, 20);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006201, 400070006196, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006201, 400070006201, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006197, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mapo tofu'),
           'Mapo Tofu', 'mapo tofu', 'Chinese Main Course', 'non_veg', v_protein_seafood, 'deacff10c8130a1fa004edc13c2515b6', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006197, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006197, 400070006, 400070006, 400070006197, 400070006014, 21);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006202, 400070006197, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006202, 400070006202, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006198, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hunan chilli'),
           'Hunan Chilli', 'hunan chilli', 'Chinese Main Course', 'veg', NULL, 'c4d0748a93c3b81d5990782e3693ec6c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006198, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006198, 400070006, 400070006, 400070006198, 400070006014, 22);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006203, 400070006198, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006203, 400070006203, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006199, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hunan chilli'),
           'Hunan Chilli', 'hunan chilli', 'Chinese Main Course', 'non_veg', v_protein_chicken, 'c4d0748a93c3b81d5990782e3693ec6c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006199, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006199, 400070006, 400070006, 400070006199, 400070006014, 23);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006204, 400070006199, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006204, 400070006204, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006200, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hunan chilli'),
           'Hunan Chilli', 'hunan chilli', 'Chinese Main Course', 'non_veg', v_protein_seafood, 'c4d0748a93c3b81d5990782e3693ec6c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006200, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006200, 400070006, 400070006, 400070006200, 400070006014, 24);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006205, 400070006200, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006205, 400070006205, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006201, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot garlic sauce'),
           'Hot Garlic Sauce', 'hot garlic sauce', 'Chinese Main Course', 'veg', NULL, '33af5c5b5d70fe253f66d3a2d840d1e6', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006201, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006201, 400070006, 400070006, 400070006201, 400070006014, 25);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006206, 400070006201, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006206, 400070006206, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006202, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot garlic sauce'),
           'Hot Garlic Sauce', 'hot garlic sauce', 'Chinese Main Course', 'non_veg', v_protein_chicken, '33af5c5b5d70fe253f66d3a2d840d1e6', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006202, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006202, 400070006, 400070006, 400070006202, 400070006014, 26);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006207, 400070006202, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006207, 400070006207, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006203, 400070006, 400070006014,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot garlic sauce'),
           'Hot Garlic Sauce', 'hot garlic sauce', 'Chinese Main Course', 'non_veg', v_protein_seafood, '33af5c5b5d70fe253f66d3a2d840d1e6', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006203, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006203, 400070006, 400070006, 400070006203, 400070006014, 27);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006208, 400070006203, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006208, 400070006208, 329.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006204, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tempura prawns'),
           'Tempura Prawns', 'tempura prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006204, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006204, 400070006, 400070006, 400070006204, 400070006015, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006209, 400070006204, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006209, 400070006209, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006205, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'goong samrot'),
           'Goong Samrot', 'goong samrot', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006205, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006205, 400070006, 400070006, 400070006205, 400070006015, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006210, 400070006205, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006210, 400070006210, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006206, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok fried fish in salt & pepper'),
           'Wok Fried Fish in Salt & Pepper', 'wok fried fish in salt & pepper', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006206, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006206, 400070006, 400070006, 400070006206, 400070006015, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006211, 400070006206, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006211, 400070006211, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006207, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok fried prawns in salt & pepper'),
           'Wok Fried Prawns in Salt & Pepper', 'wok fried prawns in salt & pepper', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006207, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006207, 400070006, 400070006, 400070006207, 400070006015, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006212, 400070006207, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006212, 400070006212, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006208, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pad krapow goong'),
           'Pad Krapow Goong', 'pad krapow goong', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006208, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006208, 400070006, 400070006, 400070006208, 400070006015, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006213, 400070006208, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006213, 400070006213, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006209, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter garlic fish'),
           'Butter Garlic Fish', 'butter garlic fish', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006209, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006209, 400070006, 400070006, 400070006209, 400070006015, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006214, 400070006209, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006214, 400070006214, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006210, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter garlic prawns'),
           'Butter Garlic Prawns', 'butter garlic prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006210, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006210, 400070006, 400070006, 400070006210, 400070006015, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006215, 400070006210, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006215, 400070006215, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006211, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cantonese style fried fish balls'),
           'Cantonese Style Fried Fish Balls', 'cantonese style fried fish balls', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006211, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006211, 400070006, 400070006, 400070006211, 400070006015, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006216, 400070006211, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006216, 400070006216, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006212, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok ginger scallion fish'),
           'Wok Ginger Scallion Fish', 'wok ginger scallion fish', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006212, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006212, 400070006, 400070006, 400070006212, 400070006015, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006217, 400070006212, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006217, 400070006217, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006213, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok ginger scallion prawns'),
           'Wok Ginger Scallion Prawns', 'wok ginger scallion prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006213, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006213, 400070006, 400070006, 400070006213, 400070006015, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006218, 400070006213, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006218, 400070006218, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006214, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thermidor prawns'),
           'Thermidor Prawns', 'thermidor prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006214, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006214, 400070006, 400070006, 400070006214, 400070006015, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006219, 400070006214, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006219, 400070006219, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006215, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli to pepper fish'),
           'Chilli to Pepper Fish', 'chilli to pepper fish', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006215, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006215, 400070006, 400070006, 400070006215, 400070006015, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006220, 400070006215, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006220, 400070006220, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006216, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli to pepper prawns'),
           'Chilli to Pepper Prawns', 'chilli to pepper prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006216, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006216, 400070006, 400070006, 400070006216, 400070006015, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006221, 400070006216, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006221, 400070006221, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006217, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai prawns'),
           'Thai Prawns', 'thai prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006217, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006217, 400070006, 400070006, 400070006217, 400070006015, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006222, 400070006217, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006222, 400070006222, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006218, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crackling fish'),
           'Crackling Fish', 'crackling fish', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006218, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006218, 400070006, 400070006, 400070006218, 400070006015, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006223, 400070006218, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006223, 400070006223, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006219, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crackling prawns'),
           'Crackling Prawns', 'crackling prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006219, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006219, 400070006, 400070006, 400070006219, 400070006015, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006224, 400070006219, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006224, 400070006224, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006220, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'garlic pepper fish'),
           'Garlic Pepper Fish', 'garlic pepper fish', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006220, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006220, 400070006, 400070006, 400070006220, 400070006015, 17);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006225, 400070006220, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006225, 400070006225, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006221, 400070006, 400070006015,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'garlic pepper prawns'),
           'Garlic Pepper Prawns', 'garlic pepper prawns', 'Seafood Chinese Starters', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006221, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006221, 400070006, 400070006, 400070006221, 400070006015, 18);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006226, 400070006221, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006226, 400070006226, 459.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006222, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'balchao prawns'),
           'Balchao Prawns', 'balchao prawns', 'Goan Main Course', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006222, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006222, 400070006, 400070006, 400070006222, 400070006016, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006227, 400070006222, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006227, 400070006227, 469.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006223, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fish goan curry'),
           'Fish Goan Curry', 'fish goan curry', 'Goan Main Course', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006223, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006223, 400070006, 400070006, 400070006223, 400070006016, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006228, 400070006223, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006228, 400070006228, 599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006224, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns goan curry'),
           'Prawns Goan Curry', 'prawns goan curry', 'Goan Main Course', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006224, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006224, 400070006, 400070006, 400070006224, 400070006016, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006229, 400070006224, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006229, 400070006229, 469.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006225, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vindaloo mutton'),
           'Vindaloo Mutton', 'vindaloo mutton', 'Goan Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006225, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006225, 400070006, 400070006, 400070006225, 400070006016, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006230, 400070006225, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006230, 400070006230, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006226, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken xacuti'),
           'Chicken Xacuti', 'chicken xacuti', 'Goan Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006226, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006226, 400070006, 400070006, 400070006226, 400070006016, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006231, 400070006226, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006231, 400070006231, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006227, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns roasted coconut gravy'),
           'Prawns Roasted Coconut Gravy', 'prawns roasted coconut gravy', 'Goan Main Course', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006227, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006227, 400070006, 400070006, 400070006227, 400070006016, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006232, 400070006227, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006232, 400070006232, 469.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006228, 400070006, 400070006016,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken cafreal'),
           'Chicken Cafreal', 'chicken cafreal', 'Goan Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006228, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006228, 400070006, 400070006, 400070006228, 400070006016, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006233, 400070006228, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006233, 400070006233, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006229, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh zaika'),
           'Murgh Zaika', 'murgh zaika', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006229, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006229, 400070006, 400070006, 400070006229, 400070006017, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006234, 400070006229, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006234, 400070006234, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006230, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh pasanda'),
           'Murgh Pasanda', 'murgh pasanda', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006230, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006230, 400070006, 400070006, 400070006230, 400070006017, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006235, 400070006230, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006235, 400070006235, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006231, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh pakiza'),
           'Murgh Pakiza', 'murgh pakiza', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006231, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006231, 400070006, 400070006, 400070006231, 400070006017, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006236, 400070006231, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006236, 400070006236, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006232, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pepper chicken'),
           'Pepper Chicken', 'pepper chicken', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006232, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006232, 400070006, 400070006, 400070006232, 400070006017, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006237, 400070006232, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006237, 400070006237, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006233, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh badami khorma'),
           'Murgh Badami Khorma', 'murgh badami khorma', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006233, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006233, 400070006, 400070006, 400070006233, 400070006017, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006238, 400070006233, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006238, 400070006238, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006234, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dum ka murgh'),
           'Dum Ka Murgh', 'dum ka murgh', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006234, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006234, 400070006, 400070006, 400070006234, 400070006017, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006239, 400070006234, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006239, 400070006239, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006235, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh sufiyana'),
           'Murgh Sufiyana', 'murgh sufiyana', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006235, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006235, 400070006, 400070006, 400070006235, 400070006017, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006240, 400070006235, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006240, 400070006240, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006236, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh nizami handi'),
           'Murgh Nizami Handi', 'murgh nizami handi', 'Hyderabadi Main Course', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006236, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006236, 400070006, 400070006, 400070006236, 400070006017, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006241, 400070006236, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006241, 400070006241, 379.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006237, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton hyderabadi khorma'),
           'Mutton Hyderabadi Khorma', 'mutton hyderabadi khorma', 'Hyderabadi Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006237, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006237, 400070006, 400070006, 400070006237, 400070006017, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006242, 400070006237, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006242, 400070006242, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006238, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton stew'),
           'Mutton Stew', 'mutton stew', 'Hyderabadi Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006238, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006238, 400070006, 400070006, 400070006238, 400070006017, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006243, 400070006238, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006243, 400070006243, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006239, 400070006, 400070006017,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton dum ka kheema'),
           'Mutton Dum Ka Kheema', 'mutton dum ka kheema', 'Hyderabadi Main Course', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006239, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006239, 400070006, 400070006, 400070006239, 400070006017, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006244, 400070006239, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006244, 400070006244, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006240, 400070006, 400070006018,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal bukhara'),
           'Dal Bukhara', 'dal bukhara', 'Dal', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006240, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006240, 400070006, 400070006, 400070006240, 400070006018, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006245, 400070006240, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006245, 400070006245, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006241, 400070006, 400070006018,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal fry'),
           'Dal Fry', 'dal fry', 'Dal', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006241, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006241, 400070006, 400070006, 400070006241, 400070006018, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006246, 400070006241, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006246, 400070006246, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006242, 400070006, 400070006018,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal tadka'),
           'Dal Tadka', 'dal tadka', 'Dal', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006242, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006242, 400070006, 400070006, 400070006242, 400070006018, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006247, 400070006242, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006247, 400070006247, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006243, 400070006, 400070006018,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal khichdi'),
           'Dal Khichdi', 'dal khichdi', 'Dal', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006243, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006243, 400070006, 400070006, 400070006243, 400070006018, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006248, 400070006243, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006248, 400070006248, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006244, 400070006, 400070006019,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh shorba'),
           'Murgh Shorba', 'murgh shorba', 'Indian Shorba', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006244, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006244, 400070006, 400070006, 400070006244, 400070006019, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006249, 400070006244, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006249, 400070006249, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006245, 400070006, 400070006019,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paya shorba'),
           'Paya Shorba', 'paya shorba', 'Indian Shorba', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006245, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006245, 400070006, 400070006, 400070006245, 400070006019, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006250, 400070006245, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006250, 400070006250, 239.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006246, 400070006, 400070006019,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi mutton shorba'),
           'Hyderabadi Mutton Shorba', 'hyderabadi mutton shorba', 'Indian Shorba', 'non_veg', v_protein_mutton, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006246, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006246, 400070006, 400070006, 400070006246, 400070006019, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006251, 400070006246, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006251, 400070006251, 239.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006247, 400070006, 400070006019,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tomato dhaniya ka shorba'),
           'Tomato Dhaniya Ka Shorba', 'tomato dhaniya ka shorba', 'Indian Shorba', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006247, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006247, 400070006, 400070006, 400070006247, 400070006019, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006252, 400070006247, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006252, 400070006252, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006248, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tom yum soup'),
           'Tom Yum Soup', 'tom yum soup', 'Chinese Soup', 'veg', NULL, '98620c948d16d08bb3a6c4b2e5dad97e', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006248, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006248, 400070006, 400070006, 400070006248, 400070006020, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006253, 400070006248, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006253, 400070006253, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006249, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tom yum soup'),
           'Tom Yum Soup', 'tom yum soup', 'Chinese Soup', 'non_veg', v_protein_chicken, '98620c948d16d08bb3a6c4b2e5dad97e', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006249, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006249, 400070006, 400070006, 400070006249, 400070006020, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006254, 400070006249, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006254, 400070006254, 199.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006250, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tom yum soup'),
           'Tom Yum Soup', 'tom yum soup', 'Chinese Soup', 'non_veg', v_protein_seafood, '98620c948d16d08bb3a6c4b2e5dad97e', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006250, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006250, 400070006, 400070006, 400070006250, 400070006020, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006255, 400070006250, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006255, 400070006255, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006251, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tom kha soup'),
           'Tom Kha Soup', 'tom kha soup', 'Chinese Soup', 'veg', NULL, '5dfea45110f09b4efe8d073ed22f00be', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006251, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006251, 400070006, 400070006, 400070006251, 400070006020, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006256, 400070006251, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006256, 400070006256, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006252, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tom kha soup'),
           'Tom Kha Soup', 'tom kha soup', 'Chinese Soup', 'non_veg', v_protein_chicken, '5dfea45110f09b4efe8d073ed22f00be', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006252, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006252, 400070006, 400070006, 400070006252, 400070006020, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006257, 400070006252, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006257, 400070006257, 199.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006253, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tom kha soup'),
           'Tom Kha Soup', 'tom kha soup', 'Chinese Soup', 'non_veg', v_protein_seafood, '5dfea45110f09b4efe8d073ed22f00be', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006253, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006253, 400070006, 400070006, 400070006253, 400070006020, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006258, 400070006253, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006258, 400070006258, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006254, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mandu-guk dumpling soup'),
           'Mandu-Guk Dumpling Soup', 'mandu-guk dumpling soup', 'Chinese Soup', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006254, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006254, 400070006, 400070006, 400070006254, 400070006020, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006259, 400070006254, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006259, 400070006259, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006255, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'manchow soup'),
           'Manchow Soup', 'manchow soup', 'Chinese Soup', 'veg', NULL, '8d10aa0c26da8f03cecc96ac04003e2c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006255, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006255, 400070006, 400070006, 400070006255, 400070006020, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006260, 400070006255, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006260, 400070006260, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006256, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'manchow soup'),
           'Manchow Soup', 'manchow soup', 'Chinese Soup', 'non_veg', v_protein_chicken, '8d10aa0c26da8f03cecc96ac04003e2c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006256, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006256, 400070006, 400070006, 400070006256, 400070006020, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006261, 400070006256, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006261, 400070006261, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006257, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'manchow soup'),
           'Manchow Soup', 'manchow soup', 'Chinese Soup', 'non_veg', v_protein_seafood, '8d10aa0c26da8f03cecc96ac04003e2c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006257, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006257, 400070006, 400070006, 400070006257, 400070006020, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006262, 400070006257, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006262, 400070006262, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006258, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'laksa noodle soup'),
           'Laksa Noodle Soup', 'laksa noodle soup', 'Chinese Soup', 'veg', NULL, '5c93ab2f423b71b599c76b965a469cf0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006258, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006258, 400070006, 400070006, 400070006258, 400070006020, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006263, 400070006258, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006263, 400070006263, 199.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006259, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'laksa noodle soup'),
           'Laksa Noodle Soup', 'laksa noodle soup', 'Chinese Soup', 'non_veg', v_protein_chicken, '5c93ab2f423b71b599c76b965a469cf0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006259, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006259, 400070006, 400070006, 400070006259, 400070006020, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006264, 400070006259, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006264, 400070006264, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006260, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'laksa noodle soup'),
           'Laksa Noodle Soup', 'laksa noodle soup', 'Chinese Soup', 'non_veg', v_protein_seafood, '5c93ab2f423b71b599c76b965a469cf0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006260, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006260, 400070006, 400070006, 400070006260, 400070006020, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006265, 400070006260, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006265, 400070006265, 259.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006261, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot & sour soup'),
           'Hot & Sour Soup', 'hot & sour soup', 'Chinese Soup', 'veg', NULL, '39556859d89ecaf76326f2b131b93d00', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006261, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006261, 400070006, 400070006, 400070006261, 400070006020, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006266, 400070006261, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006266, 400070006266, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006262, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot & sour soup'),
           'Hot & Sour Soup', 'hot & sour soup', 'Chinese Soup', 'non_veg', v_protein_chicken, '39556859d89ecaf76326f2b131b93d00', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006262, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006262, 400070006, 400070006, 400070006262, 400070006020, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006267, 400070006262, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006267, 400070006267, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006263, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hot & sour soup'),
           'Hot & Sour Soup', 'hot & sour soup', 'Chinese Soup', 'non_veg', v_protein_seafood, '39556859d89ecaf76326f2b131b93d00', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006263, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006263, 400070006, 400070006, 400070006263, 400070006020, 16);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006268, 400070006263, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006268, 400070006268, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006264, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roasted pepper sweet corn soup'),
           'Roasted Pepper Sweet Corn Soup', 'roasted pepper sweet corn soup', 'Chinese Soup', 'veg', NULL, 'c0eca513dd5e66a7567c94ca9259c5e3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006264, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006264, 400070006, 400070006, 400070006264, 400070006020, 17);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006269, 400070006264, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006269, 400070006269, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006265, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roasted pepper sweet corn soup'),
           'Roasted Pepper Sweet Corn Soup', 'roasted pepper sweet corn soup', 'Chinese Soup', 'non_veg', v_protein_chicken, 'c0eca513dd5e66a7567c94ca9259c5e3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006265, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006265, 400070006, 400070006, 400070006265, 400070006020, 18);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006270, 400070006265, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006270, 400070006270, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006266, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roasted pepper sweet corn soup'),
           'Roasted Pepper Sweet Corn Soup', 'roasted pepper sweet corn soup', 'Chinese Soup', 'non_veg', v_protein_seafood, 'c0eca513dd5e66a7567c94ca9259c5e3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006266, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006266, 400070006, 400070006, 400070006266, 400070006020, 19);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006271, 400070006266, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006271, 400070006271, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006267, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'clear soup'),
           'Clear Soup', 'clear soup', 'Chinese Soup', 'veg', NULL, '72017e347712be9f6e82a34a589e62c7', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006267, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006267, 400070006, 400070006, 400070006267, 400070006020, 20);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006272, 400070006267, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006272, 400070006272, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006268, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'clear soup'),
           'Clear Soup', 'clear soup', 'Chinese Soup', 'non_veg', v_protein_chicken, '72017e347712be9f6e82a34a589e62c7', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006268, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006268, 400070006, 400070006, 400070006268, 400070006020, 21);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006273, 400070006268, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006273, 400070006273, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006269, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'clear soup'),
           'Clear Soup', 'clear soup', 'Chinese Soup', 'non_veg', v_protein_seafood, '72017e347712be9f6e82a34a589e62c7', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006269, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006269, 400070006, 400070006, 400070006269, 400070006020, 22);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006274, 400070006269, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006274, 400070006274, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006270, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lemon coriander soup'),
           'Lemon Coriander Soup', 'lemon coriander soup', 'Chinese Soup', 'veg', NULL, 'b9a3d5977625f577735d2f00525a7825', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006270, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006270, 400070006, 400070006, 400070006270, 400070006020, 23);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006275, 400070006270, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006275, 400070006275, 169.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006271, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lemon coriander soup'),
           'Lemon Coriander Soup', 'lemon coriander soup', 'Chinese Soup', 'non_veg', v_protein_chicken, 'b9a3d5977625f577735d2f00525a7825', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006271, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006271, 400070006, 400070006, 400070006271, 400070006020, 24);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006276, 400070006271, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006276, 400070006276, 189.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006272, 400070006, 400070006020,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lemon coriander soup'),
           'Lemon Coriander Soup', 'lemon coriander soup', 'Chinese Soup', 'non_veg', v_protein_seafood, 'b9a3d5977625f577735d2f00525a7825', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006272, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006272, 400070006, 400070006, 400070006272, 400070006020, 25);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006277, 400070006272, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006277, 400070006277, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006273, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dynamite tempura prawns sushi'),
           'Dynamite Tempura Prawns Sushi', 'dynamite tempura prawns sushi', 'Sushi', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006273, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006273, 400070006, 400070006, 400070006273, 400070006021, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006278, 400070006273, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006278, 400070006278, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006274, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tempura prawns sushi'),
           'Tempura Prawns Sushi', 'tempura prawns sushi', 'Sushi', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006274, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006274, 400070006, 400070006, 400070006274, 400070006021, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006279, 400070006274, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006279, 400070006279, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006275, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns california sushi'),
           'Prawns California Sushi', 'prawns california sushi', 'Sushi', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006275, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006275, 400070006, 400070006, 400070006275, 400070006021, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006280, 400070006275, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006280, 400070006280, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006276, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'teriyaki prawns sushi'),
           'Teriyaki Prawns Sushi', 'teriyaki prawns sushi', 'Sushi', 'non_veg', v_protein_seafood, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006276, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006276, 400070006, 400070006, 400070006276, 400070006021, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006281, 400070006276, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006281, 400070006281, 449.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006277, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'takuan maki'),
           'Takuan Maki', 'takuan maki', 'Sushi', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006277, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006277, 400070006, 400070006, 400070006277, 400070006021, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006282, 400070006277, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006282, 400070006282, 409.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006278, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'asparagus tempura sushi'),
           'Asparagus Tempura Sushi', 'asparagus tempura sushi', 'Sushi', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006278, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006278, 400070006, 400070006, 400070006278, 400070006021, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006283, 400070006278, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006283, 400070006283, 409.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006279, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tempura avocado sushi'),
           'Tempura Avocado Sushi', 'tempura avocado sushi', 'Sushi', 'veg', NULL, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006279, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006279, 400070006, 400070006, 400070006279, 400070006021, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006284, 400070006279, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006284, 400070006284, 409.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006280, 400070006, 400070006021,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'avocado sesame cheese sushi'),
           'Avocado Sesame Cheese Sushi', 'avocado sesame cheese sushi', 'Sushi', 'veg', NULL, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006280, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006280, 400070006, 400070006, 400070006280, 400070006021, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006285, 400070006280, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006285, 400070006285, 409.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006281, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'soupy dim sum'),
           'Soupy Dim Sum', 'soupy dim sum', 'Dimsum', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006281, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006281, 400070006, 400070006, 400070006281, 400070006022, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006286, 400070006281, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006286, 400070006286, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006282, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sui mai'),
           'Sui Mai', 'sui mai', 'Dimsum', 'non_veg', v_protein_chicken, '6df224df5e32a55bc45d698b84a4c7e0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006282, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006282, 400070006, 400070006, 400070006282, 400070006022, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006287, 400070006282, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006287, 400070006287, 179.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006283, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sui mai'),
           'Sui Mai', 'sui mai', 'Dimsum', 'non_veg', v_protein_seafood, '6df224df5e32a55bc45d698b84a4c7e0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006283, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006283, 400070006, 400070006, 400070006283, 400070006022, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006288, 400070006283, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006288, 400070006288, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006284, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'har gow'),
           'Har Gow', 'har gow', 'Dimsum', 'non_veg', v_protein_chicken, '18c46b0131500d408f2c46ea3b67e675', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006284, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006284, 400070006, 400070006, 400070006284, 400070006022, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006289, 400070006284, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006289, 400070006289, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006285, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'har gow'),
           'Har Gow', 'har gow', 'Dimsum', 'non_veg', v_protein_seafood, '18c46b0131500d408f2c46ea3b67e675', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006285, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006285, 400070006, 400070006, 400070006285, 400070006022, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006290, 400070006285, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006290, 400070006290, 269.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006286, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'potstickers'),
           'Potstickers', 'potstickers', 'Dimsum', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006286, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006286, 400070006, 400070006, 400070006286, 400070006022, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006291, 400070006286, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006291, 400070006291, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006287, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crystal dumpling'),
           'Crystal Dumpling', 'crystal dumpling', 'Dimsum', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006287, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006287, 400070006, 400070006, 400070006287, 400070006022, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006292, 400070006287, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006292, 400070006292, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006288, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'steamed korean bao'),
           'Steamed Korean Bao', 'steamed korean bao', 'Dimsum', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006288, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006288, 400070006, 400070006, 400070006288, 400070006022, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006293, 400070006288, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006293, 400070006293, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006294, 400070006288, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006294, 400070006294, 389.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006289, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crispy chicken bao with pickled carrot, spicy mayo'),
           'Crispy Chicken Bao with Pickled Carrot, Spicy Mayo', 'crispy chicken bao with pickled carrot, spicy mayo', 'Dimsum', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006289, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006289, 400070006, 400070006, 400070006289, 400070006022, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006295, 400070006289, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006295, 400070006295, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006296, 400070006289, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006296, 400070006296, 389.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006290, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheung fun'),
           'Cheung Fun', 'cheung fun', 'Dimsum', 'non_veg', v_protein_chicken, 'af53a9a6097095c625779d85c0ec6d0e', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006290, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006290, 400070006, 400070006, 400070006290, 400070006022, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006297, 400070006290, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006297, 400070006297, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006291, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheung fun'),
           'Cheung Fun', 'cheung fun', 'Dimsum', 'non_veg', v_protein_seafood, 'af53a9a6097095c625779d85c0ec6d0e', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006291, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006291, 400070006, 400070006, 400070006291, 400070006022, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006298, 400070006291, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006298, 400070006298, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006292, 400070006, 400070006022,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fried wonton'),
           'Fried Wonton', 'fried wonton', 'Dimsum', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006292, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006292, 400070006, 400070006, 400070006292, 400070006022, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006299, 400070006292, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006299, 400070006299, 229.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006293, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mizumi ramen'),
           'Mizumi Ramen', 'mizumi ramen', 'Ramen Bowl', 'veg', NULL, '9d7d25b2ab8349e8c5ae7a68f3962ec3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006293, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006293, 400070006, 400070006, 400070006293, 400070006023, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006300, 400070006293, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006300, 400070006300, 200.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006294, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mizumi ramen'),
           'Mizumi Ramen', 'mizumi ramen', 'Ramen Bowl', 'non_veg', v_protein_chicken, '9d7d25b2ab8349e8c5ae7a68f3962ec3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006294, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006294, 400070006, 400070006, 400070006294, 400070006023, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006301, 400070006294, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006301, 400070006301, 220.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006295, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mizumi ramen'),
           'Mizumi Ramen', 'mizumi ramen', 'Ramen Bowl', 'non_veg', v_protein_seafood, '9d7d25b2ab8349e8c5ae7a68f3962ec3', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006295, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006295, 400070006, 400070006, 400070006295, 400070006023, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006302, 400070006295, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006302, 400070006302, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006296, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'miso ramen'),
           'Miso Ramen', 'miso ramen', 'Ramen Bowl', 'veg', NULL, 'eb92889d558d3610eb3d4bfd3ba70d5c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006296, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006296, 400070006, 400070006, 400070006296, 400070006023, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006303, 400070006296, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006303, 400070006303, 200.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006297, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'miso ramen'),
           'Miso Ramen', 'miso ramen', 'Ramen Bowl', 'non_veg', v_protein_chicken, 'eb92889d558d3610eb3d4bfd3ba70d5c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006297, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006297, 400070006, 400070006, 400070006297, 400070006023, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006304, 400070006297, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006304, 400070006304, 220.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006298, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'miso ramen'),
           'Miso Ramen', 'miso ramen', 'Ramen Bowl', 'non_veg', v_protein_seafood, 'eb92889d558d3610eb3d4bfd3ba70d5c', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006298, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006298, 400070006, 400070006, 400070006298, 400070006023, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006305, 400070006298, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006305, 400070006305, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006299, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'spicy kimchi ramen'),
           'Spicy Kimchi Ramen', 'spicy kimchi ramen', 'Ramen Bowl', 'veg', NULL, '633dfdc99fe517f17b8d49bced31a211', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006299, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006299, 400070006, 400070006, 400070006299, 400070006023, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006306, 400070006299, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006306, 400070006306, 200.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006300, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'spicy kimchi ramen'),
           'Spicy Kimchi Ramen', 'spicy kimchi ramen', 'Ramen Bowl', 'non_veg', v_protein_chicken, '633dfdc99fe517f17b8d49bced31a211', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006300, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006300, 400070006, 400070006, 400070006300, 400070006023, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006307, 400070006300, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006307, 400070006307, 220.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006301, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'spicy kimchi ramen'),
           'Spicy Kimchi Ramen', 'spicy kimchi ramen', 'Ramen Bowl', 'non_veg', v_protein_seafood, '633dfdc99fe517f17b8d49bced31a211', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006301, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006301, 400070006, 400070006, 400070006301, 400070006023, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006308, 400070006301, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006308, 400070006308, 279.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006302, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'creamy ramen bowl'),
           'Creamy Ramen Bowl', 'creamy ramen bowl', 'Ramen Bowl', 'veg', NULL, '0bf7ae0ae46d3470b0360595920131f0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006302, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006302, 400070006, 400070006, 400070006302, 400070006023, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006309, 400070006302, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006309, 400070006309, 220.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006303, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'creamy ramen bowl'),
           'Creamy Ramen Bowl', 'creamy ramen bowl', 'Ramen Bowl', 'non_veg', v_protein_chicken, '0bf7ae0ae46d3470b0360595920131f0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006303, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006303, 400070006, 400070006, 400070006303, 400070006023, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006310, 400070006303, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006310, 400070006310, 250.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006304, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'creamy ramen bowl'),
           'Creamy Ramen Bowl', 'creamy ramen bowl', 'Ramen Bowl', 'non_veg', v_protein_seafood, '0bf7ae0ae46d3470b0360595920131f0', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006304, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006304, 400070006, 400070006, 400070006304, 400070006023, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006311, 400070006304, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006311, 400070006311, 300.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006305, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai ramen'),
           'Thai Ramen', 'thai ramen', 'Ramen Bowl', 'veg', NULL, 'a09fb6439838f9f3848e9394eebab7a7', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006305, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006305, 400070006, 400070006, 400070006305, 400070006023, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006312, 400070006305, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006312, 400070006312, 220.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006306, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai ramen'),
           'Thai Ramen', 'thai ramen', 'Ramen Bowl', 'non_veg', v_protein_chicken, 'a09fb6439838f9f3848e9394eebab7a7', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006306, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006306, 400070006, 400070006, 400070006306, 400070006023, 14);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006313, 400070006306, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006313, 400070006313, 250.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006307, 400070006, 400070006023,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thai ramen'),
           'Thai Ramen', 'thai ramen', 'Ramen Bowl', 'non_veg', v_protein_seafood, 'a09fb6439838f9f3848e9394eebab7a7', 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006307, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006307, 400070006, 400070006, 400070006307, 400070006023, 15);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006314, 400070006307, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006314, 400070006314, 300.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006308, 400070006, 400070006024,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chilli basil pesto tikka'),
           'Chilli Basil Pesto Tikka', 'chilli basil pesto tikka', 'Tandoor Starter Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006308, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006308, 400070006, 400070006, 400070006308, 400070006024, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006315, 400070006308, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006315, 400070006315, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006309, 400070006, 400070006024,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer peri peri tikka'),
           'Paneer Peri Peri Tikka', 'paneer peri peri tikka', 'Tandoor Starter Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006309, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006309, 400070006, 400070006, 400070006309, 400070006024, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006316, 400070006309, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006316, 400070006316, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006310, 400070006, 400070006024,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'shaslik paneer tikka'),
           'Shaslik Paneer Tikka', 'shaslik paneer tikka', 'Tandoor Starter Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006310, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006310, 400070006, 400070006, 400070006310, 400070006024, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006317, 400070006310, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006317, 400070006317, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006311, 400070006, 400070006024,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'peshawari paneer tikka'),
           'Peshawari Paneer Tikka', 'peshawari paneer tikka', 'Tandoor Starter Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006311, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006311, 400070006, 400070006, 400070006311, 400070006024, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006318, 400070006311, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006318, 400070006318, 359.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006312, 400070006, 400070006024,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'firdausi aloo'),
           'Firdausi Aloo', 'firdausi aloo', 'Tandoor Starter Vegetable', 'veg', NULL, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006312, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006312, 400070006, 400070006, 400070006312, 400070006024, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006319, 400070006312, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006319, 400070006319, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006313, 400070006, 400070006024,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'makhmali mushroom tikka'),
           'Makhmali Mushroom Tikka', 'makhmali mushroom tikka', 'Tandoor Starter Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006313, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006313, 400070006, 400070006, 400070006313, 400070006024, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006320, 400070006313, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006320, 400070006320, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006314, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lotus stem honey chilli'),
           'Lotus Stem Honey Chilli', 'lotus stem honey chilli', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006314, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006314, 400070006, 400070006, 400070006314, 400070006025, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006321, 400070006314, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006321, 400070006321, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006315, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'assorted pepper cottage cheese chilli'),
           'Assorted Pepper Cottage Cheese Chilli', 'assorted pepper cottage cheese chilli', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006315, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006315, 400070006, 400070006, 400070006315, 400070006025, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006322, 400070006315, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006322, 400070006322, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006316, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'singapore cottage cheese'),
           'Singapore Cottage Cheese', 'singapore cottage cheese', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006316, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006316, 400070006, 400070006, 400070006316, 400070006025, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006323, 400070006316, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006323, 400070006323, 299.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006317, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vegetable manchurian'),
           'Vegetable Manchurian', 'vegetable manchurian', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006317, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006317, 400070006, 400070006, 400070006317, 400070006025, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006324, 400070006317, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006324, 400070006324, 289.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006318, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'honey chilli potato'),
           'Honey Chilli Potato', 'honey chilli potato', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006318, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006318, 400070006, 400070006, 400070006318, 400070006025, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006325, 400070006318, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006325, 400070006325, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006319, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'schezwan chilli baby corn'),
           'Schezwan Chilli Baby Corn', 'schezwan chilli baby corn', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006319, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006319, 400070006, 400070006, 400070006319, 400070006025, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006326, 400070006319, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006326, 400070006326, 289.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006320, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'assorted pepper mushroom chilli'),
           'Assorted Pepper Mushroom Chilli', 'assorted pepper mushroom chilli', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006320, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006320, 400070006, 400070006, 400070006320, 400070006025, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006327, 400070006320, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006327, 400070006327, 249.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006321, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'corn pistolo'),
           'Corn Pistolo', 'corn pistolo', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006321, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006321, 400070006, 400070006, 400070006321, 400070006025, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006328, 400070006321, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006328, 400070006328, 219.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006322, 400070006, 400070006025,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'wok fried vegetables in salt & pepper'),
           'Wok Fried Vegetables in Salt & Pepper', 'wok fried vegetables in salt & pepper', 'Chinese Starters Vegetable', 'veg', NULL, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006322, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006322, 400070006, 400070006, 400070006322, 400070006025, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006329, 400070006322, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006329, 400070006329, 289.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006323, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh noor-e-malai'),
           'Murgh Noor-E-Malai', 'murgh noor-e-malai', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006323, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006323, 400070006, 400070006, 400070006323, 400070006026, 1);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006330, 400070006323, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006330, 400070006330, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006324, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh cilantro tikka'),
           'Murgh Cilantro Tikka', 'murgh cilantro tikka', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006324, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006324, 400070006, 400070006, 400070006324, 400070006026, 2);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006331, 400070006324, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006331, 400070006331, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006325, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi nizami kabab'),
           'Hyderabadi Nizami Kabab', 'hyderabadi nizami kabab', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006325, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006325, 400070006, 400070006, 400070006325, 400070006026, 3);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006332, 400070006325, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006332, 400070006332, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006326, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh awadhi cheese kabab'),
           'Murgh Awadhi Cheese Kabab', 'murgh awadhi cheese kabab', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006326, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006326, 400070006, 400070006, 400070006326, 400070006026, 4);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006333, 400070006326, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006333, 400070006333, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006327, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh-e-siyah mirch'),
           'Murgh-E-Siyah Mirch', 'murgh-e-siyah mirch', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006327, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006327, 400070006, 400070006, 400070006327, 400070006026, 5);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006334, 400070006327, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006334, 400070006334, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006328, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh dahi lasooni khaas'),
           'Murgh Dahi Lasooni Khaas', 'murgh dahi lasooni khaas', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006328, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006328, 400070006, 400070006, 400070006328, 400070006026, 6);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006335, 400070006328, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006335, 400070006335, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006329, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh nawabi tangdi'),
           'Murgh Nawabi Tangdi', 'murgh nawabi tangdi', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006329, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006329, 400070006, 400070006, 400070006329, 400070006026, 7);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006336, 400070006329, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006336, 400070006336, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006330, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh moroccan kabab'),
           'Murgh Moroccan Kabab', 'murgh moroccan kabab', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006330, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006330, 400070006, 400070006, 400070006330, 400070006026, 8);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006337, 400070006330, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006337, 400070006337, 419.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006331, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kashmiri tandoori murgh'),
           'Kashmiri Tandoori Murgh', 'kashmiri tandoori murgh', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'needs_review';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006331, 400070006, 400070006, 0.75, 'needs_review');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006331, 400070006, 400070006, 400070006331, 400070006026, 9);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006338, 400070006331, 'Half', 'fixed', FALSE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006338, 400070006338, 339.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006339, 400070006331, 'Full', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006339, 400070006339, 549.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006332, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh classic tandoori tikka'),
           'Murgh Classic Tandoori Tikka', 'murgh classic tandoori tikka', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006332, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006332, 400070006, 400070006, 400070006332, 400070006026, 10);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006340, 400070006332, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006340, 400070006340, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006333, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh peshawari seekh kabab'),
           'Murgh Peshawari Seekh Kabab', 'murgh peshawari seekh kabab', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006333, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006333, 400070006, 400070006, 400070006333, 400070006026, 11);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006341, 400070006333, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006341, 400070006341, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006334, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'murgh angara kabab'),
           'Murgh Angara Kabab', 'murgh angara kabab', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006334, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006334, 400070006, 400070006, 400070006334, 400070006026, 12);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006342, 400070006334, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006342, 400070006342, 399.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

    INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                            raw_category_text, food_classification_code, protein_type_id, split_group_key, verification_status_code)
    SELECT 400070006335, 400070006, 400070006026,
           (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'smokery special kabab platter'),
           'Smokery Special Kabab Platter', 'smokery special kabab platter', 'Tandoor Starter Non-Veg', 'non_veg', v_protein_chicken, NULL, 'unverified';
    INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
    VALUES (400070006335, 400070006, 400070006, 0.95, 'unverified');
    INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
    VALUES (400070006335, 400070006, 400070006, 400070006335, 400070006026, 13);
    INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
    VALUES (400070006343, 400070006335, 'Regular', 'fixed', TRUE);
    INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
    VALUES (400070006343, 400070006343, 1599.00, 'exclusive', 400070006, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

END $$;

COMMIT;

-- ----------------------------------------------------------------------
-- Sanity check: run after commit to confirm row counts
-- ----------------------------------------------------------------------
SELECT
    400070006 AS restaurant_id,
    (SELECT COUNT(*) FROM menu_category WHERE restaurant_id = 400070006) AS categories,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070006) AS items,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070006 AND menu_category_id IS NOT NULL) AS items_categorized,
    (SELECT COUNT(*) FROM menu_item_variant miv JOIN menu_item mi ON mi.menu_item_id = miv.menu_item_id WHERE mi.restaurant_id = 400070006) AS variants,
    (SELECT COUNT(DISTINCT split_group_key) FROM menu_item WHERE restaurant_id = 400070006 AND split_group_key IS NOT NULL) AS split_groups,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070006 AND verification_status_code = 'needs_review') AS flagged_for_review;