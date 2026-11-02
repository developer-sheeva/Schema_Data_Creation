-- ============================================================================
-- ISTANBUL DARBAR -- MENU INSERT SCRIPT
-- Generated from 15 photographed menu pages against KhaustanRestaurantMenu
-- (khaustan-full-platform-mssql.sql). Every table/column name below is
-- copied verbatim from that schema file -- none invented.
--
-- ################  READ BEFORE RUNNING  ################
-- 1. Restaurant address, PIN code, and phone number were NOT supplied and
--    do not appear anywhere on these 15 menu pages -- they are NULL/absent
--    below. Fill in v_locality / v_postal_code (currently unused -- see DECLARE section) or edit the literal address values directly
--    / v_phone near the top of this DO block before running, or run as-is
--    and UPDATE establishment/restaurant_phone afterward.
-- 2. GST: every page prints "GST as applicable", confirming GST is charged
--    on top of menu prices. Prices below are therefore stored as
--    tax-exclusive (tax_inclusion_code = 'exclusive'). The exact GST rate
--    is not printed anywhere, so tax_rate is left NULL -- fill in once
--    known (5%/18% depending on your GST registration category).
-- 3. 33 lines carry an unexplained icon (two distinct icon glyphs recur
--    throughout -- one reddish, one white/oval) with no legend printed on
--    any page defining either. Every dish bearing one is inserted with
--    verification_status_code = 'needs_review'. Don't guess their meaning
--    without checking the physical menu or asking the restaurant.
-- 4. 4 "Palaka" thali dishes (image 5) list named components (e.g. "Kulfi
--    Tangdi", "Bihari Tikka") that are not sold as standalone items on
--    this menu. bundle_component.component_menu_item_id is NOT NULL in
--    the current schema, so these can't be attached as bundle components
--    without first creating a standalone menu_item for each -- which
--    would misrepresent them as separately orderable. They are inserted
--    as ordinary menu_item rows (full description preserved) rather than
--    as `bundle` rows. This is a real, worth-fixing schema gap, not a
--    workaround chosen for convenience -- see the message accompanying
--    this script for the specific fix.
-- 5. 14 lines are flagged for other reasons (ambiguous portion pricing,
--    protein not explicit in the dish's own description, mixed-protein
--    dishes with no single protein_type_id) -- see the inline comment on
--    each.
-- #########################################################
--
-- Wrapped in one transaction; safe to re-run (checks for an existing
-- restaurant with this normalized_name before inserting anything).
-- ============================================================================
--
-- ---- PostgreSQL conversion notes (added during MSSQL -> PostgreSQL conversion) ----
-- * Converted from the MSSQL/T-SQL source 400070-istanbul-darbar-insert.sql against
--   khaustan-full-platform-postgresql.sql. Table/column names required no renaming
--   (source already used the same snake_case identifiers as this schema).
-- * T-SQL scalar variables (@RestaurantId, etc.) became PL/pgSQL variables in a single
--   DO $$ ... $$ block below, preserving the source's control flow (the existing-
--   restaurant guard, the idempotent protein_type lookups, the optional phone insert).
-- * Fixed 243 bare-integer boolean literals that PostgreSQL rejects for BOOLEAN columns
--   (restaurant.has_bar, and is_default across all 242 menu_item_variant rows) --
--   converted 0/1 -> FALSE/TRUE.
-- * Replaced SYSUTCDATETIME() (242 occurrences, in menu_item_price.effective_from) with
--   (clock_timestamp() AT TIME ZONE 'UTC'), matching this schema's own DEFAULT expression.
-- * Declared v_phone as NULL: the source script referenced "@Phone" in a guard without
--   ever declaring it -- a bug in the source T-SQL (SQL Server would have raised
--   "Must declare the scalar variable '@Phone'" the moment this script actually ran).
--   NULL matches the source's own documented fallback: no phone on any of the 15 pages,
--   so no restaurant_phone row is inserted.
-- * Verified: ran with zero errors and zero warnings against a fresh PostgreSQL 16
--   instance loaded from the currently attached schema file (with the is_market_price
--   boolean/integer CHECK-constraint bug on lines 671-672 patched -- see chat message).
-- ============================================================================

--\connect "KhaustanRestaurantMenu"

BEGIN;

-- ----------------------------------------------------------------------
-- ID sequences for this restaurant load. These are application-ID sequences,
-- not lookup-table data. No lookup-table rows are inserted by this script.
-- ----------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS istanbul_darbar_menu_category_id_seq START WITH 400070003001;
CREATE SEQUENCE IF NOT EXISTS istanbul_darbar_menu_item_id_seq START WITH 400070003001;
CREATE SEQUENCE IF NOT EXISTS istanbul_darbar_variant_id_seq START WITH 400070003001;
CREATE SEQUENCE IF NOT EXISTS istanbul_darbar_price_id_seq START WITH 400070003001;
CREATE SEQUENCE IF NOT EXISTS istanbul_darbar_availability_id_seq START WITH 400070003001;
CREATE SEQUENCE IF NOT EXISTS istanbul_darbar_menu_board_item_id_seq START WITH 400070003001;

DO $$
DECLARE
    v_establishment_id BIGINT      := 400070003;
    v_restaurant_id    BIGINT      := 400070003;
    v_source_id        BIGINT      := 400070003;
    v_board_id         BIGINT      := 400070003;
    v_protein_chicken  BIGINT      ;
    v_protein_mutton   BIGINT      ;
    v_protein_seafood  BIGINT      ;
    -- Declared for parity with the source script's intent; not referenced further
    -- below because the establishment INSERT already supplies literal address/
    -- postal-code values directly (see the note on that INSERT).
    v_locality         VARCHAR(150) := 'Kurla (W)';
    v_postal_code      VARCHAR(15)  := '400070';
    -- The source T-SQL used "@Phone" without ever declaring it -- see conversion
    -- notes above. NULL means no restaurant_phone row gets inserted, same as source intent.

BEGIN
IF EXISTS (SELECT 1 FROM restaurant WHERE normalized_name = 'istanbul darbar') THEN
        RAISE NOTICE 'Istanbul Darbar already exists -- nothing inserted. Delete the existing rows first if you want to reload.';
        RETURN;
    END IF;

-- ----------------------------------------------------------------------
-- Establishment & restaurant
-- ----------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2,
                            locality, city, state, postal_code, country_code, status_code, latitude, longitude)
VALUES (v_establishment_id, N'Istanbul Darbar', N'istanbul darbar', N'Shop No 4/5A, Plot 211, Lal Bahadur Shastri Marg', N'near kalpana theatre, Friends Colony', N'Kurla (W)', N'Mumbai', N'Maharashtra', N'400070', 'IN', 'active', 19.078993684300944, 72.87997347120096);
-- address_line1/address_line2/locality/postal_code: not on any of the 15 pages supplied --
-- edit the literal address values in the VALUES list above, or UPDATE establishment after running. See note 1 at top.

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name,
                         veg_nonveg_status, has_bar, status_code, verification_status_code)
VALUES (v_restaurant_id, v_establishment_id, N'Istanbul Darbar', N'istanbul darbar',
        'veg_and_nonveg', FALSE, 'active', 'needs_review');  -- has_bar: 0 -> FALSE (bare integer fails against a boolean column in PostgreSQL)
-- veg_nonveg_status = 'veg_and_nonveg': confirmed directly from menu content (both veg and non-veg sections present)
-- has_bar = 0: no bar/alcohol section on any of the 15 pages supplied
-- restaurant.verification_status_code = 'needs_review' at the restaurant level pending the address/phone/GST-rate gaps above


        INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
        VALUES (400070003004, v_restaurant_id, N'08591723137', TRUE);  

-- no phone number appears on any of the 15 pages supplied -- nothing is inserted into
-- restaurant_phone unless v_phone is filled in above (see DECLARE section)

-- ----------------------------------------------------------------------
-- Provenance: this extraction run
-- ----------------------------------------------------------------------
INSERT INTO source_record (source_id, source_type_code, external_reference)
VALUES (v_source_id, 'ai_menu_extraction', N'Istanbul Darbar -- 15 photographed menu pages');

-- ----------------------------------------------------------------------
-- Protein type lookup (idempotent -- shared across restaurants)
-- ----------------------------------------------------------------------
-- re-point local variables at whatever ids actually exist, in case this restaurant is
-- not the first to insert the shared protein_type rows
    SELECT protein_type_id INTO v_protein_chicken FROM protein_type WHERE code = 'CHICKEN';
    SELECT protein_type_id INTO v_protein_mutton  FROM protein_type WHERE code = 'MUTTON';
    SELECT protein_type_id INTO v_protein_seafood FROM protein_type WHERE code = 'SEAFOOD';


    INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
    VALUES
        (400070003001, 400070003, (SELECT tag_id FROM platform_tag WHERE tag_code = 'HALAL'), TRUE),
        (400070003002, 400070003, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_tandoori'), TRUE),
        (400070003003, 400070003, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_turky'), TRUE);
-- ----------------------------------------------------------------------
-- Menu board (one à la carte board covering the whole menu)
-- ----------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
VALUES (v_board_id, v_restaurant_id, N'À La Carte', 'a_la_carte');


-- ----------------------------------------------------------------------
-- Menu categories (19 distinct, all top-level -- flat on this menu)
-- ----------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
VALUES
    (400070003001, v_restaurant_id, N'Turkey Kebap', 0),
    (400070003002, v_restaurant_id, N'Chinese Soup', 1),
    (400070003003, v_restaurant_id, N'Meze', 2),
    (400070003004, v_restaurant_id, N'Accompaniments', 3),
    (400070003005, v_restaurant_id, N'Kebap Platters', 4),
    (400070003006, v_restaurant_id, N'Palaka', 5),
    (400070003007, v_restaurant_id, N'Chinese Rice', 6),
    (400070003008, v_restaurant_id, N'Chinese Starters', 7),
    (400070003009, v_restaurant_id, N'Mughlai Starters', 8),
    (400070003010, v_restaurant_id, N'Arabic Thaal', 9),
    (400070003011, v_restaurant_id, N'Shaan-e-Raan', 10),
    (400070003012, v_restaurant_id, N'Veg Starters', 11),
    (400070003013, v_restaurant_id, N'Pot-Biryani', 12),
    (400070003014, v_restaurant_id, N'Istanbul Kadai Special', 13),
    (400070003015, v_restaurant_id, N'Handi Special', 14),
    (400070003016, v_restaurant_id, N'Shorba', 15),
    (400070003017, v_restaurant_id, N'Salata', 16),
    (400070003018, v_restaurant_id, N'Roti', 17),
    (400070003019, v_restaurant_id, N'Rice', 18);

-- NOTE: 'Turkey Kebap' (category id 400070003001) is used for BOTH image1 (chicken) and
-- image7 (mutton) -- that is the literal printed header on both pages, not a
-- data-entry error. protein_type_id on each menu_item carries the real distinction.

-- ----------------------------------------------------------------------
-- Menu items (201 rows -- one row per dish after protein/portion splitting)
-- ----------------------------------------------------------------------
    -- ===== image1.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    -- icons: R
    (400070003001, v_restaurant_id, 400070003001, N'Turk Sia Kebab', N'turk sia kebab', N'Chicken Mince Steeped In A Marinade Of Black Pepper Mint, Coriander And Chargrilled', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- icons: W
    (400070003002, v_restaurant_id, 400070003001, N'Chicken Chapli Kebab', N'chicken chapli kebab', N'World Famous Chapli Kebab Made With Minced Chicken And Spices', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- icons: W
    (400070003003, v_restaurant_id, 400070003001, N'Shish Tawook', N'shish tawook', N'Chicken Marinated In Oliveoil, Sumac, Dried Herbs And Chargrilled', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003004, v_restaurant_id, 400070003001, N'Istanbul Tikka', N'istanbul tikka', N'Mildly Spiced Chicken Tikka Sprinkled With Sumac & Olive', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: R
    (400070003005, v_restaurant_id, 400070003001, N'Sicak Budu', N'sicak budu', N'Grilled Chicken Drumstick Infused With Flavourful Spices In Sizzling Plate', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003006, v_restaurant_id, 400070003001, N'Kafa Murgh', N'kafa murgh', N'Grilled Potato Stuffed With Blackpepper Cheese Sauce And Chicken Keema', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: W
    (400070003007, v_restaurant_id, 400070003001, N'Filfil Dajaj', N'filfil dajaj', N'Boneless Chicken Marinated With Blackpepper, Curd, Cumin And Tossed With Soothing White Sauce', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003008, v_restaurant_id, 400070003001, N'Tuscan Dajaj', N'tuscan dajaj', N'Soft Chicken Thigh Chunks Simmered In White Butter Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003009, v_restaurant_id, 400070003001, N'Poshida Kebab', N'poshida kebab', N'Grilled Chicken Tikka Topped With Smooth Creamy White Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003010, v_restaurant_id, 400070003001, N'Chicken Alakeiv', N'chicken alakeiv', N'Mildly Spiced Chicken Seekh Poured With Lebanese Cheese Sauce And Herbs', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- 390/740 printed with no explicit Half/Full header on this line -- interpreted as Half/Full by convention; REVIEW
    (400070003011, v_restaurant_id, 400070003001, N'Al Faham Dajaj', N'al faham dajaj', N'Arabic Styled Grilled Chicken Finished With Cheese', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003012, v_restaurant_id, 400070003001, N'Sizling Pottery Kebab', N'sizling pottery kebab', N'Bite Size Kebabs Immersed In Tahina Based White Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003013, v_restaurant_id, 400070003001, N'Arabian Roast', N'arabian roast', N'Roasted Chicken Marinated In Light Arabic Spices', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003014, v_restaurant_id, 400070003001, N'Escalope Chicken', N'escalope chicken', N'Thin Sliced Chicken Breast Fried Till Extra Crispy', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: W
    (400070003015, v_restaurant_id, 400070003001, N'Istanbul Dajaj Tandoori Khazana', N'istanbul dajaj tandoori khazana', N'Chef''s Special Chicken Mixed Platter', 'non_veg', v_protein_chicken, NULL, 'needs_review');

    -- ===== image2.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003016, v_restaurant_id, 400070003002, N'Veg Lemon Corianer Soup', N'veg lemon corianer soup', N'Clear Soup Made With Mix Vegetables Leamon And Coriander Leaves', 'veg', NULL, NULL, 'unverified'),
    (400070003017, v_restaurant_id, 400070003002, N'Veg Manchow Soup', N'veg manchow soup', N'A Veg Soup Made With Vegetables And Soya Sauce', 'veg', NULL, NULL, 'unverified'),
    -- icons: R
    (400070003018, v_restaurant_id, 400070003002, N'Chicken Manchow Soup', N'chicken manchow soup', N'A Chicken Soup Made With Freshly Cut Veggies, Ginger, Garlic And Soya Sauce', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003019, v_restaurant_id, 400070003002, N'Chicken Lung Fung Soup', N'chicken lung fung soup', N'Thicke Soup Made With Lemon, Chilli Pepper And Chinese Vegetable', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003020, v_restaurant_id, 400070003002, N'Prawn White Soup', N'prawn white soup', N'Soup Made With Coconut Cream, Prawns And Curry Leaves', 'non_veg', v_protein_seafood, NULL, 'unverified'),
    (400070003021, v_restaurant_id, 400070003002, N'Chicken Thai Noodles Soup', N'chicken thai noodles soup', N'Hot And Spicy Soup With Boiled Noodles And Coconut Cream', 'non_veg', v_protein_chicken, NULL, 'unverified');

    -- ===== image3.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003022, v_restaurant_id, 400070003003, N'Hummus', N'hummus', N'All Time Favorite Middle Eastern Dip', 'veg', NULL, NULL, 'unverified'),
    (400070003023, v_restaurant_id, 400070003003, N'Hummus with Paneer', N'hummus with paneer', N'Olive Oil Infused Hummus Topped With Fresh Cottage Cheese', 'veg', NULL, NULL, 'unverified'),
    -- icons: W
    (400070003024, v_restaurant_id, 400070003003, N'Hummus Bil Dajaj', N'hummus bil dajaj', N'Mashed Chickpea Hummus Topped With Grilled Chicken And Olive Oil', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003025, v_restaurant_id, 400070003003, N'Hummua Bil Laham', N'hummua bil laham', N'Hummus With Grilled Mutton On A Plate', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- protein mix of chicken+mutton, no single protein_type_id fits; left NULL
    (400070003026, v_restaurant_id, 400070003003, N'Meze Mix Hummus', N'meze mix hummus', N'Variety Of Hummus With Chicken And Mutton', 'non_veg', NULL, NULL, 'needs_review');

    -- ===== image4.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003027, v_restaurant_id, 400070003004, N'Green Salad', N'green salad', N'Classic Indian Green Salad', 'veg', NULL, NULL, 'unverified'),
    (400070003028, v_restaurant_id, 400070003004, N'Roasted Papad', N'roasted papad', N'Traditional Indian Munchies Roasted Over Charcoal', 'veg', NULL, NULL, 'unverified'),
    (400070003029, v_restaurant_id, 400070003004, N'Fried Papad', N'fried papad', N'Extra Crispy Urad Dal Papad', 'veg', NULL, NULL, 'unverified'),
    (400070003030, v_restaurant_id, 400070003004, N'Rice Papad', N'rice papad', N'Deep Fried Rice Papad', 'veg', NULL, NULL, 'unverified'),
    (400070003031, v_restaurant_id, 400070003004, N'Masala Papad', N'masala papad', N'Papad Topped With Onion, Tomato, Chaat Masala', 'veg', NULL, NULL, 'unverified'),
    (400070003032, v_restaurant_id, 400070003004, N'Chana Lasooni', N'chana lasooni', N'Boiled Chickpea Marinated With Koliwada Masala And Fried Till Extra Crispy', 'veg', NULL, NULL, 'unverified'),
    (400070003033, v_restaurant_id, 400070003004, N'French Fries', N'french fries', N'Lightly Salted Potato Fries', 'veg', NULL, NULL, 'unverified'),
    (400070003034, v_restaurant_id, 400070003004, N'Periperi French Fries', N'periperi french fries', N'Potato Fries Sprinkled With Peri Peri Mix', 'veg', NULL, NULL, 'unverified'),
    (400070003035, v_restaurant_id, 400070003004, N'Honey Chilli Fries', N'honey chilli fries', N'Sweet And Spicy French Fries Sprinkled With Sesame Seeds', 'veg', NULL, NULL, 'unverified'),
    (400070003036, v_restaurant_id, 400070003004, N'Fries Platter With Dips', N'fries platter with dips', N'French Fries With Combination Of Different Dips', 'veg', NULL, NULL, 'unverified'),
    -- icons: R
    (400070003037, v_restaurant_id, 400070003004, N'Karelian Chilli Fries', N'karelian chilli fries', N'Potato Fries Tossed With Green Chilli And Curry Leaves', 'veg', NULL, NULL, 'needs_review');

    -- ===== image5.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003038, v_restaurant_id, 400070003005, N'Istanbul Dajaj Chef''s Special Platter', N'istanbul dajaj chef''s special platter', N'Diffrent Type Chicken Kebabs, Accompanied With Rice, Chicken Gravy, And Butter Naan', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- mixed meat+chicken platter, protein_type_id left NULL
    (400070003039, v_restaurant_id, 400070003005, N'Istanbul Mix Chef''s Special Platter', N'istanbul mix chef''s special platter', N'Delicacy Of Meat & Chicken Assembled With Rice, Istanbul Kadai, And Butter Naan', 'non_veg', NULL, NULL, 'needs_review'),
    (400070003040, v_restaurant_id, 400070003005, N'Istanbul Laham Chef''s Special Platter', N'istanbul laham chef''s special platter', N'Diffrent Type Mutton Kebabs, Accompanied With Rice, Mutton Gravy, And Butter Naan', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- thali-style dish; NOT modeled as bundle -- see schema-gap note (bundle_component.component_menu_item_id is NOT NULL, so free-text components like 'Kulfi Tangdi' can't be attached without a standalone menu_item for each)
    (400070003041, v_restaurant_id, 400070003006, N'Mini Khazana Thaal', N'mini khazana thaal', N'Kulfi Tangdi, Chicken Chilli, Bihari Tikka, Akbari Handi, Garlic Naan & Kabsa Rice', 'non_veg', NULL, NULL, 'needs_review'),
    -- icons: W | thali-style dish; NOT modeled as bundle -- see schema-gap note
    (400070003042, v_restaurant_id, 400070003006, N'Istanbul Thaal', N'istanbul thaal', N'Soup, Turk Sia Kebab, Pepper Tikka, Murgh Matka Dum Kebab, Chicken In Masala & Rice', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- thali-style dish; NOT modeled as bundle -- see schema-gap note
    (400070003043, v_restaurant_id, 400070003006, N'Sultani Thaal', N'sultani thaal', N'Soup, Mutton Adana Kebab, Mutton Pepper Tikka, Mutton Matka Dum Kebab, Mutton In Masala & Rice', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- thali-style dish; NOT modeled as bundle -- see schema-gap note
    (400070003044, v_restaurant_id, 400070003006, N'Royal Mix Thaal', N'royal mix thaal', N'Soup, Hummus With Pita, 3 Variety Of Chicken Starters, 2 Mutton Starter, 2 Fish Starter, Mutton Kadai, Butter Naan, Fried Rice & Arabic Fruit Champagne', 'non_veg', NULL, NULL, 'needs_review');

    -- ===== image6.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003045, v_restaurant_id, 400070003007, N'Fried Rice (Veg)', N'fried rice (veg)', N'Stir Fried Rice Accompanied With Soya And Chinese Spices', 'veg', NULL, N'img6-fried_rice', 'unverified'),
    (400070003046, v_restaurant_id, 400070003007, N'Fried Rice (Chicken)', N'fried rice (chicken)', N'Stir Fried Rice Accompanied With Soya And Chinese Spices', 'non_veg', v_protein_chicken, N'img6-fried_rice', 'unverified'),
    (400070003047, v_restaurant_id, 400070003007, N'Fried Rice (Prawns)', N'fried rice (prawns)', N'Stir Fried Rice Accompanied With Soya And Chinese Spices', 'non_veg', v_protein_seafood, N'img6-fried_rice', 'unverified'),
    (400070003048, v_restaurant_id, 400070003007, N'Schezwan Fried Rice (Veg)', N'schezwan fried rice (veg)', N'A Spicy Twist Of Traditional Fried Rice With Schezwan Sauce', 'veg', NULL, N'img6-schezwan_fried_rice', 'unverified'),
    (400070003049, v_restaurant_id, 400070003007, N'Schezwan Fried Rice (Chicken)', N'schezwan fried rice (chicken)', N'A Spicy Twist Of Traditional Fried Rice With Schezwan Sauce', 'non_veg', v_protein_chicken, N'img6-schezwan_fried_rice', 'unverified'),
    (400070003050, v_restaurant_id, 400070003007, N'Schezwan Fried Rice (Prawns)', N'schezwan fried rice (prawns)', N'A Spicy Twist Of Traditional Fried Rice With Schezwan Sauce', 'non_veg', v_protein_seafood, N'img6-schezwan_fried_rice', 'unverified'),
    (400070003051, v_restaurant_id, 400070003007, N'Burnt Garlic Fried Rice (Veg)', N'burnt garlic fried rice (veg)', N'An Indo Chinese Variation Topped With Crispy Fried Garlic', 'veg', NULL, N'img6-burnt_garlic_fried_r', 'unverified'),
    (400070003052, v_restaurant_id, 400070003007, N'Burnt Garlic Fried Rice (Chicken)', N'burnt garlic fried rice (chicken)', N'An Indo Chinese Variation Topped With Crispy Fried Garlic', 'non_veg', v_protein_chicken, N'img6-burnt_garlic_fried_r', 'unverified'),
    (400070003053, v_restaurant_id, 400070003007, N'Burnt Garlic Fried Rice (Prawns)', N'burnt garlic fried rice (prawns)', N'An Indo Chinese Variation Topped With Crispy Fried Garlic', 'non_veg', v_protein_seafood, N'img6-burnt_garlic_fried_r', 'unverified'),
    (400070003054, v_restaurant_id, 400070003007, N'Oriental Fried Rice (Veg)', N'oriental fried rice (veg)', N'A Simple Fried Rice With Exotic Vegetables', 'veg', NULL, N'img6-oriental_fried_rice', 'unverified'),
    (400070003055, v_restaurant_id, 400070003007, N'Oriental Fried Rice (Chicken)', N'oriental fried rice (chicken)', N'A Simple Fried Rice With Exotic Vegetables', 'non_veg', v_protein_chicken, N'img6-oriental_fried_rice', 'unverified'),
    (400070003056, v_restaurant_id, 400070003007, N'Oriental Fried Rice (Prawns)', N'oriental fried rice (prawns)', N'A Simple Fried Rice With Exotic Vegetables', 'non_veg', v_protein_seafood, N'img6-oriental_fried_rice', 'unverified'),
    (400070003057, v_restaurant_id, 400070003007, N'Sweet Chilly Fried Rice (Veg)', N'sweet chilly fried rice (veg)', N'Sweet And Spicy Chinese Preparation Style', 'veg', NULL, N'img6-sweet_chilly_fried_r', 'unverified'),
    (400070003058, v_restaurant_id, 400070003007, N'Sweet Chilly Fried Rice (Chicken)', N'sweet chilly fried rice (chicken)', N'Sweet And Spicy Chinese Preparation Style', 'non_veg', v_protein_chicken, N'img6-sweet_chilly_fried_r', 'unverified'),
    (400070003059, v_restaurant_id, 400070003007, N'Sweet Chilly Fried Rice (Prawns)', N'sweet chilly fried rice (prawns)', N'Sweet And Spicy Chinese Preparation Style', 'non_veg', v_protein_seafood, N'img6-sweet_chilly_fried_r', 'unverified'),
    -- name describes one combination dish; NOT decomposed beyond the normal Veg/Chi/Prawns split (per doc's own worked rule)
    (400070003060, v_restaurant_id, 400070003007, N'Triple Schezwan Fried Rice (Veg)', N'triple schezwan fried rice (veg)', N'A Traditional Combination Of Schezwan Fried Rice With Noodles And Schezwan Gravy', 'veg', NULL, N'img6-triple_schezwan_frie', 'needs_review'),
    -- name describes one combination dish; NOT decomposed beyond the normal Veg/Chi/Prawns split (per doc's own worked rule)
    (400070003061, v_restaurant_id, 400070003007, N'Triple Schezwan Fried Rice (Chicken)', N'triple schezwan fried rice (chicken)', N'A Traditional Combination Of Schezwan Fried Rice With Noodles And Schezwan Gravy', 'non_veg', v_protein_chicken, N'img6-triple_schezwan_frie', 'needs_review'),
    -- name describes one combination dish; NOT decomposed beyond the normal Veg/Chi/Prawns split (per doc's own worked rule)
    (400070003062, v_restaurant_id, 400070003007, N'Triple Schezwan Fried Rice (Prawns)', N'triple schezwan fried rice (prawns)', N'A Traditional Combination Of Schezwan Fried Rice With Noodles And Schezwan Gravy', 'non_veg', v_protein_seafood, N'img6-triple_schezwan_frie', 'needs_review'),
    -- icons: W
    (400070003063, v_restaurant_id, 400070003007, N'Oriental Hot Pot Rice (Veg)', N'oriental hot pot rice (veg)', N'Unique Style Rice Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'veg', NULL, N'img6-oriental_hot_pot_ric', 'needs_review'),
    -- icons: W
    (400070003064, v_restaurant_id, 400070003007, N'Oriental Hot Pot Rice (Chicken)', N'oriental hot pot rice (chicken)', N'Unique Style Rice Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'non_veg', v_protein_chicken, N'img6-oriental_hot_pot_ric', 'needs_review'),
    -- icons: W
    (400070003065, v_restaurant_id, 400070003007, N'Oriental Hot Pot Rice (Prawns)', N'oriental hot pot rice (prawns)', N'Unique Style Rice Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'non_veg', v_protein_seafood, N'img6-oriental_hot_pot_ric', 'needs_review'),
    -- name describes one combination dish; NOT decomposed beyond the normal Veg/Chi/Prawns split (per doc's own worked rule)
    (400070003066, v_restaurant_id, 400070003007, N'Combination Pot Rice (Veg)', N'combination pot rice (veg)', N'Combination Of Rice And Noodles Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'veg', NULL, N'img6-combination_pot_rice', 'needs_review'),
    -- name describes one combination dish; NOT decomposed beyond the normal Veg/Chi/Prawns split (per doc's own worked rule)
    (400070003067, v_restaurant_id, 400070003007, N'Combination Pot Rice (Chicken)', N'combination pot rice (chicken)', N'Combination Of Rice And Noodles Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'non_veg', v_protein_chicken, N'img6-combination_pot_rice', 'needs_review'),
    -- name describes one combination dish; NOT decomposed beyond the normal Veg/Chi/Prawns split (per doc's own worked rule)
    (400070003068, v_restaurant_id, 400070003007, N'Combination Pot Rice (Prawns)', N'combination pot rice (prawns)', N'Combination Of Rice And Noodles Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'non_veg', v_protein_seafood, N'img6-combination_pot_rice', 'needs_review'),
    (400070003069, v_restaurant_id, 400070003007, N'Hakka Noodles (Veg)', N'hakka noodles (veg)', N'A Perfect Blend Of Boiled Noodles, Soya And Chinese Spices', 'veg', NULL, N'img6-hakka_noodles', 'unverified'),
    (400070003070, v_restaurant_id, 400070003007, N'Hakka Noodles (Chicken)', N'hakka noodles (chicken)', N'A Perfect Blend Of Boiled Noodles, Soya And Chinese Spices', 'non_veg', v_protein_chicken, N'img6-hakka_noodles', 'unverified'),
    (400070003071, v_restaurant_id, 400070003007, N'Hakka Noodles (Prawns)', N'hakka noodles (prawns)', N'A Perfect Blend Of Boiled Noodles, Soya And Chinese Spices', 'non_veg', v_protein_seafood, N'img6-hakka_noodles', 'unverified'),
    (400070003072, v_restaurant_id, 400070003007, N'Schezwan Noodles (Veg)', N'schezwan noodles (veg)', N'A Spicy Yet Flavoured Twist With Schezwan Sauce', 'veg', NULL, N'img6-schezwan_noodles', 'unverified'),
    (400070003073, v_restaurant_id, 400070003007, N'Schezwan Noodles (Chicken)', N'schezwan noodles (chicken)', N'A Spicy Yet Flavoured Twist With Schezwan Sauce', 'non_veg', v_protein_chicken, N'img6-schezwan_noodles', 'unverified'),
    (400070003074, v_restaurant_id, 400070003007, N'Schezwan Noodles (Prawns)', N'schezwan noodles (prawns)', N'A Spicy Yet Flavoured Twist With Schezwan Sauce', 'non_veg', v_protein_seafood, N'img6-schezwan_noodles', 'unverified'),
    (400070003075, v_restaurant_id, 400070003007, N'Burnt Garlic Noodles (Veg)', N'burnt garlic noodles (veg)', N'An Indo Chinese Noodles Variation Topped With Crispy Fried Garlic', 'veg', NULL, N'img6-burnt_garlic_noodles', 'unverified'),
    (400070003076, v_restaurant_id, 400070003007, N'Burnt Garlic Noodles (Chicken)', N'burnt garlic noodles (chicken)', N'An Indo Chinese Noodles Variation Topped With Crispy Fried Garlic', 'non_veg', v_protein_chicken, N'img6-burnt_garlic_noodles', 'unverified'),
    (400070003077, v_restaurant_id, 400070003007, N'Burnt Garlic Noodles (Prawns)', N'burnt garlic noodles (prawns)', N'An Indo Chinese Noodles Variation Topped With Crispy Fried Garlic', 'non_veg', v_protein_seafood, N'img6-burnt_garlic_noodles', 'unverified'),
    (400070003078, v_restaurant_id, 400070003007, N'Triple Schezwan Noodles (Veg)', N'triple schezwan noodles (veg)', N'A Traditional Combination Of Schezwan Noodles And Schezwan Gravy', 'veg', NULL, N'img6-triple_schezwan_nood', 'unverified'),
    (400070003079, v_restaurant_id, 400070003007, N'Triple Schezwan Noodles (Chicken)', N'triple schezwan noodles (chicken)', N'A Traditional Combination Of Schezwan Noodles And Schezwan Gravy', 'non_veg', v_protein_chicken, N'img6-triple_schezwan_nood', 'unverified'),
    (400070003080, v_restaurant_id, 400070003007, N'Triple Schezwan Noodles (Prawns)', N'triple schezwan noodles (prawns)', N'A Traditional Combination Of Schezwan Noodles And Schezwan Gravy', 'non_veg', v_protein_seafood, N'img6-triple_schezwan_nood', 'unverified'),
    (400070003081, v_restaurant_id, 400070003007, N'Oriental Hot Pot Noodles (Veg)', N'oriental hot pot noodles (veg)', N'Unique Style Noodles Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'veg', NULL, N'img6-oriental_hot_pot_noo', 'unverified'),
    (400070003082, v_restaurant_id, 400070003007, N'Oriental Hot Pot Noodles (Chicken)', N'oriental hot pot noodles (chicken)', N'Unique Style Noodles Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'non_veg', v_protein_chicken, N'img6-oriental_hot_pot_noo', 'unverified'),
    (400070003083, v_restaurant_id, 400070003007, N'Oriental Hot Pot Noodles (Prawns)', N'oriental hot pot noodles (prawns)', N'Unique Style Noodles Cooked In Earten Clay Pot Topped With Spicy Black Gravy', 'non_veg', v_protein_seafood, N'img6-oriental_hot_pot_noo', 'unverified');

    -- ===== image7.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    -- icons: R
    (400070003084, v_restaurant_id, 400070003001, N'Mutton Adana Kebab', N'mutton adana kebab', N'A Foot Long Spicy Mutton Kebab Grilled Over Red Hot Charcoal', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- icons: W
    (400070003085, v_restaurant_id, 400070003001, N'Mutton Pista Kebab', N'mutton pista kebab', N'Mutton Mince Marinated In Hand Pounded Turkish Spices And Pistachios', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- icons: W
    (400070003086, v_restaurant_id, 400070003001, N'Pashto Laham', N'pashto laham', N'Grilled Mutton Chunks Marinated In Spices Finished With Oliveoil And Toasted Sesame Seed', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    (400070003087, v_restaurant_id, 400070003001, N'Mutton Al Faham', N'mutton al faham', N'Mildly Spiced Mutton Grilled Over Charcoal Accompanied With French Fries And Lebanese Sauce', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003088, v_restaurant_id, 400070003001, N'Mutton Sil Rosh', N'mutton sil rosh', N'Turkish Mutton Tikka Topped With Spicy Sauce Finished With Sumac', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003089, v_restaurant_id, 400070003001, N'Mashwi Laham', N'mashwi laham', N'Juicy Meat Grilled On Charcoal Sprincled With Lime And Seasoning', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003090, v_restaurant_id, 400070003001, N'Filfil Laham', N'filfil laham', N'Mutton Marinated With Blackpepper, Curd, Cumin And Tossed', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003091, v_restaurant_id, 400070003001, N'Mutton Chapli Kebab', N'mutton chapli kebab', N'Ground Mutton Mince Infused With Flavourful Spices Shallowfried On Pan', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- lamb chops classified as protein_type=mutton
    (400070003092, v_restaurant_id, 400070003001, N'Buryan Chop', N'buryan chop', N'Tender Grilled Lamb Chops On Pitabread Sprinkled With Roasted Sesame & Olive Oil', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    (400070003093, v_restaurant_id, 400070003001, N'Shishlik Chops', N'shishlik chops', N'Charcoal Grilled Chops Poured With Spicy Sauce', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003094, v_restaurant_id, 400070003001, N'Mutton Turkey Nalli', N'mutton turkey nalli', N'Grilled Bone Shanks Sauted With Turkish Cheese Sauce', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- icons: W
    (400070003095, v_restaurant_id, 400070003001, N'Mutton Turkey Rosh', N'mutton turkey rosh', N'Extra Soft Mutton Simmered With Garlic Pods, Carrot, Onion & Blackpepper', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- mixed chicken+mutton, protein_type_id left NULL
    (400070003096, v_restaurant_id, 400070003001, N'Istanbul Mix Tandoori Khazana', N'istanbul mix tandoori khazana', N'Chef''s Special Mutton & Chicken Mix Platter', 'non_veg', NULL, NULL, 'needs_review'),
    -- icons: W
    (400070003097, v_restaurant_id, 400070003001, N'Istanbul Laham Tandoori Khazana', N'istanbul laham tandoori khazana', N'Chef''s Special Mutton Mix Platter', 'non_veg', v_protein_mutton, NULL, 'needs_review');

    -- ===== image8.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003098, v_restaurant_id, 400070003008, N'Chicken Lolipop (6 Pcs)', N'chicken lolipop (6 pcs)', N'A Crispy Fried Chicken Lolipop', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003099, v_restaurant_id, 400070003008, N'Crispy Dry', N'crispy dry', N'Perfectly Balanced Sweet And Spicy Crispy Chicken Strips', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003100, v_restaurant_id, 400070003008, N'Cajun Chicken', N'cajun chicken', N'Chicken Chunncks Sauted In Cajun Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003101, v_restaurant_id, 400070003008, N'Bbq Dry', N'bbq dry', N'Chicken Chunks Tossed In Dark Barbeque Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003102, v_restaurant_id, 400070003008, N'Pineapple Pepper Chicken', N'pineapple pepper chicken', N'Hot And Sweet Flavoured Chicken With Pineapple Chunks', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003103, v_restaurant_id, 400070003008, N'Orange Chicken', N'orange chicken', N'Chicken Tossed In Chef Special Spicy And Tangy Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: W+R | protein not explicit in own description (no 'chicken'/'chunks' stated); inferred chicken from surrounding section context -- REVIEW
    (400070003104, v_restaurant_id, 400070003008, N'Oyester Chilli', N'oyester chilli', N'Tossed In Salty Oyster Sauce With The Hint Of Chilli', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003105, v_restaurant_id, 400070003008, N'Red Thai Dry', N'red thai dry', N'Chicken Seared With Red Thai Sauce With Coconut Cream', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003106, v_restaurant_id, 400070003008, N'Black Bean Dry', N'black bean dry', N'Chicken Tossed In Black Bean Sauce With Red Yellow Capsicum', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: R
    (400070003107, v_restaurant_id, 400070003008, N'Dynamite Peri Peri Chicken', N'dynamite peri peri chicken', N'A Hot And Spicy Chicken For Extra Zing', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- icons: W
    (400070003108, v_restaurant_id, 400070003008, N'White Sauce Chicken', N'white sauce chicken', N'Medium Spiced Chicken In White Cheese Sauce', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003109, v_restaurant_id, 400070003008, N'Lemon Grass Chicken', N'lemon grass chicken', N'Medium Spiced Chicken In Yellow Sauce With Hint Of Lemongrass', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: R
    (400070003110, v_restaurant_id, 400070003008, N'Prawns Dynamite', N'prawns dynamite', N'A Hot And Spicy Prawns For Extra Zing', 'non_veg', v_protein_seafood, NULL, 'needs_review'),
    (400070003111, v_restaurant_id, 400070003008, N'Butter Garlic Prawns', N'butter garlic prawns', N'A Simple Prawn Dish Glazed With Butter', 'non_veg', v_protein_seafood, NULL, 'unverified'),
    (400070003112, v_restaurant_id, 400070003008, N'Prawns Sweet Chilli', N'prawns sweet chilli', N'Prawns Tossed In Honey And Hot Sauce', 'non_veg', v_protein_seafood, NULL, 'unverified');

    -- ===== image9.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003113, v_restaurant_id, 400070003009, N'Surkh Murgh Tikka', N'surkh murgh tikka', N'All Time Favorite Succulent Chicken Tikka', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003114, v_restaurant_id, 400070003009, N'Murgh Burrah', N'murgh burrah', N'Tender Chicken Thigh Flavored With Red Spices And Finished With Cream', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003115, v_restaurant_id, 400070003009, N'Nizami Tikka', N'nizami tikka', N'Succulent Chicken Tikka Infused With Medium Spicy Cheese Sause', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003116, v_restaurant_id, 400070003009, N'Peri peri Tikka', N'peri peri tikka', N'Grilled Chicken Sauted In All Time Favorite Peri Peri Spices To Give Some Extra Zing', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003117, v_restaurant_id, 400070003009, N'Pepper Tikka', N'pepper tikka', N'Grilled Chicken Sauted In Butter, Garlic And Blackpepper', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003118, v_restaurant_id, 400070003009, N'Tangdi Ghee Roast', N'tangdi ghee roast', N'Chicken Drumsticks Sauted In Ginger Garlic Green Chilli Past With Hint Of Carrom Seed', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003119, v_restaurant_id, 400070003009, N'Chicken Cafriyal Roast', N'chicken cafriyal roast', N'A Signature Green Marination With Onions And Bellpepper', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003120, v_restaurant_id, 400070003009, N'Murgh Kulfi Tangdi', N'murgh kulfi tangdi', N'Chicken Drumsticks Grilled With Cashew Based Marinate And Cheese Sauce', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003121, v_restaurant_id, 400070003009, N'Mutton Tikka', N'mutton tikka', N'All Time Favorite Succulent Mutton Tikka', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003122, v_restaurant_id, 400070003009, N'Masala Laham Chops', N'masala laham chops', N'Grilled Chops Sauted With Red Indian Sauce', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003123, v_restaurant_id, 400070003009, N'Albaik Peri Peri Fish', N'albaik peri peri fish', N'Medium Spiced Fish Fried And Sprinkled With Spicy Peperiri Masala', 'non_veg', v_protein_seafood, NULL, 'unverified'),
    (400070003124, v_restaurant_id, 400070003009, N'Fish Tikka', N'fish tikka', N'Fish Marinated In Red Spices And Grilled Over Charcoal', 'non_veg', v_protein_seafood, NULL, 'unverified'),
    (400070003125, v_restaurant_id, 400070003009, N'Koliwada Prawns', N'koliwada prawns', N'Prawns Marinated In Red Masala Fried And Finished With Chaat Masala', 'non_veg', v_protein_seafood, NULL, 'unverified'),
    (400070003126, v_restaurant_id, 400070003009, N'Prawns Tandoori', N'prawns tandoori', N'Red And Spicy Prawns Grilled Over Charcoal', 'non_veg', v_protein_seafood, NULL, 'unverified');

    -- ===== image10.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003127, v_restaurant_id, 400070003010, N'Chicken Al Faham Mandi Thaal', N'chicken al faham mandi thaal', N'Traditional Arabic Rice Cooked With Stock Water And Arabic Spices', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: W
    (400070003128, v_restaurant_id, 400070003010, N'Chicken Istanbuli Kabsa Thaal', N'chicken istanbuli kabsa thaal', N'A Perfect Balance Of Red Hot & Smocky Gravy Mixed With Long Gain Rice And Cooked To Perfection', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- icons: W
    (400070003129, v_restaurant_id, 400070003010, N'Chicken Nizami Kabsa Thaal', N'chicken nizami kabsa thaal', N'Unique Flavour Of Curryleaves, Carraway Seed And Slit Green Chillies Infused In Chicken And Rice', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003130, v_restaurant_id, 400070003010, N'Chicken Yakhni Kabsa Thaal', N'chicken yakhni kabsa thaal', N'Medium Spiced Gravy Accompanied With Long Grain Rice Served In Thaal', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003131, v_restaurant_id, 400070003010, N'Mutton Haneeth Mandi Thaal', N'mutton haneeth mandi thaal', N'Traditional Yemeni Rice Cooked With Stock Water And Arabic Spices', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003132, v_restaurant_id, 400070003010, N'Mutton Zurbian Mandi Thaal', N'mutton zurbian mandi thaal', N'Traditional Yemeni Rice Cooked With Extra Soft Mutton Pieces', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003133, v_restaurant_id, 400070003010, N'Mutton Istanbuli kabsa Thaal', N'mutton istanbuli kabsa thaal', N'A Perfect Balance Of Red Hot & Smocky Gravy Mixed With Long Grain Rice And Cooked To Perfection', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003134, v_restaurant_id, 400070003010, N'Mutton Nizami Kabsa Thaal', N'mutton nizami kabsa thaal', N'Unique Flavour Of Curryleaves, Carraway Seed And Slit Green Chillies Infused In Mutton And Rice', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- single price printed, no Half/Full split shown for this item
    (400070003135, v_restaurant_id, 400070003010, N'Raan Mandi Thaal', N'raan mandi thaal', N'Perfectly Cooked Mutton With Delicate Spices Served With Saffron Infused Mandi Rice', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- single price printed, no Half/Full split shown for this item
    (400070003136, v_restaurant_id, 400070003010, N'Raan Kabsa Thaal', N'raan kabsa thaal', N'Mutton Served With Spicy Red Rice With Red Sauce', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- single price printed, no Half/Full split shown for this item
    (400070003137, v_restaurant_id, 400070003010, N'Raan Biryani Thaal', N'raan biryani thaal', N'Delicious Biryani Cooked With Specific Lamb Cut And Long Grain Basmati Rice', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- single price printed, no Half/Full split shown for this item
    (400070003138, v_restaurant_id, 400070003010, N'Raan Mushakkal Thaal', N'raan mushakkal thaal', N'Variety Of Rice With Perfectly Grilled Mutton Leg', 'non_veg', v_protein_mutton, NULL, 'needs_review');

    -- ===== image11.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003139, v_restaurant_id, 400070003011, N'Raan Tandoori Dry', N'raan tandoori dry', N'Mutton Leg Boiled And Grilled With Red Spicy Masala', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- icons: R
    (400070003140, v_restaurant_id, 400070003011, N'Raan Masala', N'raan masala', N'Grilled Mutton Raan With Red Thick Spicy Gravy', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    (400070003141, v_restaurant_id, 400070003011, N'Raan Musallam', N'raan musallam', N'Coal Smoked Gravy With Grilled Raan Tandoori', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003142, v_restaurant_id, 400070003011, N'Raan Nizami', N'raan nizami', N'Mutton Leg Grilled And Tossed With White Cheese Sauce', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003143, v_restaurant_id, 400070003011, N'Raan Chilli', N'raan chilli', N'Mutton Raan Accompanied With Black Chilli Gravy', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003144, v_restaurant_id, 400070003012, N'Surkh paneer', N'surkh paneer', N'All Time Favorite Succulent Paneer Tikka', 'veg', NULL, NULL, 'unverified'),
    (400070003145, v_restaurant_id, 400070003012, N'Cajun Potato', N'cajun potato', N'Crispy Baby Potato Finished With Cajun Sauce', 'veg', NULL, NULL, 'unverified'),
    (400070003146, v_restaurant_id, 400070003012, N'Deccan Paneer', N'deccan paneer', N'South East Asain Cottage Cheese Delicacy', 'veg', NULL, NULL, 'unverified'),
    (400070003147, v_restaurant_id, 400070003012, N'Aatishi Aaloo', N'aatishi aaloo', N'Selected Potatoes Cooked With Red, Yellow Chilli Powder,Mustard And Filled With Paneer Mix', 'veg', NULL, NULL, 'unverified'),
    (400070003148, v_restaurant_id, 400070003012, N'Cheese Seekh', N'cheese seekh', N'Scrambled Malai Paneer And Cheese Delicately Flavored And Chargrilled', 'veg', NULL, NULL, 'unverified');

    -- ===== image12.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003149, v_restaurant_id, 400070003013, N'Veg Birista Biryani', N'veg birista biryani', N'Basmati Rice Cooked With Cottage Cheese, Vegetable In Rich Onion-Tomato Gravy And Sealed In Earthen Pot', 'veg', NULL, NULL, 'unverified'),
    (400070003150, v_restaurant_id, 400070003013, N'Veg Paneer Tikka Biryani', N'veg paneer tikka biryani', N'Chargrilled Paneer Tikka Cubes Cooked With Sauce, Basmati Rice On Dum In Sealed Earthen Pot', 'veg', NULL, NULL, 'unverified'),
    -- icons: W
    (400070003151, v_restaurant_id, 400070003013, N'Murgh Birista Biryani (On Bone)', N'murgh birista biryani (on bone)', N'Chicken On Bone Cooked In Nawabi Masala With Saffron Flavored Rice On Dum In Sealed Earthen Pot', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003152, v_restaurant_id, 400070003013, N'Murgh Tikka Biryani', N'murgh tikka biryani', N'Delicately Flavored Chargrilled Chicken Tikka Cooked And Aromatic Basmati Rice On Dum In Earthen Pot', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- distinct dish from 'Murgh Birista Biryani (On Bone)' above -- same base name, no bone qualifier, different price (480/830 vs 460/830)
    (400070003153, v_restaurant_id, 400070003013, N'Murgh Birista Biryani', N'murgh birista biryani', N'Medium Spiced Chicken Cooked In Onion, Tomato And Spices With Basmati Rice On Dum In Sealed Earthen Pot', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070003154, v_restaurant_id, 400070003013, N'Murgh Malai Seekh Biryani', N'murgh malai seekh biryani', N'Grilled Chicken Seekh Laced With Onion Julian And Rich Indian Masala', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070003155, v_restaurant_id, 400070003013, N'Mutton Birista Biryani', N'mutton birista biryani', N'Chunks Of Mutton Flavored With Cardamom, Coriander, Blackpepper, Star Anies Garnished With Golden Fried Onion', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003156, v_restaurant_id, 400070003013, N'Mutton Tikka Biryani', N'mutton tikka biryani', N'Delicately Flavored Chargrilled Mutton Tikka Cooked With Red Gravy And Aromatic Basmati Rice On Dum In Earthen Pot', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003157, v_restaurant_id, 400070003013, N'Prawns Birista Biryani', N'prawns birista biryani', N'Prawns Cooked With Onion, Tomato, And Whole Spices', 'non_veg', v_protein_seafood, NULL, 'unverified'),
    (400070003158, v_restaurant_id, 400070003013, N'Prawns Tikka Biryani', N'prawns tikka biryani', N'Grilled & Spicy Prawns Cooked In Red Gravy And Aromatic Basmati Rice', 'non_veg', v_protein_seafood, NULL, 'unverified');

    -- ===== image13.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    -- icons: W+R
    (400070003159, v_restaurant_id, 400070003014, N'Koyla Kadai (Chicken)', N'koyla kadai (chicken)', N'A Smokey Kadai Cooked And Served In Thick Deep Skillet', 'non_veg', v_protein_chicken, N'img13-koyla_kadai', 'needs_review'),
    -- icons: W+R
    (400070003160, v_restaurant_id, 400070003014, N'Koyla Kadai (Mutton)', N'koyla kadai (mutton)', N'A Smokey Kadai Cooked And Served In Thick Deep Skillet', 'non_veg', v_protein_mutton, N'img13-koyla_kadai', 'needs_review'),
    -- icons: R
    (400070003161, v_restaurant_id, 400070003014, N'Kalimiri Kadai (Chicken)', N'kalimiri kadai (chicken)', N'Black Pepper Spiced Kadai Cooked In Onion Tomato Base', 'non_veg', v_protein_chicken, N'img13-kalimiri_kadai', 'needs_review'),
    -- icons: R
    (400070003162, v_restaurant_id, 400070003014, N'Kalimiri Kadai (Mutton)', N'kalimiri kadai (mutton)', N'Black Pepper Spiced Kadai Cooked In Onion Tomato Base', 'non_veg', v_protein_mutton, N'img13-kalimiri_kadai', 'needs_review'),
    (400070003163, v_restaurant_id, 400070003014, N'Changezi Kadai (Chicken)', N'changezi kadai (chicken)', N'Coal Smoked Red Tomato Gravy Cooked With Grilled Chunks', 'non_veg', v_protein_chicken, N'img13-changezi_kadai', 'unverified'),
    (400070003164, v_restaurant_id, 400070003014, N'Changezi Kadai (Mutton)', N'changezi kadai (mutton)', N'Coal Smoked Red Tomato Gravy Cooked With Grilled Chunks', 'non_veg', v_protein_mutton, N'img13-changezi_kadai', 'unverified'),
    (400070003165, v_restaurant_id, 400070003014, N'Afghani Kadai (Chicken)', N'afghani kadai (chicken)', N'Medium Spiced White Kadai Finished With Butter', 'non_veg', v_protein_chicken, N'img13-afghani_kadai', 'unverified'),
    (400070003166, v_restaurant_id, 400070003014, N'Afghani Kadai (Mutton)', N'afghani kadai (mutton)', N'Medium Spiced White Kadai Finished With Butter', 'non_veg', v_protein_mutton, N'img13-afghani_kadai', 'unverified'),
    (400070003167, v_restaurant_id, 400070003014, N'Akhbari Kadai (Chicken)', N'akhbari kadai (chicken)', N'Chargrilled Cubes Cooked With Yellow Aromatic Gravy With Settled Flavour', 'non_veg', v_protein_chicken, N'img13-akhbari_kadai', 'unverified'),
    (400070003168, v_restaurant_id, 400070003014, N'Akhbari Kadai (Mutton)', N'akhbari kadai (mutton)', N'Chargrilled Cubes Cooked With Yellow Aromatic Gravy With Settled Flavour', 'non_veg', v_protein_mutton, N'img13-akhbari_kadai', 'unverified'),
    (400070003169, v_restaurant_id, 400070003014, N'Tikka Kadai (Chicken)', N'tikka kadai (chicken)', N'Grilled Tikka Simmered In Medium Spiced Tomato Gravy', 'non_veg', v_protein_chicken, N'img13-tikka_kadai', 'unverified'),
    (400070003170, v_restaurant_id, 400070003014, N'Tikka Kadai (Mutton)', N'tikka kadai (mutton)', N'Grilled Tikka Simmered In Medium Spiced Tomato Gravy', 'non_veg', v_protein_mutton, N'img13-tikka_kadai', 'unverified'),
    (400070003171, v_restaurant_id, 400070003014, N'Angara Kadai (Chicken)', N'angara kadai (chicken)', N'Spicy Chunks Panfried With Red Hot Gravy', 'non_veg', v_protein_chicken, N'img13-angara_kadai', 'unverified'),
    (400070003172, v_restaurant_id, 400070003014, N'Angara Kadai (Mutton)', N'angara kadai (mutton)', N'Spicy Chunks Panfried With Red Hot Gravy', 'non_veg', v_protein_mutton, N'img13-angara_kadai', 'unverified'),
    (400070003173, v_restaurant_id, 400070003015, N'Mutton Korma', N'mutton korma', N'A Royal Dish Prepared From Meat, Curd, Spices For Heavenly Taste', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003174, v_restaurant_id, 400070003015, N'Mutton Dopyaza', N'mutton dopyaza', N'Mutton Seared With Onion, Spices And Curd And Smoked With Coal To Perfection', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003175, v_restaurant_id, 400070003015, N'Mutton White Korma', N'mutton white korma', N'Age Old Recipe Of Mutton Cooked For Hours Together For Royal Palate', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003176, v_restaurant_id, 400070003015, N'Mutton Bhuna', N'mutton bhuna', N'Mutton Preparation In Spicy Onion Based Sauce', 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070003177, v_restaurant_id, 400070003015, N'Mutton Istanbuli Handi', N'mutton istanbuli handi', N'Chef''s Mutton Preparation In Thin Brown Gravy', 'non_veg', v_protein_mutton, NULL, 'unverified');

    -- ===== image14.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    -- icons: W
    (400070003178, v_restaurant_id, 400070003016, N'Kabuli Shorba', N'kabuli shorba', N'Chef Special Soup Cooked With Barley, Lentils, Veggies And Stock Water', 'veg', NULL, NULL, 'needs_review'),
    (400070003179, v_restaurant_id, 400070003016, N'Turkey Lentil Shorba', N'turkey lentil shorba', N'Lentils Cooked With Tomatoes, Carrot And Celery Infused With Garlic And Herbs', 'veg', NULL, NULL, 'unverified'),
    (400070003180, v_restaurant_id, 400070003016, N'Murgh Yakhni Shorba', N'murgh yakhni shorba', N'Chicken Stock Cooked With Fresh Indian Aromatic Spices', 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- icons: W
    (400070003181, v_restaurant_id, 400070003016, N'Aab Gosht', N'aab gosht', N'Mutton Yakhni Cooked With White Chickpea And Freshly Crushed Herbs', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- lamb classified as protein_type=mutton
    (400070003182, v_restaurant_id, 400070003016, N'Traditional lamb Turkish Shorba', N'traditional lamb turkish shorba', N'Lamb Cubes Immersed In Delicious Soup Gravy Spiced With Freshly Pounded Black Pepper', 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- icons: W
    (400070003183, v_restaurant_id, 400070003017, N'Arabian Fattoush Salad With Olive Oil', N'arabian fattoush salad with olive oil', N'Arabic Salad With Lettuce, Olive, Bellpepper, Squeeze Of Lime And Oliveoil', 'veg', NULL, NULL, 'needs_review'),
    -- icons: W
    (400070003184, v_restaurant_id, 400070003017, N'Chicken Mayo Salad', N'chicken mayo salad', N'Combination Of Chicken, Mayoniese, Green Leaves And A Hint Of Spices', 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- icons: R
    (400070003185, v_restaurant_id, 400070003017, N'Dynamite Potato Salad', N'dynamite potato salad', N'Fried Potato Chunks Sprinkled With Lime And Spices', 'veg', NULL, NULL, 'needs_review'),
    (400070003186, v_restaurant_id, 400070003017, N'Salata Platter', N'salata platter', N'A Mix Of Salad, Hummus And French Fries', 'veg', NULL, NULL, 'unverified');

    -- ===== image15.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070003187, v_restaurant_id, 400070003018, N'Tandoori Roti', N'tandoori roti', N'Wheat Based Brown Roti Prepared In Tandoor', 'veg', NULL, NULL, 'unverified'),
    (400070003188, v_restaurant_id, 400070003018, N'Butter Tandoori Roti', N'butter tandoori roti', N'Melted Butter Glazed On Hot Tandoori Roti', 'veg', NULL, NULL, 'unverified'),
    -- icons: W
    (400070003189, v_restaurant_id, 400070003018, N'Kulcha', N'kulcha', N'A Special Bread Made With Milk, Fennil Powder And Herbs', 'veg', NULL, NULL, 'needs_review'),
    (400070003190, v_restaurant_id, 400070003018, N'Butter Kulcha', N'butter kulcha', N'Soft Fluffy Bread Glazed With Butter', 'veg', NULL, NULL, 'unverified'),
    (400070003191, v_restaurant_id, 400070003018, N'Naan', N'naan', N'White Flour Dough Mixed With Coriander', 'veg', NULL, NULL, 'unverified'),
    (400070003192, v_restaurant_id, 400070003018, N'Butter Naan', N'butter naan', N'White Flour Dough Mixed With Coriander And Topped With Butter', 'veg', NULL, NULL, 'unverified'),
    (400070003193, v_restaurant_id, 400070003018, N'Garlic Butter Naan', N'garlic butter naan', N'Fresh Garlic Pierced In White Flour Dough Topped With Butter', 'veg', NULL, NULL, 'unverified'),
    (400070003194, v_restaurant_id, 400070003018, N'Chilli Garlic Naan', N'chilli garlic naan', N'Slit Chillies And Garlic Layed Naan Baked In Tandoor', 'veg', NULL, NULL, 'unverified'),
    (400070003195, v_restaurant_id, 400070003018, N'Cheese Garlic Naan', N'cheese garlic naan', N'Grated Cheese Layed On White Flat Bread And Baked In Tandoor', 'veg', NULL, NULL, 'unverified'),
    -- icons: W
    (400070003196, v_restaurant_id, 400070003018, N'Laccha Paratha (Desi Ghee)', N'laccha paratha (desi ghee)', N'Wheat Based Bread Prepared On Skillet With Desi Ghee', 'veg', NULL, NULL, 'needs_review'),
    (400070003197, v_restaurant_id, 400070003019, N'Zeera Rice', N'zeera rice', N'Steamed Rice Temperad With Cumin Seeds', 'veg', NULL, NULL, 'unverified'),
    (400070003198, v_restaurant_id, 400070003019, N'Steam Rice', N'steam rice', N'Steamed Long Grain Fragrant Rice', 'veg', NULL, NULL, 'unverified'),
    (400070003199, v_restaurant_id, 400070003019, N'Biryani Rice', N'biryani rice', N'Long Grain Basmati Rice Cooked On Dum', 'veg', NULL, NULL, 'unverified'),
    (400070003200, v_restaurant_id, 400070003019, N'Kabsa Rice', N'kabsa rice', N'Arabic Rice Delicacy', 'veg', NULL, NULL, 'unverified'),
    (400070003201, v_restaurant_id, 400070003019, N'Mandi Rice', N'mandi rice', N'Arabic Rice Preparation', 'veg', NULL, NULL, 'unverified');

-- ----------------------------------------------------------------------
-- Item provenance (confidence 0.97 for clean reads, 0.65 for anything flagged)
-- ----------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, confidence, verification_status_code)
VALUES
    (400070003001, v_source_id, 0.65, 'needs_review'),
    (400070003002, v_source_id, 0.65, 'needs_review'),
    (400070003003, v_source_id, 0.65, 'needs_review'),
    (400070003004, v_source_id, 0.97, 'unverified'),
    (400070003005, v_source_id, 0.65, 'needs_review'),
    (400070003006, v_source_id, 0.97, 'unverified'),
    (400070003007, v_source_id, 0.65, 'needs_review'),
    (400070003008, v_source_id, 0.97, 'unverified'),
    (400070003009, v_source_id, 0.97, 'unverified'),
    (400070003010, v_source_id, 0.97, 'unverified'),
    (400070003011, v_source_id, 0.65, 'needs_review'),
    (400070003012, v_source_id, 0.97, 'unverified'),
    (400070003013, v_source_id, 0.97, 'unverified'),
    (400070003014, v_source_id, 0.97, 'unverified'),
    (400070003015, v_source_id, 0.65, 'needs_review'),
    (400070003016, v_source_id, 0.97, 'unverified'),
    (400070003017, v_source_id, 0.97, 'unverified'),
    (400070003018, v_source_id, 0.65, 'needs_review'),
    (400070003019, v_source_id, 0.97, 'unverified'),
    (400070003020, v_source_id, 0.97, 'unverified'),
    (400070003021, v_source_id, 0.97, 'unverified'),
    (400070003022, v_source_id, 0.97, 'unverified'),
    (400070003023, v_source_id, 0.97, 'unverified'),
    (400070003024, v_source_id, 0.65, 'needs_review'),
    (400070003025, v_source_id, 0.97, 'unverified'),
    (400070003026, v_source_id, 0.65, 'needs_review'),
    (400070003027, v_source_id, 0.97, 'unverified'),
    (400070003028, v_source_id, 0.97, 'unverified'),
    (400070003029, v_source_id, 0.97, 'unverified'),
    (400070003030, v_source_id, 0.97, 'unverified'),
    (400070003031, v_source_id, 0.97, 'unverified'),
    (400070003032, v_source_id, 0.97, 'unverified'),
    (400070003033, v_source_id, 0.97, 'unverified'),
    (400070003034, v_source_id, 0.97, 'unverified'),
    (400070003035, v_source_id, 0.97, 'unverified'),
    (400070003036, v_source_id, 0.97, 'unverified'),
    (400070003037, v_source_id, 0.65, 'needs_review'),
    (400070003038, v_source_id, 0.97, 'unverified'),
    (400070003039, v_source_id, 0.65, 'needs_review'),
    (400070003040, v_source_id, 0.97, 'unverified'),
    (400070003041, v_source_id, 0.65, 'needs_review'),
    (400070003042, v_source_id, 0.65, 'needs_review'),
    (400070003043, v_source_id, 0.65, 'needs_review'),
    (400070003044, v_source_id, 0.65, 'needs_review'),
    (400070003045, v_source_id, 0.97, 'unverified'),
    (400070003046, v_source_id, 0.97, 'unverified'),
    (400070003047, v_source_id, 0.97, 'unverified'),
    (400070003048, v_source_id, 0.97, 'unverified'),
    (400070003049, v_source_id, 0.97, 'unverified'),
    (400070003050, v_source_id, 0.97, 'unverified'),
    (400070003051, v_source_id, 0.97, 'unverified'),
    (400070003052, v_source_id, 0.97, 'unverified'),
    (400070003053, v_source_id, 0.97, 'unverified'),
    (400070003054, v_source_id, 0.97, 'unverified'),
    (400070003055, v_source_id, 0.97, 'unverified'),
    (400070003056, v_source_id, 0.97, 'unverified'),
    (400070003057, v_source_id, 0.97, 'unverified'),
    (400070003058, v_source_id, 0.97, 'unverified'),
    (400070003059, v_source_id, 0.97, 'unverified'),
    (400070003060, v_source_id, 0.65, 'needs_review'),
    (400070003061, v_source_id, 0.65, 'needs_review'),
    (400070003062, v_source_id, 0.65, 'needs_review'),
    (400070003063, v_source_id, 0.65, 'needs_review'),
    (400070003064, v_source_id, 0.65, 'needs_review'),
    (400070003065, v_source_id, 0.65, 'needs_review'),
    (400070003066, v_source_id, 0.65, 'needs_review'),
    (400070003067, v_source_id, 0.65, 'needs_review'),
    (400070003068, v_source_id, 0.65, 'needs_review'),
    (400070003069, v_source_id, 0.97, 'unverified'),
    (400070003070, v_source_id, 0.97, 'unverified'),
    (400070003071, v_source_id, 0.97, 'unverified'),
    (400070003072, v_source_id, 0.97, 'unverified'),
    (400070003073, v_source_id, 0.97, 'unverified'),
    (400070003074, v_source_id, 0.97, 'unverified'),
    (400070003075, v_source_id, 0.97, 'unverified'),
    (400070003076, v_source_id, 0.97, 'unverified'),
    (400070003077, v_source_id, 0.97, 'unverified'),
    (400070003078, v_source_id, 0.97, 'unverified'),
    (400070003079, v_source_id, 0.97, 'unverified'),
    (400070003080, v_source_id, 0.97, 'unverified'),
    (400070003081, v_source_id, 0.97, 'unverified'),
    (400070003082, v_source_id, 0.97, 'unverified'),
    (400070003083, v_source_id, 0.97, 'unverified'),
    (400070003084, v_source_id, 0.65, 'needs_review'),
    (400070003085, v_source_id, 0.65, 'needs_review'),
    (400070003086, v_source_id, 0.65, 'needs_review'),
    (400070003087, v_source_id, 0.97, 'unverified'),
    (400070003088, v_source_id, 0.97, 'unverified'),
    (400070003089, v_source_id, 0.97, 'unverified'),
    (400070003090, v_source_id, 0.97, 'unverified'),
    (400070003091, v_source_id, 0.97, 'unverified'),
    (400070003092, v_source_id, 0.65, 'needs_review'),
    (400070003093, v_source_id, 0.97, 'unverified'),
    (400070003094, v_source_id, 0.97, 'unverified'),
    (400070003095, v_source_id, 0.65, 'needs_review'),
    (400070003096, v_source_id, 0.65, 'needs_review'),
    (400070003097, v_source_id, 0.65, 'needs_review'),
    (400070003098, v_source_id, 0.97, 'unverified'),
    (400070003099, v_source_id, 0.97, 'unverified'),
    (400070003100, v_source_id, 0.97, 'unverified'),
    (400070003101, v_source_id, 0.97, 'unverified'),
    (400070003102, v_source_id, 0.97, 'unverified'),
    (400070003103, v_source_id, 0.97, 'unverified'),
    (400070003104, v_source_id, 0.65, 'needs_review'),
    (400070003105, v_source_id, 0.97, 'unverified'),
    (400070003106, v_source_id, 0.97, 'unverified'),
    (400070003107, v_source_id, 0.65, 'needs_review'),
    (400070003108, v_source_id, 0.65, 'needs_review'),
    (400070003109, v_source_id, 0.97, 'unverified'),
    (400070003110, v_source_id, 0.65, 'needs_review'),
    (400070003111, v_source_id, 0.97, 'unverified'),
    (400070003112, v_source_id, 0.97, 'unverified'),
    (400070003113, v_source_id, 0.97, 'unverified'),
    (400070003114, v_source_id, 0.97, 'unverified'),
    (400070003115, v_source_id, 0.97, 'unverified'),
    (400070003116, v_source_id, 0.97, 'unverified'),
    (400070003117, v_source_id, 0.97, 'unverified'),
    (400070003118, v_source_id, 0.97, 'unverified'),
    (400070003119, v_source_id, 0.97, 'unverified'),
    (400070003120, v_source_id, 0.97, 'unverified'),
    (400070003121, v_source_id, 0.97, 'unverified'),
    (400070003122, v_source_id, 0.97, 'unverified'),
    (400070003123, v_source_id, 0.97, 'unverified'),
    (400070003124, v_source_id, 0.97, 'unverified'),
    (400070003125, v_source_id, 0.97, 'unverified'),
    (400070003126, v_source_id, 0.97, 'unverified'),
    (400070003127, v_source_id, 0.97, 'unverified'),
    (400070003128, v_source_id, 0.65, 'needs_review'),
    (400070003129, v_source_id, 0.65, 'needs_review'),
    (400070003130, v_source_id, 0.97, 'unverified'),
    (400070003131, v_source_id, 0.97, 'unverified'),
    (400070003132, v_source_id, 0.97, 'unverified'),
    (400070003133, v_source_id, 0.97, 'unverified'),
    (400070003134, v_source_id, 0.97, 'unverified'),
    (400070003135, v_source_id, 0.65, 'needs_review'),
    (400070003136, v_source_id, 0.65, 'needs_review'),
    (400070003137, v_source_id, 0.65, 'needs_review'),
    (400070003138, v_source_id, 0.65, 'needs_review'),
    (400070003139, v_source_id, 0.97, 'unverified'),
    (400070003140, v_source_id, 0.65, 'needs_review'),
    (400070003141, v_source_id, 0.97, 'unverified'),
    (400070003142, v_source_id, 0.97, 'unverified'),
    (400070003143, v_source_id, 0.97, 'unverified'),
    (400070003144, v_source_id, 0.97, 'unverified'),
    (400070003145, v_source_id, 0.97, 'unverified'),
    (400070003146, v_source_id, 0.97, 'unverified'),
    (400070003147, v_source_id, 0.97, 'unverified'),
    (400070003148, v_source_id, 0.97, 'unverified'),
    (400070003149, v_source_id, 0.97, 'unverified'),
    (400070003150, v_source_id, 0.97, 'unverified'),
    (400070003151, v_source_id, 0.65, 'needs_review'),
    (400070003152, v_source_id, 0.97, 'unverified'),
    (400070003153, v_source_id, 0.65, 'needs_review'),
    (400070003154, v_source_id, 0.97, 'unverified'),
    (400070003155, v_source_id, 0.97, 'unverified'),
    (400070003156, v_source_id, 0.97, 'unverified'),
    (400070003157, v_source_id, 0.97, 'unverified'),
    (400070003158, v_source_id, 0.97, 'unverified'),
    (400070003159, v_source_id, 0.65, 'needs_review'),
    (400070003160, v_source_id, 0.65, 'needs_review'),
    (400070003161, v_source_id, 0.65, 'needs_review'),
    (400070003162, v_source_id, 0.65, 'needs_review'),
    (400070003163, v_source_id, 0.97, 'unverified'),
    (400070003164, v_source_id, 0.97, 'unverified'),
    (400070003165, v_source_id, 0.97, 'unverified'),
    (400070003166, v_source_id, 0.97, 'unverified'),
    (400070003167, v_source_id, 0.97, 'unverified'),
    (400070003168, v_source_id, 0.97, 'unverified'),
    (400070003169, v_source_id, 0.97, 'unverified'),
    (400070003170, v_source_id, 0.97, 'unverified'),
    (400070003171, v_source_id, 0.97, 'unverified'),
    (400070003172, v_source_id, 0.97, 'unverified'),
    (400070003173, v_source_id, 0.97, 'unverified'),
    (400070003174, v_source_id, 0.97, 'unverified'),
    (400070003175, v_source_id, 0.97, 'unverified'),
    (400070003176, v_source_id, 0.97, 'unverified'),
    (400070003177, v_source_id, 0.97, 'unverified'),
    (400070003178, v_source_id, 0.65, 'needs_review'),
    (400070003179, v_source_id, 0.97, 'unverified'),
    (400070003180, v_source_id, 0.97, 'unverified'),
    (400070003181, v_source_id, 0.65, 'needs_review'),
    (400070003182, v_source_id, 0.65, 'needs_review'),
    (400070003183, v_source_id, 0.65, 'needs_review'),
    (400070003184, v_source_id, 0.65, 'needs_review'),
    (400070003185, v_source_id, 0.65, 'needs_review'),
    (400070003186, v_source_id, 0.97, 'unverified'),
    (400070003187, v_source_id, 0.97, 'unverified'),
    (400070003188, v_source_id, 0.97, 'unverified'),
    (400070003189, v_source_id, 0.65, 'needs_review'),
    (400070003190, v_source_id, 0.97, 'unverified'),
    (400070003191, v_source_id, 0.97, 'unverified'),
    (400070003192, v_source_id, 0.97, 'unverified'),
    (400070003193, v_source_id, 0.97, 'unverified'),
    (400070003194, v_source_id, 0.97, 'unverified'),
    (400070003195, v_source_id, 0.97, 'unverified'),
    (400070003196, v_source_id, 0.65, 'needs_review'),
    (400070003197, v_source_id, 0.97, 'unverified'),
    (400070003198, v_source_id, 0.97, 'unverified'),
    (400070003199, v_source_id, 0.97, 'unverified'),
    (400070003200, v_source_id, 0.97, 'unverified'),
    (400070003201, v_source_id, 0.97, 'unverified');

-- ----------------------------------------------------------------------
-- Variants (242 rows -- portion/protein-split pricing units)
-- ----------------------------------------------------------------------
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400070003001, 400070003001, N'Full', 'fixed', TRUE),
    (400070003002, 400070003002, N'Full', 'fixed', TRUE),
    (400070003003, 400070003003, N'Full', 'fixed', TRUE),
    (400070003004, 400070003004, N'Full', 'fixed', TRUE),
    (400070003005, 400070003005, N'Full', 'fixed', TRUE),
    (400070003006, 400070003006, N'Full', 'fixed', TRUE),
    (400070003007, 400070003007, N'Full', 'fixed', TRUE),
    (400070003008, 400070003008, N'Full', 'fixed', TRUE),
    (400070003009, 400070003009, N'Full', 'fixed', TRUE),
    (400070003010, 400070003010, N'Full', 'fixed', TRUE),
    (400070003011, 400070003011, N'Half', 'fixed', FALSE),
    (400070003012, 400070003011, N'Full', 'fixed', FALSE),
    (400070003013, 400070003012, N'Full', 'fixed', TRUE),
    (400070003014, 400070003013, N'Full', 'fixed', TRUE),
    (400070003015, 400070003014, N'Full', 'fixed', TRUE),
    (400070003016, 400070003015, N'Full', 'fixed', TRUE),
    (400070003017, 400070003016, N'Full', 'fixed', TRUE),
    (400070003018, 400070003017, N'Full', 'fixed', TRUE),
    (400070003019, 400070003018, N'Full', 'fixed', TRUE),
    (400070003020, 400070003019, N'Full', 'fixed', TRUE),
    (400070003021, 400070003020, N'Full', 'fixed', TRUE),
    (400070003022, 400070003021, N'Full', 'fixed', TRUE),
    (400070003023, 400070003022, N'Full', 'fixed', TRUE),
    (400070003024, 400070003023, N'Full', 'fixed', TRUE),
    (400070003025, 400070003024, N'Full', 'fixed', TRUE),
    (400070003026, 400070003025, N'Full', 'fixed', TRUE),
    (400070003027, 400070003026, N'Full', 'fixed', TRUE),
    (400070003028, 400070003027, N'Full', 'fixed', TRUE),
    (400070003029, 400070003028, N'Full', 'fixed', TRUE),
    (400070003030, 400070003029, N'Full', 'fixed', TRUE),
    (400070003031, 400070003030, N'Full', 'fixed', TRUE),
    (400070003032, 400070003031, N'Full', 'fixed', TRUE),
    (400070003033, 400070003032, N'Full', 'fixed', TRUE),
    (400070003034, 400070003033, N'Full', 'fixed', TRUE),
    (400070003035, 400070003034, N'Full', 'fixed', TRUE),
    (400070003036, 400070003035, N'Full', 'fixed', TRUE),
    (400070003037, 400070003036, N'Full', 'fixed', TRUE),
    (400070003038, 400070003037, N'Full', 'fixed', TRUE),
    (400070003039, 400070003038, N'Small', 'fixed', FALSE),
    (400070003040, 400070003038, N'Big', 'fixed', FALSE),
    (400070003041, 400070003039, N'Small', 'fixed', FALSE),
    (400070003042, 400070003039, N'Big', 'fixed', FALSE),
    (400070003043, 400070003040, N'Small', 'fixed', FALSE),
    (400070003044, 400070003040, N'Big', 'fixed', FALSE),
    (400070003045, 400070003041, N'Full', 'fixed', TRUE),
    (400070003046, 400070003042, N'Full', 'fixed', TRUE),
    (400070003047, 400070003043, N'Full', 'fixed', TRUE),
    (400070003048, 400070003044, N'Full', 'fixed', TRUE),
    (400070003049, 400070003045, N'Full', 'fixed', TRUE),
    (400070003050, 400070003046, N'Full', 'fixed', TRUE),
    (400070003051, 400070003047, N'Full', 'fixed', TRUE),
    (400070003052, 400070003048, N'Full', 'fixed', TRUE),
    (400070003053, 400070003049, N'Full', 'fixed', TRUE),
    (400070003054, 400070003050, N'Full', 'fixed', TRUE),
    (400070003055, 400070003051, N'Full', 'fixed', TRUE),
    (400070003056, 400070003052, N'Full', 'fixed', TRUE),
    (400070003057, 400070003053, N'Full', 'fixed', TRUE),
    (400070003058, 400070003054, N'Full', 'fixed', TRUE),
    (400070003059, 400070003055, N'Full', 'fixed', TRUE),
    (400070003060, 400070003056, N'Full', 'fixed', TRUE),
    (400070003061, 400070003057, N'Full', 'fixed', TRUE),
    (400070003062, 400070003058, N'Full', 'fixed', TRUE),
    (400070003063, 400070003059, N'Full', 'fixed', TRUE),
    (400070003064, 400070003060, N'Full', 'fixed', TRUE),
    (400070003065, 400070003061, N'Full', 'fixed', TRUE),
    (400070003066, 400070003062, N'Full', 'fixed', TRUE),
    (400070003067, 400070003063, N'Full', 'fixed', TRUE),
    (400070003068, 400070003064, N'Full', 'fixed', TRUE),
    (400070003069, 400070003065, N'Full', 'fixed', TRUE),
    (400070003070, 400070003066, N'Full', 'fixed', TRUE),
    (400070003071, 400070003067, N'Full', 'fixed', TRUE),
    (400070003072, 400070003068, N'Full', 'fixed', TRUE),
    (400070003073, 400070003069, N'Full', 'fixed', TRUE),
    (400070003074, 400070003070, N'Full', 'fixed', TRUE),
    (400070003075, 400070003071, N'Full', 'fixed', TRUE),
    (400070003076, 400070003072, N'Full', 'fixed', TRUE),
    (400070003077, 400070003073, N'Full', 'fixed', TRUE),
    (400070003078, 400070003074, N'Full', 'fixed', TRUE),
    (400070003079, 400070003075, N'Full', 'fixed', TRUE),
    (400070003080, 400070003076, N'Full', 'fixed', TRUE),
    (400070003081, 400070003077, N'Full', 'fixed', TRUE),
    (400070003082, 400070003078, N'Full', 'fixed', TRUE),
    (400070003083, 400070003079, N'Full', 'fixed', TRUE),
    (400070003084, 400070003080, N'Full', 'fixed', TRUE),
    (400070003085, 400070003081, N'Full', 'fixed', TRUE),
    (400070003086, 400070003082, N'Full', 'fixed', TRUE),
    (400070003087, 400070003083, N'Full', 'fixed', TRUE),
    (400070003088, 400070003084, N'Full', 'fixed', TRUE),
    (400070003089, 400070003085, N'Full', 'fixed', TRUE),
    (400070003090, 400070003086, N'Full', 'fixed', TRUE),
    (400070003091, 400070003087, N'Full', 'fixed', TRUE),
    (400070003092, 400070003088, N'Full', 'fixed', TRUE),
    (400070003093, 400070003089, N'Full', 'fixed', TRUE),
    (400070003094, 400070003090, N'Full', 'fixed', TRUE),
    (400070003095, 400070003091, N'Full', 'fixed', TRUE),
    (400070003096, 400070003092, N'Full', 'fixed', TRUE),
    (400070003097, 400070003093, N'Full', 'fixed', TRUE),
    (400070003098, 400070003094, N'Full', 'fixed', TRUE),
    (400070003099, 400070003095, N'Full', 'fixed', TRUE),
    (400070003100, 400070003096, N'Full', 'fixed', TRUE),
    (400070003101, 400070003097, N'Full', 'fixed', TRUE),
    (400070003102, 400070003098, N'Full', 'fixed', TRUE),
    (400070003103, 400070003099, N'Full', 'fixed', TRUE),
    (400070003104, 400070003100, N'Full', 'fixed', TRUE),
    (400070003105, 400070003101, N'Full', 'fixed', TRUE),
    (400070003106, 400070003102, N'Full', 'fixed', TRUE),
    (400070003107, 400070003103, N'Full', 'fixed', TRUE),
    (400070003108, 400070003104, N'Full', 'fixed', TRUE),
    (400070003109, 400070003105, N'Full', 'fixed', TRUE),
    (400070003110, 400070003106, N'Full', 'fixed', TRUE),
    (400070003111, 400070003107, N'Full', 'fixed', TRUE),
    (400070003112, 400070003108, N'Full', 'fixed', TRUE),
    (400070003113, 400070003109, N'Full', 'fixed', TRUE),
    (400070003114, 400070003110, N'Full', 'fixed', TRUE),
    (400070003115, 400070003111, N'Full', 'fixed', TRUE),
    (400070003116, 400070003112, N'Full', 'fixed', TRUE),
    (400070003117, 400070003113, N'Full', 'fixed', TRUE),
    (400070003118, 400070003114, N'Full', 'fixed', TRUE),
    (400070003119, 400070003115, N'Full', 'fixed', TRUE),
    (400070003120, 400070003116, N'Full', 'fixed', TRUE),
    (400070003121, 400070003117, N'Full', 'fixed', TRUE),
    (400070003122, 400070003118, N'Full', 'fixed', TRUE),
    (400070003123, 400070003119, N'Full', 'fixed', TRUE),
    (400070003124, 400070003120, N'Full', 'fixed', TRUE),
    (400070003125, 400070003121, N'Full', 'fixed', TRUE),
    (400070003126, 400070003122, N'Full', 'fixed', TRUE),
    (400070003127, 400070003123, N'Full', 'fixed', TRUE),
    (400070003128, 400070003124, N'Full', 'fixed', TRUE),
    (400070003129, 400070003125, N'Full', 'fixed', TRUE),
    (400070003130, 400070003126, N'Full', 'fixed', TRUE),
    (400070003131, 400070003127, N'Half', 'fixed', FALSE),
    (400070003132, 400070003127, N'Full', 'fixed', FALSE),
    (400070003133, 400070003128, N'Half', 'fixed', FALSE),
    (400070003134, 400070003128, N'Full', 'fixed', FALSE),
    (400070003135, 400070003129, N'Half', 'fixed', FALSE),
    (400070003136, 400070003129, N'Full', 'fixed', FALSE),
    (400070003137, 400070003130, N'Half', 'fixed', FALSE),
    (400070003138, 400070003130, N'Full', 'fixed', FALSE),
    (400070003139, 400070003131, N'Half', 'fixed', FALSE),
    (400070003140, 400070003131, N'Full', 'fixed', FALSE),
    (400070003141, 400070003132, N'Half', 'fixed', FALSE),
    (400070003142, 400070003132, N'Full', 'fixed', FALSE),
    (400070003143, 400070003133, N'Half', 'fixed', FALSE),
    (400070003144, 400070003133, N'Full', 'fixed', FALSE),
    (400070003145, 400070003134, N'Half', 'fixed', FALSE),
    (400070003146, 400070003134, N'Full', 'fixed', FALSE),
    (400070003147, 400070003135, N'Full', 'fixed', TRUE),
    (400070003148, 400070003136, N'Full', 'fixed', TRUE),
    (400070003149, 400070003137, N'Full', 'fixed', TRUE),
    (400070003150, 400070003138, N'Full', 'fixed', TRUE),
    (400070003151, 400070003139, N'Full', 'fixed', TRUE),
    (400070003152, 400070003140, N'Full', 'fixed', TRUE),
    (400070003153, 400070003141, N'Full', 'fixed', TRUE),
    (400070003154, 400070003142, N'Full', 'fixed', TRUE),
    (400070003155, 400070003143, N'Full', 'fixed', TRUE),
    (400070003156, 400070003144, N'Full', 'fixed', TRUE),
    (400070003157, 400070003145, N'Full', 'fixed', TRUE),
    (400070003158, 400070003146, N'Full', 'fixed', TRUE),
    (400070003159, 400070003147, N'Full', 'fixed', TRUE),
    (400070003160, 400070003148, N'Full', 'fixed', TRUE),
    (400070003161, 400070003149, N'Double', 'fixed', FALSE),
    (400070003162, 400070003149, N'Family', 'fixed', FALSE),
    (400070003163, 400070003150, N'Double', 'fixed', FALSE),
    (400070003164, 400070003150, N'Family', 'fixed', FALSE),
    (400070003165, 400070003151, N'Double', 'fixed', FALSE),
    (400070003166, 400070003151, N'Family', 'fixed', FALSE),
    (400070003167, 400070003152, N'Double', 'fixed', FALSE),
    (400070003168, 400070003152, N'Family', 'fixed', FALSE),
    (400070003169, 400070003153, N'Double', 'fixed', FALSE),
    (400070003170, 400070003153, N'Family', 'fixed', FALSE),
    (400070003171, 400070003154, N'Double', 'fixed', FALSE),
    (400070003172, 400070003154, N'Family', 'fixed', FALSE),
    (400070003173, 400070003155, N'Double', 'fixed', FALSE),
    (400070003174, 400070003155, N'Family', 'fixed', FALSE),
    (400070003175, 400070003156, N'Double', 'fixed', FALSE),
    (400070003176, 400070003156, N'Family', 'fixed', FALSE),
    (400070003177, 400070003157, N'Double', 'fixed', FALSE),
    (400070003178, 400070003157, N'Family', 'fixed', FALSE),
    (400070003179, 400070003158, N'Double', 'fixed', FALSE),
    (400070003180, 400070003158, N'Family', 'fixed', FALSE),
    (400070003181, 400070003159, N'Half', 'fixed', FALSE),
    (400070003182, 400070003159, N'Full', 'fixed', FALSE),
    (400070003183, 400070003160, N'Half', 'fixed', FALSE),
    (400070003184, 400070003160, N'Full', 'fixed', FALSE),
    (400070003185, 400070003161, N'Half', 'fixed', FALSE),
    (400070003186, 400070003161, N'Full', 'fixed', FALSE),
    (400070003187, 400070003162, N'Half', 'fixed', FALSE),
    (400070003188, 400070003162, N'Full', 'fixed', FALSE),
    (400070003189, 400070003163, N'Half', 'fixed', FALSE),
    (400070003190, 400070003163, N'Full', 'fixed', FALSE),
    (400070003191, 400070003164, N'Half', 'fixed', FALSE),
    (400070003192, 400070003164, N'Full', 'fixed', FALSE),
    (400070003193, 400070003165, N'Half', 'fixed', FALSE),
    (400070003194, 400070003165, N'Full', 'fixed', FALSE),
    (400070003195, 400070003166, N'Half', 'fixed', FALSE),
    (400070003196, 400070003166, N'Full', 'fixed', FALSE),
    (400070003197, 400070003167, N'Half', 'fixed', FALSE),
    (400070003198, 400070003167, N'Full', 'fixed', FALSE),
    (400070003199, 400070003168, N'Half', 'fixed', FALSE),
    (400070003200, 400070003168, N'Full', 'fixed', FALSE),
    (400070003201, 400070003169, N'Half', 'fixed', FALSE),
    (400070003202, 400070003169, N'Full', 'fixed', FALSE),
    (400070003203, 400070003170, N'Half', 'fixed', FALSE),
    (400070003204, 400070003170, N'Full', 'fixed', FALSE),
    (400070003205, 400070003171, N'Half', 'fixed', FALSE),
    (400070003206, 400070003171, N'Full', 'fixed', FALSE),
    (400070003207, 400070003172, N'Half', 'fixed', FALSE),
    (400070003208, 400070003172, N'Full', 'fixed', FALSE),
    (400070003209, 400070003173, N'Half', 'fixed', FALSE),
    (400070003210, 400070003173, N'Full', 'fixed', FALSE),
    (400070003211, 400070003174, N'Half', 'fixed', FALSE),
    (400070003212, 400070003174, N'Full', 'fixed', FALSE),
    (400070003213, 400070003175, N'Half', 'fixed', FALSE),
    (400070003214, 400070003175, N'Full', 'fixed', FALSE),
    (400070003215, 400070003176, N'Half', 'fixed', FALSE),
    (400070003216, 400070003176, N'Full', 'fixed', FALSE),
    (400070003217, 400070003177, N'Half', 'fixed', FALSE),
    (400070003218, 400070003177, N'Full', 'fixed', FALSE),
    (400070003219, 400070003178, N'Full', 'fixed', TRUE),
    (400070003220, 400070003179, N'Full', 'fixed', TRUE),
    (400070003221, 400070003180, N'Full', 'fixed', TRUE),
    (400070003222, 400070003181, N'Full', 'fixed', TRUE),
    (400070003223, 400070003182, N'Full', 'fixed', TRUE),
    (400070003224, 400070003183, N'Full', 'fixed', TRUE),
    (400070003225, 400070003184, N'Full', 'fixed', TRUE),
    (400070003226, 400070003185, N'Full', 'fixed', TRUE),
    (400070003227, 400070003186, N'Full', 'fixed', TRUE),
    (400070003228, 400070003187, N'Full', 'fixed', TRUE),
    (400070003229, 400070003188, N'Full', 'fixed', TRUE),
    (400070003230, 400070003189, N'Full', 'fixed', TRUE),
    (400070003231, 400070003190, N'Full', 'fixed', TRUE),
    (400070003232, 400070003191, N'Full', 'fixed', TRUE),
    (400070003233, 400070003192, N'Full', 'fixed', TRUE),
    (400070003234, 400070003193, N'Full', 'fixed', TRUE),
    (400070003235, 400070003194, N'Full', 'fixed', TRUE),
    (400070003236, 400070003195, N'Full', 'fixed', TRUE),
    (400070003237, 400070003196, N'Full', 'fixed', TRUE),
    (400070003238, 400070003197, N'Full', 'fixed', TRUE),
    (400070003239, 400070003198, N'Full', 'fixed', TRUE),
    (400070003240, 400070003199, N'Full', 'fixed', TRUE),
    (400070003241, 400070003200, N'Full', 'fixed', TRUE),
    (400070003242, 400070003201, N'Full', 'fixed', TRUE);

-- ----------------------------------------------------------------------
-- Prices (242 rows, 1:1 with variants -- exclusive of GST, see note 2 at top)
-- ----------------------------------------------------------------------
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
VALUES
    (400070003001, 400070003001, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003002, 400070003002, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003003, 400070003003, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003004, 400070003004, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003005, 400070003005, 610, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003006, 400070003006, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003007, 400070003007, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003008, 400070003008, 580, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003009, 400070003009, 580, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003010, 400070003010, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003011, 400070003011, 390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003012, 400070003012, 740, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003013, 400070003013, 610, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003014, 400070003014, 690, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003015, 400070003015, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003016, 400070003016, 1190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003017, 400070003017, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003018, 400070003018, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003019, 400070003019, 220, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003020, 400070003020, 220, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003021, 400070003021, 240, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003022, 400070003022, 240, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003023, 400070003023, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003024, 400070003024, 220, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003025, 400070003025, 240, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003026, 400070003026, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003027, 400070003027, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003028, 400070003028, 90, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003029, 400070003029, 30, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003030, 400070003030, 30, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003031, 400070003031, 30, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003032, 400070003032, 60, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003033, 400070003033, 150, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003034, 400070003034, 140, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003035, 400070003035, 160, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003036, 400070003036, 200, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003037, 400070003037, 280, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003038, 400070003038, 180, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003039, 400070003039, 4190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003040, 400070003040, 7190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003041, 400070003041, 4990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003042, 400070003042, 9190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003043, 400070003043, 6190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003044, 400070003044, 12190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003045, 400070003045, 2490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003046, 400070003046, 2990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003047, 400070003047, 4490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003048, 400070003048, 6990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003049, 400070003049, 290, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003050, 400070003050, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003051, 400070003051, 350, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003052, 400070003052, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003053, 400070003053, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003054, 400070003054, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003055, 400070003055, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003056, 400070003056, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003057, 400070003057, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003058, 400070003058, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003059, 400070003059, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003060, 400070003060, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003061, 400070003061, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003062, 400070003062, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003063, 400070003063, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003064, 400070003064, 340, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003065, 400070003065, 390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003066, 400070003066, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003067, 400070003067, 340, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003068, 400070003068, 390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003069, 400070003069, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003070, 400070003070, 340, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003071, 400070003071, 390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003072, 400070003072, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003073, 400070003073, 290, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003074, 400070003074, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003075, 400070003075, 350, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003076, 400070003076, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003077, 400070003077, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003078, 400070003078, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003079, 400070003079, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003080, 400070003080, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003081, 400070003081, 430, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003082, 400070003082, 340, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003083, 400070003083, 390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003084, 400070003084, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003085, 400070003085, 340, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003086, 400070003086, 390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003087, 400070003087, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003088, 400070003088, 590, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003089, 400070003089, 690, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003090, 400070003090, 750, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003091, 400070003091, 890, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003092, 400070003092, 890, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003093, 400070003093, 890, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003094, 400070003094, 850, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003095, 400070003095, 850, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003096, 400070003096, 1250, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003097, 400070003097, 1250, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003098, 400070003098, 1390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003099, 400070003099, 890, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003100, 400070003100, 1990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003101, 400070003101, 2190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003102, 400070003102, 320, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003103, 400070003103, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003104, 400070003104, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003105, 400070003105, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003106, 400070003106, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003107, 400070003107, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003108, 400070003108, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003109, 400070003109, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003110, 400070003110, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003111, 400070003111, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003112, 400070003112, 420, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003113, 400070003113, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003114, 400070003114, 690, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003115, 400070003115, 690, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003116, 400070003116, 690, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003117, 400070003117, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003118, 400070003118, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003119, 400070003119, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003120, 400070003120, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003121, 400070003121, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003122, 400070003122, 560, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003123, 400070003123, 380, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003124, 400070003124, 640, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003125, 400070003125, 750, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003126, 400070003126, 1250, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003127, 400070003127, 550, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003128, 400070003128, 550, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003129, 400070003129, 650, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003130, 400070003130, 690, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003131, 400070003131, 890, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003132, 400070003132, 1780, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003133, 400070003133, 1090, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003134, 400070003134, 2150, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003135, 400070003135, 1090, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003136, 400070003136, 2150, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003137, 400070003137, 750, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003138, 400070003138, 1390, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003139, 400070003139, 1190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003140, 400070003140, 2190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003141, 400070003141, 1250, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003142, 400070003142, 2400, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003143, 400070003143, 990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003144, 400070003144, 1990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003145, 400070003145, 990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003146, 400070003146, 1990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003147, 400070003147, 2200, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003148, 400070003148, 2200, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003149, 400070003149, 2200, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003150, 400070003150, 2400, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003151, 400070003151, 1890, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003152, 400070003152, 1990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003153, 400070003153, 2190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003154, 400070003154, 2190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003155, 400070003155, 1990, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003156, 400070003156, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003157, 400070003157, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003158, 400070003158, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003159, 400070003159, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003160, 400070003160, 360, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003161, 400070003161, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003162, 400070003162, 770, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003163, 400070003163, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003164, 400070003164, 770, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003165, 400070003165, 460, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003166, 400070003166, 830, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003167, 400070003167, 480, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003168, 400070003168, 830, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003169, 400070003169, 480, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003170, 400070003170, 830, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003171, 400070003171, 480, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003172, 400070003172, 830, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003173, 400070003173, 600, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003174, 400070003174, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003175, 400070003175, 600, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003176, 400070003176, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003177, 400070003177, 600, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003178, 400070003178, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003179, 400070003179, 600, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003180, 400070003180, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003181, 400070003181, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003182, 400070003182, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003183, 400070003183, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003184, 400070003184, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003185, 400070003185, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003186, 400070003186, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003187, 400070003187, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003188, 400070003188, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003189, 400070003189, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003190, 400070003190, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003191, 400070003191, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003192, 400070003192, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003193, 400070003193, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003194, 400070003194, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003195, 400070003195, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003196, 400070003196, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003197, 400070003197, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003198, 400070003198, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003199, 400070003199, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003200, 400070003200, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003201, 400070003201, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003202, 400070003202, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003203, 400070003203, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003204, 400070003204, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003205, 400070003205, 490, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003206, 400070003206, 980, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003207, 400070003207, 950, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003208, 400070003208, 1880, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003209, 400070003209, 450, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003210, 400070003210, 870, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003211, 400070003211, 450, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003212, 400070003212, 870, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003213, 400070003213, 450, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003214, 400070003214, 870, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003215, 400070003215, 450, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003216, 400070003216, 870, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003217, 400070003217, 450, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003218, 400070003218, 870, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003219, 400070003219, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003220, 400070003220, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003221, 400070003221, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003222, 400070003222, 240, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003223, 400070003223, 280, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003224, 400070003224, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003225, 400070003225, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003226, 400070003226, 190, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003227, 400070003227, 250, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003228, 400070003228, 30, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003229, 400070003229, 40, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003230, 400070003230, 40, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003231, 400070003231, 50, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003232, 400070003232, 50, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003233, 400070003233, 60, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003234, 400070003234, 70, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003235, 400070003235, 70, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003236, 400070003236, 140, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003237, 400070003237, 90, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070003238, 400070003238, 120, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003239, 400070003239, 120, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003240, 400070003240, 160, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003241, 400070003241, 180, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070003242, 400070003242, 180, 'exclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

-- ----------------------------------------------------------------------
-- Attach every category and every item to the A La Carte board
-- ----------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (v_restaurant_id, v_board_id, 400070003001, 0),
    (v_restaurant_id, v_board_id, 400070003002, 1),
    (v_restaurant_id, v_board_id, 400070003003, 2),
    (v_restaurant_id, v_board_id, 400070003004, 3),
    (v_restaurant_id, v_board_id, 400070003005, 4),
    (v_restaurant_id, v_board_id, 400070003006, 5),
    (v_restaurant_id, v_board_id, 400070003007, 6),
    (v_restaurant_id, v_board_id, 400070003008, 7),
    (v_restaurant_id, v_board_id, 400070003009, 8),
    (v_restaurant_id, v_board_id, 400070003010, 9),
    (v_restaurant_id, v_board_id, 400070003011, 10),
    (v_restaurant_id, v_board_id, 400070003012, 11),
    (v_restaurant_id, v_board_id, 400070003013, 12),
    (v_restaurant_id, v_board_id, 400070003014, 13),
    (v_restaurant_id, v_board_id, 400070003015, 14),
    (v_restaurant_id, v_board_id, 400070003016, 15),
    (v_restaurant_id, v_board_id, 400070003017, 16),
    (v_restaurant_id, v_board_id, 400070003018, 17),
    (v_restaurant_id, v_board_id, 400070003019, 18);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, display_sequence)
VALUES
    (400070003001, v_restaurant_id, v_board_id, 400070003001, 0),
    (400070003002, v_restaurant_id, v_board_id, 400070003002, 1),
    (400070003003, v_restaurant_id, v_board_id, 400070003003, 2),
    (400070003004, v_restaurant_id, v_board_id, 400070003004, 3),
    (400070003005, v_restaurant_id, v_board_id, 400070003005, 4),
    (400070003006, v_restaurant_id, v_board_id, 400070003006, 5),
    (400070003007, v_restaurant_id, v_board_id, 400070003007, 6),
    (400070003008, v_restaurant_id, v_board_id, 400070003008, 7),
    (400070003009, v_restaurant_id, v_board_id, 400070003009, 8),
    (400070003010, v_restaurant_id, v_board_id, 400070003010, 9),
    (400070003011, v_restaurant_id, v_board_id, 400070003011, 10),
    (400070003012, v_restaurant_id, v_board_id, 400070003012, 11),
    (400070003013, v_restaurant_id, v_board_id, 400070003013, 12),
    (400070003014, v_restaurant_id, v_board_id, 400070003014, 13),
    (400070003015, v_restaurant_id, v_board_id, 400070003015, 14),
    (400070003016, v_restaurant_id, v_board_id, 400070003016, 15),
    (400070003017, v_restaurant_id, v_board_id, 400070003017, 16),
    (400070003018, v_restaurant_id, v_board_id, 400070003018, 17),
    (400070003019, v_restaurant_id, v_board_id, 400070003019, 18),
    (400070003020, v_restaurant_id, v_board_id, 400070003020, 19),
    (400070003021, v_restaurant_id, v_board_id, 400070003021, 20),
    (400070003022, v_restaurant_id, v_board_id, 400070003022, 21),
    (400070003023, v_restaurant_id, v_board_id, 400070003023, 22),
    (400070003024, v_restaurant_id, v_board_id, 400070003024, 23),
    (400070003025, v_restaurant_id, v_board_id, 400070003025, 24),
    (400070003026, v_restaurant_id, v_board_id, 400070003026, 25),
    (400070003027, v_restaurant_id, v_board_id, 400070003027, 26),
    (400070003028, v_restaurant_id, v_board_id, 400070003028, 27),
    (400070003029, v_restaurant_id, v_board_id, 400070003029, 28),
    (400070003030, v_restaurant_id, v_board_id, 400070003030, 29),
    (400070003031, v_restaurant_id, v_board_id, 400070003031, 30),
    (400070003032, v_restaurant_id, v_board_id, 400070003032, 31),
    (400070003033, v_restaurant_id, v_board_id, 400070003033, 32),
    (400070003034, v_restaurant_id, v_board_id, 400070003034, 33),
    (400070003035, v_restaurant_id, v_board_id, 400070003035, 34),
    (400070003036, v_restaurant_id, v_board_id, 400070003036, 35),
    (400070003037, v_restaurant_id, v_board_id, 400070003037, 36),
    (400070003038, v_restaurant_id, v_board_id, 400070003038, 37),
    (400070003039, v_restaurant_id, v_board_id, 400070003039, 38),
    (400070003040, v_restaurant_id, v_board_id, 400070003040, 39),
    (400070003041, v_restaurant_id, v_board_id, 400070003041, 40),
    (400070003042, v_restaurant_id, v_board_id, 400070003042, 41),
    (400070003043, v_restaurant_id, v_board_id, 400070003043, 42),
    (400070003044, v_restaurant_id, v_board_id, 400070003044, 43),
    (400070003045, v_restaurant_id, v_board_id, 400070003045, 44),
    (400070003046, v_restaurant_id, v_board_id, 400070003046, 45),
    (400070003047, v_restaurant_id, v_board_id, 400070003047, 46),
    (400070003048, v_restaurant_id, v_board_id, 400070003048, 47),
    (400070003049, v_restaurant_id, v_board_id, 400070003049, 48),
    (400070003050, v_restaurant_id, v_board_id, 400070003050, 49),
    (400070003051, v_restaurant_id, v_board_id, 400070003051, 50),
    (400070003052, v_restaurant_id, v_board_id, 400070003052, 51),
    (400070003053, v_restaurant_id, v_board_id, 400070003053, 52),
    (400070003054, v_restaurant_id, v_board_id, 400070003054, 53),
    (400070003055, v_restaurant_id, v_board_id, 400070003055, 54),
    (400070003056, v_restaurant_id, v_board_id, 400070003056, 55),
    (400070003057, v_restaurant_id, v_board_id, 400070003057, 56),
    (400070003058, v_restaurant_id, v_board_id, 400070003058, 57),
    (400070003059, v_restaurant_id, v_board_id, 400070003059, 58),
    (400070003060, v_restaurant_id, v_board_id, 400070003060, 59),
    (400070003061, v_restaurant_id, v_board_id, 400070003061, 60),
    (400070003062, v_restaurant_id, v_board_id, 400070003062, 61),
    (400070003063, v_restaurant_id, v_board_id, 400070003063, 62),
    (400070003064, v_restaurant_id, v_board_id, 400070003064, 63),
    (400070003065, v_restaurant_id, v_board_id, 400070003065, 64),
    (400070003066, v_restaurant_id, v_board_id, 400070003066, 65),
    (400070003067, v_restaurant_id, v_board_id, 400070003067, 66),
    (400070003068, v_restaurant_id, v_board_id, 400070003068, 67),
    (400070003069, v_restaurant_id, v_board_id, 400070003069, 68),
    (400070003070, v_restaurant_id, v_board_id, 400070003070, 69),
    (400070003071, v_restaurant_id, v_board_id, 400070003071, 70),
    (400070003072, v_restaurant_id, v_board_id, 400070003072, 71),
    (400070003073, v_restaurant_id, v_board_id, 400070003073, 72),
    (400070003074, v_restaurant_id, v_board_id, 400070003074, 73),
    (400070003075, v_restaurant_id, v_board_id, 400070003075, 74),
    (400070003076, v_restaurant_id, v_board_id, 400070003076, 75),
    (400070003077, v_restaurant_id, v_board_id, 400070003077, 76),
    (400070003078, v_restaurant_id, v_board_id, 400070003078, 77),
    (400070003079, v_restaurant_id, v_board_id, 400070003079, 78),
    (400070003080, v_restaurant_id, v_board_id, 400070003080, 79),
    (400070003081, v_restaurant_id, v_board_id, 400070003081, 80),
    (400070003082, v_restaurant_id, v_board_id, 400070003082, 81),
    (400070003083, v_restaurant_id, v_board_id, 400070003083, 82),
    (400070003084, v_restaurant_id, v_board_id, 400070003084, 83),
    (400070003085, v_restaurant_id, v_board_id, 400070003085, 84),
    (400070003086, v_restaurant_id, v_board_id, 400070003086, 85),
    (400070003087, v_restaurant_id, v_board_id, 400070003087, 86),
    (400070003088, v_restaurant_id, v_board_id, 400070003088, 87),
    (400070003089, v_restaurant_id, v_board_id, 400070003089, 88),
    (400070003090, v_restaurant_id, v_board_id, 400070003090, 89),
    (400070003091, v_restaurant_id, v_board_id, 400070003091, 90),
    (400070003092, v_restaurant_id, v_board_id, 400070003092, 91),
    (400070003093, v_restaurant_id, v_board_id, 400070003093, 92),
    (400070003094, v_restaurant_id, v_board_id, 400070003094, 93),
    (400070003095, v_restaurant_id, v_board_id, 400070003095, 94),
    (400070003096, v_restaurant_id, v_board_id, 400070003096, 95),
    (400070003097, v_restaurant_id, v_board_id, 400070003097, 96),
    (400070003098, v_restaurant_id, v_board_id, 400070003098, 97),
    (400070003099, v_restaurant_id, v_board_id, 400070003099, 98),
    (400070003100, v_restaurant_id, v_board_id, 400070003100, 99),
    (400070003101, v_restaurant_id, v_board_id, 400070003101, 100),
    (400070003102, v_restaurant_id, v_board_id, 400070003102, 101),
    (400070003103, v_restaurant_id, v_board_id, 400070003103, 102),
    (400070003104, v_restaurant_id, v_board_id, 400070003104, 103),
    (400070003105, v_restaurant_id, v_board_id, 400070003105, 104),
    (400070003106, v_restaurant_id, v_board_id, 400070003106, 105),
    (400070003107, v_restaurant_id, v_board_id, 400070003107, 106),
    (400070003108, v_restaurant_id, v_board_id, 400070003108, 107),
    (400070003109, v_restaurant_id, v_board_id, 400070003109, 108),
    (400070003110, v_restaurant_id, v_board_id, 400070003110, 109),
    (400070003111, v_restaurant_id, v_board_id, 400070003111, 110),
    (400070003112, v_restaurant_id, v_board_id, 400070003112, 111),
    (400070003113, v_restaurant_id, v_board_id, 400070003113, 112),
    (400070003114, v_restaurant_id, v_board_id, 400070003114, 113),
    (400070003115, v_restaurant_id, v_board_id, 400070003115, 114),
    (400070003116, v_restaurant_id, v_board_id, 400070003116, 115),
    (400070003117, v_restaurant_id, v_board_id, 400070003117, 116),
    (400070003118, v_restaurant_id, v_board_id, 400070003118, 117),
    (400070003119, v_restaurant_id, v_board_id, 400070003119, 118),
    (400070003120, v_restaurant_id, v_board_id, 400070003120, 119),
    (400070003121, v_restaurant_id, v_board_id, 400070003121, 120),
    (400070003122, v_restaurant_id, v_board_id, 400070003122, 121),
    (400070003123, v_restaurant_id, v_board_id, 400070003123, 122),
    (400070003124, v_restaurant_id, v_board_id, 400070003124, 123),
    (400070003125, v_restaurant_id, v_board_id, 400070003125, 124),
    (400070003126, v_restaurant_id, v_board_id, 400070003126, 125),
    (400070003127, v_restaurant_id, v_board_id, 400070003127, 126),
    (400070003128, v_restaurant_id, v_board_id, 400070003128, 127),
    (400070003129, v_restaurant_id, v_board_id, 400070003129, 128),
    (400070003130, v_restaurant_id, v_board_id, 400070003130, 129),
    (400070003131, v_restaurant_id, v_board_id, 400070003131, 130),
    (400070003132, v_restaurant_id, v_board_id, 400070003132, 131),
    (400070003133, v_restaurant_id, v_board_id, 400070003133, 132),
    (400070003134, v_restaurant_id, v_board_id, 400070003134, 133),
    (400070003135, v_restaurant_id, v_board_id, 400070003135, 134),
    (400070003136, v_restaurant_id, v_board_id, 400070003136, 135),
    (400070003137, v_restaurant_id, v_board_id, 400070003137, 136),
    (400070003138, v_restaurant_id, v_board_id, 400070003138, 137),
    (400070003139, v_restaurant_id, v_board_id, 400070003139, 138),
    (400070003140, v_restaurant_id, v_board_id, 400070003140, 139),
    (400070003141, v_restaurant_id, v_board_id, 400070003141, 140),
    (400070003142, v_restaurant_id, v_board_id, 400070003142, 141),
    (400070003143, v_restaurant_id, v_board_id, 400070003143, 142),
    (400070003144, v_restaurant_id, v_board_id, 400070003144, 143),
    (400070003145, v_restaurant_id, v_board_id, 400070003145, 144),
    (400070003146, v_restaurant_id, v_board_id, 400070003146, 145),
    (400070003147, v_restaurant_id, v_board_id, 400070003147, 146),
    (400070003148, v_restaurant_id, v_board_id, 400070003148, 147),
    (400070003149, v_restaurant_id, v_board_id, 400070003149, 148),
    (400070003150, v_restaurant_id, v_board_id, 400070003150, 149),
    (400070003151, v_restaurant_id, v_board_id, 400070003151, 150),
    (400070003152, v_restaurant_id, v_board_id, 400070003152, 151),
    (400070003153, v_restaurant_id, v_board_id, 400070003153, 152),
    (400070003154, v_restaurant_id, v_board_id, 400070003154, 153),
    (400070003155, v_restaurant_id, v_board_id, 400070003155, 154),
    (400070003156, v_restaurant_id, v_board_id, 400070003156, 155),
    (400070003157, v_restaurant_id, v_board_id, 400070003157, 156),
    (400070003158, v_restaurant_id, v_board_id, 400070003158, 157),
    (400070003159, v_restaurant_id, v_board_id, 400070003159, 158),
    (400070003160, v_restaurant_id, v_board_id, 400070003160, 159),
    (400070003161, v_restaurant_id, v_board_id, 400070003161, 160),
    (400070003162, v_restaurant_id, v_board_id, 400070003162, 161),
    (400070003163, v_restaurant_id, v_board_id, 400070003163, 162),
    (400070003164, v_restaurant_id, v_board_id, 400070003164, 163),
    (400070003165, v_restaurant_id, v_board_id, 400070003165, 164),
    (400070003166, v_restaurant_id, v_board_id, 400070003166, 165),
    (400070003167, v_restaurant_id, v_board_id, 400070003167, 166),
    (400070003168, v_restaurant_id, v_board_id, 400070003168, 167),
    (400070003169, v_restaurant_id, v_board_id, 400070003169, 168),
    (400070003170, v_restaurant_id, v_board_id, 400070003170, 169),
    (400070003171, v_restaurant_id, v_board_id, 400070003171, 170),
    (400070003172, v_restaurant_id, v_board_id, 400070003172, 171),
    (400070003173, v_restaurant_id, v_board_id, 400070003173, 172),
    (400070003174, v_restaurant_id, v_board_id, 400070003174, 173),
    (400070003175, v_restaurant_id, v_board_id, 400070003175, 174),
    (400070003176, v_restaurant_id, v_board_id, 400070003176, 175),
    (400070003177, v_restaurant_id, v_board_id, 400070003177, 176),
    (400070003178, v_restaurant_id, v_board_id, 400070003178, 177),
    (400070003179, v_restaurant_id, v_board_id, 400070003179, 178),
    (400070003180, v_restaurant_id, v_board_id, 400070003180, 179),
    (400070003181, v_restaurant_id, v_board_id, 400070003181, 180),
    (400070003182, v_restaurant_id, v_board_id, 400070003182, 181),
    (400070003183, v_restaurant_id, v_board_id, 400070003183, 182),
    (400070003184, v_restaurant_id, v_board_id, 400070003184, 183),
    (400070003185, v_restaurant_id, v_board_id, 400070003185, 184),
    (400070003186, v_restaurant_id, v_board_id, 400070003186, 185),
    (400070003187, v_restaurant_id, v_board_id, 400070003187, 186),
    (400070003188, v_restaurant_id, v_board_id, 400070003188, 187),
    (400070003189, v_restaurant_id, v_board_id, 400070003189, 188),
    (400070003190, v_restaurant_id, v_board_id, 400070003190, 189),
    (400070003191, v_restaurant_id, v_board_id, 400070003191, 190),
    (400070003192, v_restaurant_id, v_board_id, 400070003192, 191),
    (400070003193, v_restaurant_id, v_board_id, 400070003193, 192),
    (400070003194, v_restaurant_id, v_board_id, 400070003194, 193),
    (400070003195, v_restaurant_id, v_board_id, 400070003195, 194),
    (400070003196, v_restaurant_id, v_board_id, 400070003196, 195),
    (400070003197, v_restaurant_id, v_board_id, 400070003197, 196),
    (400070003198, v_restaurant_id, v_board_id, 400070003198, 197),
    (400070003199, v_restaurant_id, v_board_id, 400070003199, 198),
    (400070003200, v_restaurant_id, v_board_id, 400070003200, 199),
    (400070003201, v_restaurant_id, v_board_id, 400070003201, 200);

END $$;

-- Align the sequences with the IDs explicitly inserted above.
SELECT setval('istanbul_darbar_menu_category_id_seq', 400070003019, true);
SELECT setval('istanbul_darbar_menu_item_id_seq', 400070003201, true);
SELECT setval('istanbul_darbar_variant_id_seq', 400070003201, true);
SELECT setval('istanbul_darbar_price_id_seq', 400070003201, true);
SELECT setval('istanbul_darbar_availability_id_seq', 400070003001, false);
SELECT setval('istanbul_darbar_menu_board_item_id_seq', 400070003201, true);

COMMIT;

-- ----------------------------------------------------------------------
-- Sanity check: run after commit to confirm row counts
-- ----------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM menu_category WHERE restaurant_id = 400070003) AS categories,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070003) AS items,
    (SELECT COUNT(*) FROM menu_item_variant miv JOIN menu_item mi ON mi.menu_item_id = miv.menu_item_id WHERE mi.restaurant_id = 400070003) AS variants,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070003 AND verification_status_code = 'needs_review') AS flagged_for_review;
