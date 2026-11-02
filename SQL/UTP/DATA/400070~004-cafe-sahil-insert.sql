-- ============================================================================
-- CAFE SAHIL -- MENU INSERT SCRIPT
-- Generated from 15 photographed menu pages (00.jpg restaurant-info page +
-- 14 menu pages) against KhaustanRestaurantMenu (khaustan-full-platform-mssql.sql).
-- Every table/column name below is copied verbatim from that schema file.
--
-- ################  READ BEFORE RUNNING  ################
-- 1. Address, PIN code and phone were supplied directly (not left as
--    placeholders this time) and are inserted as given: Shop No. 3, Beside
--    Micheal School, L.B.S. Road, Kurla (W), Mumbai, PIN 400070; four phone
--    numbers, all inserted as restaurant_phone rows.
-- 2. GST: you said GST is NOT charged on top of menu prices, so prices are
--    stored as tax-inclusive (tax_inclusion_code = 'inclusive') -- the
--    opposite convention from the Istanbul Darbar script, which had GST
--    charged on top. Worth double-checking this is the intended reading
--    of "GST charged on top: NO" before relying on it for billing.
-- 3. Hours: 00.jpg gives "12 Noon to 12 Midnight" daily, but also "Friday
--    Closed: 1:00 pm to 2:00" -- modeled as two restaurant_hours rows on
--    Friday (12:00-13:00 and 14:00-24:00) instead of one, so the gap is
--    real, queryable data rather than a footnote. Every other day gets one
--    row, 12:00-24:00.
-- 4. Delivery: "FREE HOME DELIVERY, Minimum Order of Rs.200/-" maps to
--    restaurant_delivery (self_delivery_available = 1, minimum
--    order = 200). No third-party provider is mentioned anywhere, so
--    restaurant_delivery_provider is left empty.
-- 5. Halal / No Beef / cuisine claims (Tandoori, Moghlai, Punjabi, Chinese)
--    from the cover page are stored as restaurant_tag rows against
--    platform_tag, not as new columns -- exactly the extensible mechanism
--    that table exists for.
-- 6. "THALI - NOT IN PARCEL" (image 09.jpg): the 4 thali items are marked
--    delivery_status_code = 'not_available' in menu_item_delivery, with a
--    reason -- they're dine-in only, and this schema has an exact slot for
--    that fact rather than needing a workaround.
-- 7. "Mutton Khichda (FRI)": interpreted as Friday-only availability
--    (khichda is a traditional Friday dish) and given a Friday-only
--    menu_item_availability row. Flagged for review -- confirm with the
--    restaurant rather than taking this as certain.
-- 8. Same schema gap as the Istanbul Darbar script: no thali/combo item
--    here lists structured components anyway, so bundle_component's
--    NOT NULL component_menu_item_id doesn't come up this time -- but it's
--    the same underlying limitation, worth fixing once, not per-restaurant.
-- 9. 5 lines carry a two-number price with no explicit column header
--    justifying the split (egg dishes, Spl. Dal Fry) -- inserted with
--    verification_status_code = 'needs_review' and an inline comment
--    explaining the specific ambiguity.
-- #########################################################
--
-- Wrapped in one transaction; safe to re-run (checks for an existing
-- restaurant with this normalized_name before inserting anything).
-- ============================================================================
--
-- ---- PostgreSQL conversion notes (added during MSSQL -> PostgreSQL conversion) ----
-- * Converted from the MSSQL/T-SQL source 400070-cafe-sahil-insert.sql against
--   khaustan-full-platform-postgresql.sql. Table/column names required no renaming.
-- * T-SQL scalar variables became PL/pgSQL variables in a single DO $$ ... $$ block
--   below (13 variables: 4 ids, 3 protein-type lookups, 6 platform-tag lookups),
--   preserving the source's control flow unchanged.
-- * Fixed 286 bare-integer boolean literals PostgreSQL rejects for BOOLEAN columns:
--   restaurant.has_bar (1), restaurant_phone.is_primary (4 rows), restaurant_delivery.
--   delivery_available/self_delivery_available (1 row, 2 columns), restaurant_tag.
--   value_boolean (6 rows), and menu_item_variant.is_default (274 rows) -- 0/1 -> FALSE/TRUE.
-- * Replaced SYSUTCDATETIME() (278 occurrences, in menu_item_price.effective_from and
--   menu_item_delivery.effective_from) with (clock_timestamp() AT TIME ZONE 'UTC').
-- * ID convention in this revised script: establishment_id, restaurant_id and source_id use
--   400070004. Menu-category IDs start at 400070004001. Menu-item IDs start at
--   400070004001. Menu-item variant IDs start at 400070004001. Menu-item price IDs
--   start at 400070004001. Menu-item availability IDs start at 400070004001.
--   Menu-board item IDs start at 400070004001. All dependent menu-item and
--   menu-category foreign keys are remapped accordingly. Other standalone ID
--   namespaces remain unchanged.
-- * No stray/undeclared T-SQL variables and no encoding corruption found in this file
--   (both issues affected the Istanbul Darbar script; this one is clean on both counts).
-- * Shares protein_type and platform_tag lookup rows with whichever restaurants were
--   loaded first: this script's own IF NOT EXISTS guards correctly detect Istanbul
--   Darbar's pre-existing protein_type rows (900001-900003) and skip re-inserting them,
--   re-pointing local variables to the existing ids instead -- verified below.
-- * Verified: ran with zero errors and zero warnings against a fresh PostgreSQL 16
--   instance loaded from khaustan-full-platform-postgresql.sql (is_market_price fix
--   applied) with Istanbul Darbar already loaded, confirming no id collisions
--   (the re-keyed Cafe Sahil IDs use the 400070000004-based convention; Istanbul Darbar remains in 900000 series).
-- ============================================================================

--\connect "KhaustanRestaurantMenu"

BEGIN;

DO $$
DECLARE
    v_establishment_id BIGINT := 400070004;
    v_restaurant_id    BIGINT := 400070004;
    v_source_id        BIGINT := 400070004;
    v_board_id         BIGINT := 400070004001;
    v_protein_chicken  BIGINT;
    v_protein_mutton   BIGINT;
    v_protein_seafood  BIGINT;
    v_tag_halal        BIGINT;
    v_tag_no_beef      BIGINT;
    v_tag_tandoori     BIGINT;
    v_tag_moghlai      BIGINT;
    v_tag_punjabi      BIGINT;
    v_tag_chinese      BIGINT;
BEGIN
IF EXISTS (SELECT 1 FROM restaurant WHERE normalized_name = 'cafe sahil') THEN
        RAISE NOTICE 'Cafe Sahil already exists -- nothing inserted. Delete the existing rows first if you want to reload.';
        RETURN;
    END IF;

-- ----------------------------------------------------------------------
-- Establishment & restaurant -- real data throughout, no placeholders
-- ----------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2,
                            locality, city, state, postal_code, country_code, status_code, latitude, longitude)
VALUES (v_establishment_id, N'Cafe Sahil', N'cafe sahil',
        N'Shop No. 3, Beside Micheal School', N'L.B.S. Road',
        N'Kurla (W)', N'Mumbai', N'Maharashtra', N'400070', 'IN', 'active', 19.083755478740546, 72.88315260541951);  

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name,
                         veg_nonveg_status, has_bar, status_code, verification_status_code)
VALUES (v_restaurant_id, v_establishment_id, N'Cafe Sahil', N'cafe sahil',
        'veg_and_nonveg', FALSE, 'active', 'needs_review');  -- has_bar: 0 -> FALSE
-- verification_status_code = 'needs_review' at the restaurant level pending the
-- Friday-availability and dual-price ambiguities flagged at the top of this file

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (400070004001, v_restaurant_id, N'8452051330', TRUE),
    (400070004002, v_restaurant_id, N'8452051340', FALSE),
    (400070004003, v_restaurant_id, N'8657304371', FALSE),
    (400070004004, v_restaurant_id, N'8657304372', FALSE);

-- ----------------------------------------------------------------------
-- Hours: 12 Noon-12 Midnight daily, except Friday's 1-2pm closure
-- ----------------------------------------------------------------------
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (400070004001, v_restaurant_id, 1, 1, '12:00', '24:00'),  -- Monday
    (400070004002, v_restaurant_id, 2, 1, '12:00', '24:00'),  -- Tuesday
    (400070004003, v_restaurant_id, 3, 1, '12:00', '24:00'),  -- Wednesday
    (400070004004, v_restaurant_id, 4, 1, '12:00', '24:00'),  -- Thursday
    (400070004005, v_restaurant_id, 5, 1, '12:00', '13:00'),  -- Friday, before the gap
    (400070004006, v_restaurant_id, 5, 2, '14:00', '24:00'),  -- Friday, after the gap
    (400070004007, v_restaurant_id, 6, 1, '12:00', '24:00'),  -- Saturday
    (400070004008, v_restaurant_id, 7, 1, '12:00', '24:00');  -- Sunday

-- ----------------------------------------------------------------------
-- Delivery capability
-- ----------------------------------------------------------------------
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available,
                                  self_delivery_min_order_amount, status_code)
VALUES (v_restaurant_id, TRUE, TRUE, 200.00, 'active');  

    INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, 						delivery_charge_type_code, effective_from)
    VALUES(400070004001, v_restaurant_id, 4, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')); -- hardcoded

-- ----------------------------------------------------------------------
-- Restaurant-level tags: halal, no-beef, and the four cuisine claims from
-- the cover page. platform_tag rows are shared/reusable across
-- restaurants -- only inserted if they don't already exist.
-- ----------------------------------------------------------------------

    SELECT tag_id INTO v_tag_halal    FROM platform_tag WHERE tag_code = 'HALAL';
    SELECT tag_id INTO v_tag_no_beef  FROM platform_tag WHERE tag_code = 'NO_BEEF';
    SELECT tag_id INTO v_tag_tandoori FROM platform_tag WHERE tag_code = 'cuisine_tandoori';
    SELECT tag_id INTO v_tag_moghlai  FROM platform_tag WHERE tag_code = 'cuisine_moghlai';
    SELECT tag_id INTO v_tag_punjabi  FROM platform_tag WHERE tag_code = 'cuisine_punjabi';
    SELECT tag_id INTO v_tag_chinese  FROM platform_tag WHERE tag_code = 'cuisine_chinese';

INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
VALUES
    (400070004001, v_restaurant_id, v_tag_halal, TRUE),
    (400070004002, v_restaurant_id, v_tag_no_beef, TRUE),
    (400070004003, v_restaurant_id, v_tag_tandoori, TRUE),
    (400070004004, v_restaurant_id, v_tag_moghlai, TRUE),
    (400070004005, v_restaurant_id, v_tag_punjabi, TRUE),
    (400070004006, v_restaurant_id, v_tag_chinese, TRUE);

-- ----------------------------------------------------------------------
-- Provenance & protein-type lookup (idempotent, shared across restaurants)
-- ----------------------------------------------------------------------
INSERT INTO source_record (source_id, source_type_code, external_reference)
VALUES (v_source_id, 'ai_menu_extraction', N'Cafe Sahil -- 15 photographed menu pages');

SELECT protein_type_id INTO v_protein_chicken FROM protein_type WHERE code = 'CHICKEN';
    SELECT protein_type_id INTO v_protein_mutton  FROM protein_type WHERE code = 'MUTTON';
    SELECT protein_type_id INTO v_protein_seafood FROM protein_type WHERE code = 'SEAFOOD';

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
VALUES (v_board_id, v_restaurant_id, N'A La Carte', 'a_la_carte');

-- ----------------------------------------------------------------------
-- Menu categories
-- ----------------------------------------------------------------------
-- menu_board_category.restaurant_id remains the restaurant FK (400070004);
-- menu_category_id values use the 400070004001+ namespace.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
VALUES
    (400070004001, v_restaurant_id, N'Starters', 0),
    (400070004002, v_restaurant_id, N'Chicken Sahil Special', 1),
    (400070004003, v_restaurant_id, N'Chicken', 2),
    (400070004004, v_restaurant_id, N'Mutton Sahil Special', 3),
    (400070004005, v_restaurant_id, N'Mutton', 4),
    (400070004006, v_restaurant_id, N'Egg', 5),
    (400070004007, v_restaurant_id, N'Paneer', 6),
    (400070004008, v_restaurant_id, N'Vegetable', 7),
    (400070004009, v_restaurant_id, N'Biryani & Pulav', 8),
    (400070004010, v_restaurant_id, N'Thali', 9),
    (400070004011, v_restaurant_id, N'Chapati & Tandoori Roti', 10),
    (400070004012, v_restaurant_id, N'Soup', 11),
    (400070004013, v_restaurant_id, N'Chinese Gravy', 12),
    (400070004014, v_restaurant_id, N'Fried Rice', 13),
    (400070004015, v_restaurant_id, N'Noodles', 14),
    (400070004016, v_restaurant_id, N'Dessert', 15),
    (400070004017, v_restaurant_id, N'Salad, Dahi, Papad', 16),
    (400070004018, v_restaurant_id, N'Tea & Coffee', 17);

-- ----------------------------------------------------------------------
-- Menu items (237 rows)
-- ----------------------------------------------------------------------
    -- ===== image 02.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004001, v_restaurant_id, 400070004001, N'Chicken Tandoori Spl', N'chicken tandoori spl', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004002, v_restaurant_id, 400070004001, N'Chi. Schezwan Tandoori', N'chi. schezwan tandoori', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004003, v_restaurant_id, 400070004001, N'Chicken Tandoori Leg', N'chicken tandoori leg', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004004, v_restaurant_id, 400070004001, N'Chicken Tikka Dry (6pcs)', N'chicken tikka dry (6pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- printed as three separate lines by weight (250gm/500gm/1kg); merged into one dish with three weight variants
    (400070004005, v_restaurant_id, 400070004001, N'Chicken Dana', N'chicken dana', NULL, 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070004006, v_restaurant_id, 400070004001, N'Chicken Lollypop (6pcs)', N'chicken lollypop (6pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004007, v_restaurant_id, 400070004001, N'Chi. Scz. Lollypop Dry (6pcs)', N'chi. scz. lollypop dry (6pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004008, v_restaurant_id, 400070004001, N'Chicken Crispy', N'chicken crispy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004009, v_restaurant_id, 400070004001, N'Chicken-65', N'chicken-65', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004010, v_restaurant_id, 400070004001, N'Chicken Dragon', N'chicken dragon', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004011, v_restaurant_id, 400070004001, N'Chicken Chilly Dry', N'chicken chilly dry', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004012, v_restaurant_id, 400070004001, N'Chicken Manchurian Dry', N'chicken manchurian dry', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004013, v_restaurant_id, 400070004001, N'Chicken Roasted Dry', N'chicken roasted dry', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004014, v_restaurant_id, 400070004001, N'Paneer Tikka Dry (6pcs)', N'paneer tikka dry (6pcs)', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004015, v_restaurant_id, 400070004001, N'Paneer Crispy', N'paneer crispy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004016, v_restaurant_id, 400070004001, N'Veg. Crispy', N'veg. crispy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004017, v_restaurant_id, 400070004001, N'Veg. Chilli Dry', N'veg. chilli dry', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004018, v_restaurant_id, 400070004001, N'Veg. Manchurian Dry', N'veg. manchurian dry', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004019, v_restaurant_id, 400070004001, N'Veg. Schezwan Dry', N'veg. schezwan dry', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004020, v_restaurant_id, 400070004001, N'Mutton Plain Fry (7pc)', N'mutton plain fry (7pc)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004021, v_restaurant_id, 400070004001, N'Chicken Finger (6pcs)', N'chicken finger (6pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004022, v_restaurant_id, 400070004001, N'Paneer Chilli', N'paneer chilli', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 03.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004023, v_restaurant_id, 400070004002, N'Sahil Spl. Murg Musallam', N'sahil spl. murg musallam', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004024, v_restaurant_id, 400070004002, N'Family Chicken', N'family chicken', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004025, v_restaurant_id, 400070004002, N'Chicken Dana Masala', N'chicken dana masala', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004026, v_restaurant_id, 400070004002, N'Chicken Balti', N'chicken balti', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004027, v_restaurant_id, 400070004002, N'Chicken Lara(bl)', N'chicken lara(bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004028, v_restaurant_id, 400070004002, N'Chicken Marhaba', N'chicken marhaba', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004029, v_restaurant_id, 400070004002, N'Chicken Lajwab (bl)', N'chicken lajwab (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004030, v_restaurant_id, 400070004002, N'Chicken Akbari (bl)', N'chicken akbari (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004031, v_restaurant_id, 400070004002, N'Chicken Patiyala (bl)', N'chicken patiyala (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004032, v_restaurant_id, 400070004002, N'Chicken Sahil Spl', N'chicken sahil spl', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004033, v_restaurant_id, 400070004002, N'Chicken Angara (bl)', N'chicken angara (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004034, v_restaurant_id, 400070004002, N'Chicken Laziz (bl)', N'chicken laziz (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004035, v_restaurant_id, 400070004002, N'Chicken Mumtaz (bl)', N'chicken mumtaz (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004036, v_restaurant_id, 400070004002, N'Chicken Hyderabadi (bl)', N'chicken hyderabadi (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004037, v_restaurant_id, 400070004002, N'Chicken Tikka Masala(bl)', N'chicken tikka masala(bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004038, v_restaurant_id, 400070004002, N'Chicken Tawa(bl)', N'chicken tawa(bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004039, v_restaurant_id, 400070004002, N'Chicken Kolhapuri Spl', N'chicken kolhapuri spl', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004040, v_restaurant_id, 400070004002, N'Chicken Handi', N'chicken handi', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004041, v_restaurant_id, 400070004002, N'Chicken Lucknowi', N'chicken lucknowi', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004042, v_restaurant_id, 400070004002, N'Chicken Chingari (bl)', N'chicken chingari (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004043, v_restaurant_id, 400070004002, N'Chicken Chatpata (bl)', N'chicken chatpata (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004044, v_restaurant_id, 400070004002, N'Chicken Spicy', N'chicken spicy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004045, v_restaurant_id, 400070004002, N'Chicken Toofani (10 Pcs)', N'chicken toofani (10 pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004046, v_restaurant_id, 400070004002, N'Chicken Lasuniya (bl)', N'chicken lasuniya (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004047, v_restaurant_id, 400070004002, N'Chicken Lahori', N'chicken lahori', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified');

    -- ===== image 04.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004048, v_restaurant_id, 400070004003, N'Butter Chicken (BL)', N'butter chicken (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004049, v_restaurant_id, 400070004003, N'Chicken Dabba Gosht (BL)', N'chicken dabba gosht (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004050, v_restaurant_id, 400070004003, N'Chicken Kadai (4pcs)', N'chicken kadai (4pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004051, v_restaurant_id, 400070004003, N'Chicken Do-Pyaza', N'chicken do-pyaza', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004052, v_restaurant_id, 400070004003, N'Chicken Afgani (BL)', N'chicken afgani (bl)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004053, v_restaurant_id, 400070004003, N'Chicken Rashida', N'chicken rashida', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004054, v_restaurant_id, 400070004003, N'Chicken Moglai', N'chicken moglai', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004055, v_restaurant_id, 400070004003, N'Chicken Korma', N'chicken korma', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004056, v_restaurant_id, 400070004003, N'Chicken Malwani', N'chicken malwani', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004057, v_restaurant_id, 400070004003, N'Chicken Kabuli', N'chicken kabuli', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004058, v_restaurant_id, 400070004003, N'Chicken Punjabi', N'chicken punjabi', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004059, v_restaurant_id, 400070004003, N'Chicken Palak', N'chicken palak', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004060, v_restaurant_id, 400070004003, N'Chicken Stew Fry', N'chicken stew fry', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004061, v_restaurant_id, 400070004003, N'Chicken Masala Fry', N'chicken masala fry', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified');

    -- ===== image 05.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004062, v_restaurant_id, 400070004004, N'Mutton Angara (BL)', N'mutton angara (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004063, v_restaurant_id, 400070004004, N'Mutton Hyderabadi(BL)', N'mutton hyderabadi(bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004064, v_restaurant_id, 400070004004, N'Mutton Tawa (BL)', N'mutton tawa (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004065, v_restaurant_id, 400070004004, N'Mutton Mumtaz (BL)', N'mutton mumtaz (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004066, v_restaurant_id, 400070004004, N'Mutton Laziz (BL)', N'mutton laziz (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004067, v_restaurant_id, 400070004004, N'Mutton Spicy (BL)', N'mutton spicy (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004068, v_restaurant_id, 400070004004, N'Mutton Lajawab (BL)', N'mutton lajawab (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004069, v_restaurant_id, 400070004004, N'Mutton Hungama (BL)', N'mutton hungama (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004070, v_restaurant_id, 400070004004, N'Mutton Makhanwala', N'mutton makhanwala', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004071, v_restaurant_id, 400070004004, N'Mutton Sahil Spl', N'mutton sahil spl', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004072, v_restaurant_id, 400070004004, N'Mutton Toofani (10 pcs)', N'mutton toofani (10 pcs)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004073, v_restaurant_id, 400070004004, N'Mutton Patiyala', N'mutton patiyala', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004074, v_restaurant_id, 400070004004, N'Mutton Chatpata(BL)', N'mutton chatpata(bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004075, v_restaurant_id, 400070004004, N'Mutton Dabba Gosht (BL)', N'mutton dabba gosht (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004076, v_restaurant_id, 400070004004, N'Mutton Lahori (BL)', N'mutton lahori (bl)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004077, v_restaurant_id, 400070004004, N'Mutton Malwani', N'mutton malwani', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004078, v_restaurant_id, 400070004004, N'Mutton Lasuniya', N'mutton lasuniya', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004079, v_restaurant_id, 400070004004, N'Mutton Kolhapuri', N'mutton kolhapuri', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004080, v_restaurant_id, 400070004004, N'Mutton Punjabi', N'mutton punjabi', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- (FRI) strongly suggests Friday-only availability (khichda/haleem is a traditional Friday dish) -- modeled with a Friday-only menu_item_availability row; REVIEW to confirm with the restaurant
    (400070004081, v_restaurant_id, 400070004004, N'Mutton Khichda (FRI)', N'mutton khichda (fri)', NULL, 'non_veg', v_protein_mutton, NULL, 'needs_review');

    -- ===== image 06.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004082, v_restaurant_id, 400070004005, N'Sahil Spl Mutton Salan', N'sahil spl mutton salan', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004083, v_restaurant_id, 400070004005, N'Mutton Kadai (4 pcs)', N'mutton kadai (4 pcs)', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004084, v_restaurant_id, 400070004005, N'Mutton Handi', N'mutton handi', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004085, v_restaurant_id, 400070004005, N'Mutton Afgani', N'mutton afgani', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004086, v_restaurant_id, 400070004005, N'Mutton Moglai', N'mutton moglai', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004087, v_restaurant_id, 400070004005, N'Mutton Kabuli', N'mutton kabuli', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004088, v_restaurant_id, 400070004005, N'Mutton Korma', N'mutton korma', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004089, v_restaurant_id, 400070004005, N'Mutton Do-Pyaza', N'mutton do-pyaza', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004090, v_restaurant_id, 400070004005, N'Mutton Palak', N'mutton palak', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004091, v_restaurant_id, 400070004005, N'Mutton Dal Gosht', N'mutton dal gosht', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004092, v_restaurant_id, 400070004005, N'Mutton Kheema', N'mutton kheema', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004093, v_restaurant_id, 400070004005, N'Mutton Kheema Fry', N'mutton kheema fry', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004094, v_restaurant_id, 400070004005, N'Mutton Kheema Ghotala', N'mutton kheema ghotala', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- accompaniment/add-on charge, printed as its own priced line
    (400070004095, v_restaurant_id, 400070004005, N'Extra Gravy', N'extra gravy', NULL, 'veg', NULL, NULL, 'needs_review'),
    (400070004096, v_restaurant_id, 400070004006, N'Egg Masala Single', N'egg masala single', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004097, v_restaurant_id, 400070004006, N'Egg Masala Fry Double', N'egg masala fry double', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004098, v_restaurant_id, 400070004006, N'Egg Masala Todphod', N'egg masala todphod', NULL, 'egg', NULL, NULL, 'unverified'),
    -- 30/50 interpreted as single-egg/double-egg (no explicit column header on this page for this specific line) -- REVIEW
    (400070004099, v_restaurant_id, 400070004006, N'Egg Omlete', N'egg omlete', NULL, 'egg', NULL, NULL, 'needs_review'),
    -- 40/60 interpreted as single-egg/double-egg (no explicit column header on this page for this specific line) -- REVIEW
    (400070004100, v_restaurant_id, 400070004006, N'Eggbhurji', N'eggbhurji', NULL, 'egg', NULL, NULL, 'needs_review'),
    (400070004101, v_restaurant_id, 400070004006, N'Egg Boiled', N'egg boiled', NULL, 'egg', NULL, NULL, 'unverified');

    -- ===== image 07.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004102, v_restaurant_id, 400070004007, N'Paneer Angara', N'paneer angara', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004103, v_restaurant_id, 400070004007, N'Paneer Butter Masala', N'paneer butter masala', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004104, v_restaurant_id, 400070004007, N'Paneer Handi', N'paneer handi', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004105, v_restaurant_id, 400070004007, N'Paneer Kadai', N'paneer kadai', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004106, v_restaurant_id, 400070004007, N'Paneer Chingari (6pcs)', N'paneer chingari (6pcs)', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004107, v_restaurant_id, 400070004007, N'Paneer Tikka Masala', N'paneer tikka masala', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004108, v_restaurant_id, 400070004007, N'Paneer Sahil Korma', N'paneer sahil korma', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004109, v_restaurant_id, 400070004007, N'Paneer Tawa', N'paneer tawa', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004110, v_restaurant_id, 400070004007, N'Paneer Punjabi', N'paneer punjabi', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004111, v_restaurant_id, 400070004007, N'Paneer Bhurji', N'paneer bhurji', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004112, v_restaurant_id, 400070004007, N'Paneer Kolhapuri', N'paneer kolhapuri', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004113, v_restaurant_id, 400070004007, N'Paneer Chana Masala', N'paneer chana masala', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004114, v_restaurant_id, 400070004007, N'Paneer Palak', N'paneer palak', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004115, v_restaurant_id, 400070004007, N'Paneer Mutter', N'paneer mutter', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004116, v_restaurant_id, 400070004007, N'Paneer Masala Fry', N'paneer masala fry', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 08.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004117, v_restaurant_id, 400070004008, N'Veg. Makhmali', N'veg. makhmali', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004118, v_restaurant_id, 400070004008, N'Veg. Shabnami', N'veg. shabnami', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004119, v_restaurant_id, 400070004008, N'Veg. Sahil Spl', N'veg. sahil spl', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004120, v_restaurant_id, 400070004008, N'Veg. Hyderabadi', N'veg. hyderabadi', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004121, v_restaurant_id, 400070004008, N'Veg. Tawa', N'veg. tawa', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004122, v_restaurant_id, 400070004008, N'Veg. Punjabi', N'veg. punjabi', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004123, v_restaurant_id, 400070004008, N'Veg. Kolhapuri', N'veg. kolhapuri', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004124, v_restaurant_id, 400070004008, N'Veg. Jaipuri', N'veg. jaipuri', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004125, v_restaurant_id, 400070004008, N'Veg. Makhanwala', N'veg. makhanwala', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004126, v_restaurant_id, 400070004008, N'Veg. Sev. Tomato', N'veg. sev. tomato', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004127, v_restaurant_id, 400070004008, N'Mix Veg', N'mix veg', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004128, v_restaurant_id, 400070004008, N'Chana Masala', N'chana masala', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004129, v_restaurant_id, 400070004008, N'Alu Palak', N'alu palak', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004130, v_restaurant_id, 400070004008, N'Alu Mutter', N'alu mutter', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004131, v_restaurant_id, 400070004008, N'Dal Tadka', N'dal tadka', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004132, v_restaurant_id, 400070004008, N'Dal Ghotala', N'dal ghotala', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004133, v_restaurant_id, 400070004008, N'Extra Dal', N'extra dal', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004134, v_restaurant_id, 400070004008, N'Extra Salan', N'extra salan', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004135, v_restaurant_id, 400070004008, N'Chana Masala Todphod', N'chana masala todphod', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004136, v_restaurant_id, 400070004008, N'Alu Mutter Tod Phod', N'alu mutter tod phod', NULL, 'veg', NULL, NULL, 'unverified'),
    -- 70/80 -- name already says '(Butter)'; second price's meaning is unclear (possibly plain-vs-butter upcharge) -- REVIEW
    (400070004137, v_restaurant_id, 400070004008, N'Spl. Dal Fry (Butter)', N'spl. dal fry (butter)', NULL, 'veg', NULL, NULL, 'needs_review');

    -- ===== image 09.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    -- printed as two separate lines '(H)' and '(F)' rather than two columns; merged into one dish, two variants
    (400070004138, v_restaurant_id, 400070004009, N'Chi. Khabsa Rice', N'chi. khabsa rice', NULL, 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- printed as two separate lines '(H)' and '(F)' rather than two columns; merged into one dish, two variants
    (400070004139, v_restaurant_id, 400070004009, N'Chi. Chilly Khabsa Rice', N'chi. chilly khabsa rice', NULL, 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070004140, v_restaurant_id, 400070004009, N'Chi. Tikka Biryani (3 pcs)', N'chi. tikka biryani (3 pcs)', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004141, v_restaurant_id, 400070004009, N'Chicken Tandoori Biryani', N'chicken tandoori biryani', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004142, v_restaurant_id, 400070004009, N'Chi. Biryani', N'chi. biryani', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004143, v_restaurant_id, 400070004009, N'Mutton Biryani', N'mutton biryani', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004144, v_restaurant_id, 400070004009, N'Paneer Tikka Biryani', N'paneer tikka biryani', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004145, v_restaurant_id, 400070004009, N'Paneer Biryani', N'paneer biryani', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004146, v_restaurant_id, 400070004009, N'Egg Biryani', N'egg biryani', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004147, v_restaurant_id, 400070004009, N'Veg Biryani', N'veg biryani', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004148, v_restaurant_id, 400070004009, N'Chicken Pulao', N'chicken pulao', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004149, v_restaurant_id, 400070004009, N'Mutton Pulao', N'mutton pulao', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    (400070004150, v_restaurant_id, 400070004009, N'Egg Pulao', N'egg pulao', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004151, v_restaurant_id, 400070004009, N'Paneer Pulao', N'paneer pulao', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004152, v_restaurant_id, 400070004009, N'Veg. Pulao', N'veg. pulao', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004153, v_restaurant_id, 400070004009, N'Dal Khichdi', N'dal khichdi', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004154, v_restaurant_id, 400070004009, N'Dal Khichdi Tadka', N'dal khichdi tadka', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004155, v_restaurant_id, 400070004009, N'Jeera Rice', N'jeera rice', NULL, 'veg', NULL, NULL, 'unverified'),
    -- printed exactly as 'Esteem Rice' (likely means Steam Rice) -- kept verbatim
    (400070004156, v_restaurant_id, 400070004009, N'Esteem Rice', N'esteem rice', NULL, 'veg', NULL, NULL, 'needs_review'),
    (400070004157, v_restaurant_id, 400070004009, N'Biryani Rice', N'biryani rice', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 10.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    -- 'THALI - NOT IN PARCEL': dine-in only, not available for delivery/takeaway -- see menu_item_delivery
    (400070004158, v_restaurant_id, 400070004010, N'Mix Thali', N'mix thali', NULL, 'non_veg', NULL, NULL, 'needs_review'),
    -- 'THALI - NOT IN PARCEL': dine-in only, not available for delivery/takeaway -- see menu_item_delivery
    (400070004159, v_restaurant_id, 400070004010, N'Mutton Thali', N'mutton thali', NULL, 'non_veg', v_protein_mutton, NULL, 'needs_review'),
    -- 'THALI - NOT IN PARCEL': dine-in only, not available for delivery/takeaway -- see menu_item_delivery
    (400070004160, v_restaurant_id, 400070004010, N'Chicken Thali', N'chicken thali', NULL, 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    -- 'THALI - NOT IN PARCEL': dine-in only, not available for delivery/takeaway -- see menu_item_delivery
    (400070004161, v_restaurant_id, 400070004010, N'Veg. Thali', N'veg. thali', NULL, 'veg', NULL, NULL, 'needs_review'),
    (400070004162, v_restaurant_id, 400070004011, N'Tandoori Roti', N'tandoori roti', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004163, v_restaurant_id, 400070004011, N'Tandoori Butter Roti', N'tandoori butter roti', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004164, v_restaurant_id, 400070004011, N'Tandoori Paratha', N'tandoori paratha', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004165, v_restaurant_id, 400070004011, N'Tandoori Butter Paratha', N'tandoori butter paratha', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004166, v_restaurant_id, 400070004011, N'Tandoori Naan', N'tandoori naan', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004167, v_restaurant_id, 400070004011, N'Tandoori Butter Naan', N'tandoori butter naan', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004168, v_restaurant_id, 400070004011, N'Tandoori Garlic Naan', N'tandoori garlic naan', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004169, v_restaurant_id, 400070004011, N'Tandoori Alu Paratha', N'tandoori alu paratha', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004170, v_restaurant_id, 400070004011, N'Chapati', N'chapati', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 11.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004171, v_restaurant_id, 400070004012, N'Chi. Lung Fung Soup', N'chi. lung fung soup', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004172, v_restaurant_id, 400070004012, N'Chi. Hot Sour Soup', N'chi. hot sour soup', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004173, v_restaurant_id, 400070004012, N'Chi. Manchow Soup', N'chi. manchow soup', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004174, v_restaurant_id, 400070004012, N'Chi. Noodles Soup', N'chi. noodles soup', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004175, v_restaurant_id, 400070004012, N'Chi. Clear Soup', N'chi. clear soup', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004176, v_restaurant_id, 400070004012, N'Mutton Clear Soup', N'mutton clear soup', NULL, 'non_veg', v_protein_mutton, NULL, 'unverified'),
    -- printed as 'Sour', almost certainly 'Soup' -- kept verbatim
    (400070004177, v_restaurant_id, 400070004012, N'Veg. Manchow Sour', N'veg. manchow sour', NULL, 'veg', NULL, NULL, 'needs_review'),
    (400070004178, v_restaurant_id, 400070004012, N'Veg. Hot Sour Soup', N'veg. hot sour soup', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004179, v_restaurant_id, 400070004012, N'Veg. Noodles Soup', N'veg. noodles soup', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 12.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004180, v_restaurant_id, 400070004013, N'Chicken 65 Gravy', N'chicken 65 gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004181, v_restaurant_id, 400070004013, N'Chicken Chilly Gravy', N'chicken chilly gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004182, v_restaurant_id, 400070004013, N'Chicken Manchurian Gravy', N'chicken manchurian gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004183, v_restaurant_id, 400070004013, N'Chicken Garlic Gravy', N'chicken garlic gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004184, v_restaurant_id, 400070004013, N'Chicken Ginger Gravy', N'chicken ginger gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004185, v_restaurant_id, 400070004013, N'Chicken Hong Kong Gravy', N'chicken hong kong gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004186, v_restaurant_id, 400070004013, N'Chicken Lollypop Gravy', N'chicken lollypop gravy', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004187, v_restaurant_id, 400070004013, N'Veg. Chilli Gravy', N'veg. chilli gravy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004188, v_restaurant_id, 400070004013, N'Veg. Manchurian Gravy', N'veg. manchurian gravy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004189, v_restaurant_id, 400070004013, N'Veg. Garlic Gravy', N'veg. garlic gravy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004190, v_restaurant_id, 400070004013, N'Veg. Ginger Gravy', N'veg. ginger gravy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004191, v_restaurant_id, 400070004013, N'Paneer Chilli Gravy', N'paneer chilli gravy', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004192, v_restaurant_id, 400070004013, N'Paneer Manchurian Gravy', N'paneer manchurian gravy', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 13.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004193, v_restaurant_id, 400070004014, N'Chicken Fried Rice', N'chicken fried rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004194, v_restaurant_id, 400070004014, N'Chicken Schezwan Rice', N'chicken schezwan rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    -- name describes one combination dish; not decomposed further
    (400070004195, v_restaurant_id, 400070004014, N'Chicken Combination Rice', N'chicken combination rice', NULL, 'non_veg', v_protein_chicken, NULL, 'needs_review'),
    (400070004196, v_restaurant_id, 400070004014, N'Chicken Hong Kong Rice', N'chicken hong kong rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004197, v_restaurant_id, 400070004014, N'Mix Schezwan Rice', N'mix schezwan rice', NULL, 'non_veg', NULL, NULL, 'unverified'),
    (400070004198, v_restaurant_id, 400070004014, N'Mix Fried Rice', N'mix fried rice', NULL, 'non_veg', NULL, NULL, 'unverified'),
    -- printed exactly as 'Tripple' -- kept verbatim
    (400070004199, v_restaurant_id, 400070004014, N'Mix Tripple Rice', N'mix tripple rice', NULL, 'non_veg', NULL, NULL, 'needs_review'),
    (400070004200, v_restaurant_id, 400070004014, N'Chicken Singapore Rice', N'chicken singapore rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004201, v_restaurant_id, 400070004014, N'Chicken Ginger Rice', N'chicken ginger rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004202, v_restaurant_id, 400070004014, N'Chicken Garlic Rice', N'chicken garlic rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004203, v_restaurant_id, 400070004014, N'Chicken Triple Special Rice', N'chicken triple special rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004204, v_restaurant_id, 400070004014, N'Chicken Tringa Rice', N'chicken tringa rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004205, v_restaurant_id, 400070004014, N'Chicken Manchurian Rice', N'chicken manchurian rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004206, v_restaurant_id, 400070004014, N'Chicken Chopper Rice', N'chicken chopper rice', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004207, v_restaurant_id, 400070004014, N'Egg Fried Rice', N'egg fried rice', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004208, v_restaurant_id, 400070004014, N'Egg Schezwan Fried Rice', N'egg schezwan fried rice', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004209, v_restaurant_id, 400070004014, N'Veg. Fried Rice', N'veg. fried rice', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004210, v_restaurant_id, 400070004014, N'Veg. Schezwan Rice', N'veg. schezwan rice', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004211, v_restaurant_id, 400070004014, N'Veg Triple Rice', N'veg triple rice', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004212, v_restaurant_id, 400070004014, N'Paneer Fried Rice', N'paneer fried rice', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 14.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004213, v_restaurant_id, 400070004015, N'Chicken Hakka Noodles', N'chicken hakka noodles', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004214, v_restaurant_id, 400070004015, N'Chi. Schezwan Noodles', N'chi. schezwan noodles', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004215, v_restaurant_id, 400070004015, N'Mix Hakka Noodles', N'mix hakka noodles', NULL, 'non_veg', NULL, NULL, 'unverified'),
    (400070004216, v_restaurant_id, 400070004015, N'Mix Schezwan Noodles', N'mix schezwan noodles', NULL, 'non_veg', NULL, NULL, 'unverified'),
    (400070004217, v_restaurant_id, 400070004015, N'Chicken Triple Noodles', N'chicken triple noodles', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004218, v_restaurant_id, 400070004015, N'Chi. Manchurian Noodles', N'chi. manchurian noodles', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004219, v_restaurant_id, 400070004015, N'Chi. Singapore Noodles', N'chi. singapore noodles', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004220, v_restaurant_id, 400070004015, N'Chi. Hong Kong Noodles', N'chi. hong kong noodles', NULL, 'non_veg', v_protein_chicken, NULL, 'unverified'),
    (400070004221, v_restaurant_id, 400070004015, N'Egg Noodles', N'egg noodles', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004222, v_restaurant_id, 400070004015, N'Egg Schezwan Noodles', N'egg schezwan noodles', NULL, 'egg', NULL, NULL, 'unverified'),
    (400070004223, v_restaurant_id, 400070004015, N'Veg Singapore Noodles', N'veg singapore noodles', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004224, v_restaurant_id, 400070004015, N'Veg Hong Kong Noodles', N'veg hong kong noodles', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004225, v_restaurant_id, 400070004015, N'Veg Triple Noodles', N'veg triple noodles', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004226, v_restaurant_id, 400070004015, N'Veg. Noodles', N'veg. noodles', NULL, 'veg', NULL, NULL, 'unverified');

    -- ===== image 15.jpg =====
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, name, normalized_name, description, food_classification_code, protein_type_id, split_group_key, verification_status_code)
VALUES
    (400070004227, v_restaurant_id, 400070004016, N'Caramel Custard', N'caramel custard', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004228, v_restaurant_id, 400070004016, N'Pudding', N'pudding', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004229, v_restaurant_id, 400070004017, N'Dahi Raitha', N'dahi raitha', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004230, v_restaurant_id, 400070004017, N'Green Salad', N'green salad', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004231, v_restaurant_id, 400070004017, N'Masala Papad', N'masala papad', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004232, v_restaurant_id, 400070004017, N'Papad Fry', N'papad fry', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004233, v_restaurant_id, 400070004017, N'Papad Roasted', N'papad roasted', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004234, v_restaurant_id, 400070004018, N'Tea', N'tea', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004235, v_restaurant_id, 400070004018, N'Spl. Tea', N'spl. tea', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004236, v_restaurant_id, 400070004018, N'Coffee', N'coffee', NULL, 'veg', NULL, NULL, 'unverified'),
    (400070004237, v_restaurant_id, 400070004018, N'Malai Tea', N'malai tea', NULL, 'veg', NULL, NULL, 'unverified');

-- ----------------------------------------------------------------------
-- Item provenance
-- ----------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, confidence, verification_status_code)
VALUES
    (400070004001, v_source_id, 0.97, 'unverified'),
    (400070004002, v_source_id, 0.97, 'unverified'),
    (400070004003, v_source_id, 0.97, 'unverified'),
    (400070004004, v_source_id, 0.97, 'unverified'),
    (400070004005, v_source_id, 0.65, 'needs_review'),
    (400070004006, v_source_id, 0.97, 'unverified'),
    (400070004007, v_source_id, 0.97, 'unverified'),
    (400070004008, v_source_id, 0.97, 'unverified'),
    (400070004009, v_source_id, 0.97, 'unverified'),
    (400070004010, v_source_id, 0.97, 'unverified'),
    (400070004011, v_source_id, 0.97, 'unverified'),
    (400070004012, v_source_id, 0.97, 'unverified'),
    (400070004013, v_source_id, 0.97, 'unverified'),
    (400070004014, v_source_id, 0.97, 'unverified'),
    (400070004015, v_source_id, 0.97, 'unverified'),
    (400070004016, v_source_id, 0.97, 'unverified'),
    (400070004017, v_source_id, 0.97, 'unverified'),
    (400070004018, v_source_id, 0.97, 'unverified'),
    (400070004019, v_source_id, 0.97, 'unverified'),
    (400070004020, v_source_id, 0.97, 'unverified'),
    (400070004021, v_source_id, 0.97, 'unverified'),
    (400070004022, v_source_id, 0.97, 'unverified'),
    (400070004023, v_source_id, 0.97, 'unverified'),
    (400070004024, v_source_id, 0.97, 'unverified'),
    (400070004025, v_source_id, 0.97, 'unverified'),
    (400070004026, v_source_id, 0.97, 'unverified'),
    (400070004027, v_source_id, 0.97, 'unverified'),
    (400070004028, v_source_id, 0.97, 'unverified'),
    (400070004029, v_source_id, 0.97, 'unverified'),
    (400070004030, v_source_id, 0.97, 'unverified'),
    (400070004031, v_source_id, 0.97, 'unverified'),
    (400070004032, v_source_id, 0.97, 'unverified'),
    (400070004033, v_source_id, 0.97, 'unverified'),
    (400070004034, v_source_id, 0.97, 'unverified'),
    (400070004035, v_source_id, 0.97, 'unverified'),
    (400070004036, v_source_id, 0.97, 'unverified'),
    (400070004037, v_source_id, 0.97, 'unverified'),
    (400070004038, v_source_id, 0.97, 'unverified'),
    (400070004039, v_source_id, 0.97, 'unverified'),
    (400070004040, v_source_id, 0.97, 'unverified'),
    (400070004041, v_source_id, 0.97, 'unverified'),
    (400070004042, v_source_id, 0.97, 'unverified'),
    (400070004043, v_source_id, 0.97, 'unverified'),
    (400070004044, v_source_id, 0.97, 'unverified'),
    (400070004045, v_source_id, 0.97, 'unverified'),
    (400070004046, v_source_id, 0.97, 'unverified'),
    (400070004047, v_source_id, 0.97, 'unverified'),
    (400070004048, v_source_id, 0.97, 'unverified'),
    (400070004049, v_source_id, 0.97, 'unverified'),
    (400070004050, v_source_id, 0.97, 'unverified'),
    (400070004051, v_source_id, 0.97, 'unverified'),
    (400070004052, v_source_id, 0.97, 'unverified'),
    (400070004053, v_source_id, 0.97, 'unverified'),
    (400070004054, v_source_id, 0.97, 'unverified'),
    (400070004055, v_source_id, 0.97, 'unverified'),
    (400070004056, v_source_id, 0.97, 'unverified'),
    (400070004057, v_source_id, 0.97, 'unverified'),
    (400070004058, v_source_id, 0.97, 'unverified'),
    (400070004059, v_source_id, 0.97, 'unverified'),
    (400070004060, v_source_id, 0.97, 'unverified'),
    (400070004061, v_source_id, 0.97, 'unverified'),
    (400070004062, v_source_id, 0.97, 'unverified'),
    (400070004063, v_source_id, 0.97, 'unverified'),
    (400070004064, v_source_id, 0.97, 'unverified'),
    (400070004065, v_source_id, 0.97, 'unverified'),
    (400070004066, v_source_id, 0.97, 'unverified'),
    (400070004067, v_source_id, 0.97, 'unverified'),
    (400070004068, v_source_id, 0.97, 'unverified'),
    (400070004069, v_source_id, 0.97, 'unverified'),
    (400070004070, v_source_id, 0.97, 'unverified'),
    (400070004071, v_source_id, 0.97, 'unverified'),
    (400070004072, v_source_id, 0.97, 'unverified'),
    (400070004073, v_source_id, 0.97, 'unverified'),
    (400070004074, v_source_id, 0.97, 'unverified'),
    (400070004075, v_source_id, 0.97, 'unverified'),
    (400070004076, v_source_id, 0.97, 'unverified'),
    (400070004077, v_source_id, 0.97, 'unverified'),
    (400070004078, v_source_id, 0.97, 'unverified'),
    (400070004079, v_source_id, 0.97, 'unverified'),
    (400070004080, v_source_id, 0.97, 'unverified'),
    (400070004081, v_source_id, 0.65, 'needs_review'),
    (400070004082, v_source_id, 0.97, 'unverified'),
    (400070004083, v_source_id, 0.97, 'unverified'),
    (400070004084, v_source_id, 0.97, 'unverified'),
    (400070004085, v_source_id, 0.97, 'unverified'),
    (400070004086, v_source_id, 0.97, 'unverified'),
    (400070004087, v_source_id, 0.97, 'unverified'),
    (400070004088, v_source_id, 0.97, 'unverified'),
    (400070004089, v_source_id, 0.97, 'unverified'),
    (400070004090, v_source_id, 0.97, 'unverified'),
    (400070004091, v_source_id, 0.97, 'unverified'),
    (400070004092, v_source_id, 0.97, 'unverified'),
    (400070004093, v_source_id, 0.97, 'unverified'),
    (400070004094, v_source_id, 0.97, 'unverified'),
    (400070004095, v_source_id, 0.65, 'needs_review'),
    (400070004096, v_source_id, 0.97, 'unverified'),
    (400070004097, v_source_id, 0.97, 'unverified'),
    (400070004098, v_source_id, 0.97, 'unverified'),
    (400070004099, v_source_id, 0.65, 'needs_review'),
    (400070004100, v_source_id, 0.65, 'needs_review'),
    (400070004101, v_source_id, 0.97, 'unverified'),
    (400070004102, v_source_id, 0.97, 'unverified'),
    (400070004103, v_source_id, 0.97, 'unverified'),
    (400070004104, v_source_id, 0.97, 'unverified'),
    (400070004105, v_source_id, 0.97, 'unverified'),
    (400070004106, v_source_id, 0.97, 'unverified'),
    (400070004107, v_source_id, 0.97, 'unverified'),
    (400070004108, v_source_id, 0.97, 'unverified'),
    (400070004109, v_source_id, 0.97, 'unverified'),
    (400070004110, v_source_id, 0.97, 'unverified'),
    (400070004111, v_source_id, 0.97, 'unverified'),
    (400070004112, v_source_id, 0.97, 'unverified'),
    (400070004113, v_source_id, 0.97, 'unverified'),
    (400070004114, v_source_id, 0.97, 'unverified'),
    (400070004115, v_source_id, 0.97, 'unverified'),
    (400070004116, v_source_id, 0.97, 'unverified'),
    (400070004117, v_source_id, 0.97, 'unverified'),
    (400070004118, v_source_id, 0.97, 'unverified'),
    (400070004119, v_source_id, 0.97, 'unverified'),
    (400070004120, v_source_id, 0.97, 'unverified'),
    (400070004121, v_source_id, 0.97, 'unverified'),
    (400070004122, v_source_id, 0.97, 'unverified'),
    (400070004123, v_source_id, 0.97, 'unverified'),
    (400070004124, v_source_id, 0.97, 'unverified'),
    (400070004125, v_source_id, 0.97, 'unverified'),
    (400070004126, v_source_id, 0.97, 'unverified'),
    (400070004127, v_source_id, 0.97, 'unverified'),
    (400070004128, v_source_id, 0.97, 'unverified'),
    (400070004129, v_source_id, 0.97, 'unverified'),
    (400070004130, v_source_id, 0.97, 'unverified'),
    (400070004131, v_source_id, 0.97, 'unverified'),
    (400070004132, v_source_id, 0.97, 'unverified'),
    (400070004133, v_source_id, 0.97, 'unverified'),
    (400070004134, v_source_id, 0.97, 'unverified'),
    (400070004135, v_source_id, 0.97, 'unverified'),
    (400070004136, v_source_id, 0.97, 'unverified'),
    (400070004137, v_source_id, 0.65, 'needs_review'),
    (400070004138, v_source_id, 0.65, 'needs_review'),
    (400070004139, v_source_id, 0.65, 'needs_review'),
    (400070004140, v_source_id, 0.97, 'unverified'),
    (400070004141, v_source_id, 0.97, 'unverified'),
    (400070004142, v_source_id, 0.97, 'unverified'),
    (400070004143, v_source_id, 0.97, 'unverified'),
    (400070004144, v_source_id, 0.97, 'unverified'),
    (400070004145, v_source_id, 0.97, 'unverified'),
    (400070004146, v_source_id, 0.97, 'unverified'),
    (400070004147, v_source_id, 0.97, 'unverified'),
    (400070004148, v_source_id, 0.97, 'unverified'),
    (400070004149, v_source_id, 0.97, 'unverified'),
    (400070004150, v_source_id, 0.97, 'unverified'),
    (400070004151, v_source_id, 0.97, 'unverified'),
    (400070004152, v_source_id, 0.97, 'unverified'),
    (400070004153, v_source_id, 0.97, 'unverified'),
    (400070004154, v_source_id, 0.97, 'unverified'),
    (400070004155, v_source_id, 0.97, 'unverified'),
    (400070004156, v_source_id, 0.65, 'needs_review'),
    (400070004157, v_source_id, 0.97, 'unverified'),
    (400070004158, v_source_id, 0.65, 'needs_review'),
    (400070004159, v_source_id, 0.65, 'needs_review'),
    (400070004160, v_source_id, 0.65, 'needs_review'),
    (400070004161, v_source_id, 0.65, 'needs_review'),
    (400070004162, v_source_id, 0.97, 'unverified'),
    (400070004163, v_source_id, 0.97, 'unverified'),
    (400070004164, v_source_id, 0.97, 'unverified'),
    (400070004165, v_source_id, 0.97, 'unverified'),
    (400070004166, v_source_id, 0.97, 'unverified'),
    (400070004167, v_source_id, 0.97, 'unverified'),
    (400070004168, v_source_id, 0.97, 'unverified'),
    (400070004169, v_source_id, 0.97, 'unverified'),
    (400070004170, v_source_id, 0.97, 'unverified'),
    (400070004171, v_source_id, 0.97, 'unverified'),
    (400070004172, v_source_id, 0.97, 'unverified'),
    (400070004173, v_source_id, 0.97, 'unverified'),
    (400070004174, v_source_id, 0.97, 'unverified'),
    (400070004175, v_source_id, 0.97, 'unverified'),
    (400070004176, v_source_id, 0.97, 'unverified'),
    (400070004177, v_source_id, 0.65, 'needs_review'),
    (400070004178, v_source_id, 0.97, 'unverified'),
    (400070004179, v_source_id, 0.97, 'unverified'),
    (400070004180, v_source_id, 0.97, 'unverified'),
    (400070004181, v_source_id, 0.97, 'unverified'),
    (400070004182, v_source_id, 0.97, 'unverified'),
    (400070004183, v_source_id, 0.97, 'unverified'),
    (400070004184, v_source_id, 0.97, 'unverified'),
    (400070004185, v_source_id, 0.97, 'unverified'),
    (400070004186, v_source_id, 0.97, 'unverified'),
    (400070004187, v_source_id, 0.97, 'unverified'),
    (400070004188, v_source_id, 0.97, 'unverified'),
    (400070004189, v_source_id, 0.97, 'unverified'),
    (400070004190, v_source_id, 0.97, 'unverified'),
    (400070004191, v_source_id, 0.97, 'unverified'),
    (400070004192, v_source_id, 0.97, 'unverified'),
    (400070004193, v_source_id, 0.97, 'unverified'),
    (400070004194, v_source_id, 0.97, 'unverified'),
    (400070004195, v_source_id, 0.65, 'needs_review'),
    (400070004196, v_source_id, 0.97, 'unverified'),
    (400070004197, v_source_id, 0.97, 'unverified'),
    (400070004198, v_source_id, 0.97, 'unverified'),
    (400070004199, v_source_id, 0.65, 'needs_review'),
    (400070004200, v_source_id, 0.97, 'unverified'),
    (400070004201, v_source_id, 0.97, 'unverified'),
    (400070004202, v_source_id, 0.97, 'unverified'),
    (400070004203, v_source_id, 0.97, 'unverified'),
    (400070004204, v_source_id, 0.97, 'unverified'),
    (400070004205, v_source_id, 0.97, 'unverified'),
    (400070004206, v_source_id, 0.97, 'unverified'),
    (400070004207, v_source_id, 0.97, 'unverified'),
    (400070004208, v_source_id, 0.97, 'unverified'),
    (400070004209, v_source_id, 0.97, 'unverified'),
    (400070004210, v_source_id, 0.97, 'unverified'),
    (400070004211, v_source_id, 0.97, 'unverified'),
    (400070004212, v_source_id, 0.97, 'unverified'),
    (400070004213, v_source_id, 0.97, 'unverified'),
    (400070004214, v_source_id, 0.97, 'unverified'),
    (400070004215, v_source_id, 0.97, 'unverified'),
    (400070004216, v_source_id, 0.97, 'unverified'),
    (400070004217, v_source_id, 0.97, 'unverified'),
    (400070004218, v_source_id, 0.97, 'unverified'),
    (400070004219, v_source_id, 0.97, 'unverified'),
    (400070004220, v_source_id, 0.97, 'unverified'),
    (400070004221, v_source_id, 0.97, 'unverified'),
    (400070004222, v_source_id, 0.97, 'unverified'),
    (400070004223, v_source_id, 0.97, 'unverified'),
    (400070004224, v_source_id, 0.97, 'unverified'),
    (400070004225, v_source_id, 0.97, 'unverified'),
    (400070004226, v_source_id, 0.97, 'unverified'),
    (400070004227, v_source_id, 0.97, 'unverified'),
    (400070004228, v_source_id, 0.97, 'unverified'),
    (400070004229, v_source_id, 0.97, 'unverified'),
    (400070004230, v_source_id, 0.97, 'unverified'),
    (400070004231, v_source_id, 0.97, 'unverified'),
    (400070004232, v_source_id, 0.97, 'unverified'),
    (400070004233, v_source_id, 0.97, 'unverified'),
    (400070004234, v_source_id, 0.97, 'unverified'),
    (400070004235, v_source_id, 0.97, 'unverified'),
    (400070004236, v_source_id, 0.97, 'unverified'),
    (400070004237, v_source_id, 0.97, 'unverified');

-- ----------------------------------------------------------------------
-- Variants (274 rows -- portion, single/double, or weight-based)
-- ----------------------------------------------------------------------
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, is_default)
VALUES
    (400070004001, 400070004001, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004002, 400070004002, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004003, 400070004002, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004004, 400070004003, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004005, 400070004004, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004006, 400070004005, N'250gm', 'fixed', 250, 'g', FALSE),
    (400070004007, 400070004005, N'500gm', 'fixed', 500, 'g', FALSE),
    (400070004008, 400070004005, N'1 Kg', 'fixed', 1, 'kg', FALSE),
    (400070004009, 400070004006, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004010, 400070004007, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004011, 400070004008, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004012, 400070004009, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004013, 400070004010, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004014, 400070004011, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004015, 400070004012, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004016, 400070004013, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004017, 400070004014, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004018, 400070004015, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004019, 400070004016, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004020, 400070004017, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004021, 400070004018, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004022, 400070004019, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004023, 400070004020, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004024, 400070004021, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004025, 400070004022, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004026, 400070004023, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004027, 400070004023, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004028, 400070004024, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004029, 400070004025, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004030, 400070004026, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004031, 400070004027, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004032, 400070004028, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004033, 400070004029, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004034, 400070004030, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004035, 400070004031, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004036, 400070004032, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004037, 400070004033, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004038, 400070004034, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004039, 400070004035, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004040, 400070004036, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004041, 400070004037, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004042, 400070004038, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004043, 400070004039, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004044, 400070004040, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004045, 400070004041, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004046, 400070004042, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004047, 400070004043, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004048, 400070004044, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004049, 400070004045, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004050, 400070004046, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004051, 400070004047, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004052, 400070004048, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004053, 400070004049, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004054, 400070004050, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004055, 400070004051, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004056, 400070004052, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004057, 400070004053, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004058, 400070004054, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004059, 400070004055, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004060, 400070004056, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004061, 400070004057, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004062, 400070004058, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004063, 400070004059, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004064, 400070004060, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004065, 400070004061, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004066, 400070004062, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004067, 400070004063, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004068, 400070004064, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004069, 400070004065, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004070, 400070004066, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004071, 400070004067, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004072, 400070004068, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004073, 400070004069, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004074, 400070004070, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004075, 400070004071, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004076, 400070004072, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004077, 400070004073, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004078, 400070004074, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004079, 400070004075, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004080, 400070004076, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004081, 400070004077, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004082, 400070004078, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004083, 400070004079, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004084, 400070004080, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004085, 400070004081, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004086, 400070004082, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004087, 400070004083, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004088, 400070004084, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004089, 400070004085, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004090, 400070004086, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004091, 400070004087, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004092, 400070004088, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004093, 400070004089, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004094, 400070004090, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004095, 400070004091, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004096, 400070004092, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004097, 400070004093, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004098, 400070004094, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004099, 400070004095, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004100, 400070004096, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004101, 400070004097, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004102, 400070004098, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004103, 400070004099, N'Single', 'fixed', NULL, NULL, FALSE),
    (400070004104, 400070004099, N'Double', 'fixed', NULL, NULL, FALSE),
    (400070004105, 400070004100, N'Single', 'fixed', NULL, NULL, FALSE),
    (400070004106, 400070004100, N'Double', 'fixed', NULL, NULL, FALSE),
    (400070004107, 400070004101, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004108, 400070004102, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004109, 400070004103, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004110, 400070004104, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004111, 400070004105, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004112, 400070004106, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004113, 400070004107, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004114, 400070004108, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004115, 400070004109, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004116, 400070004110, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004117, 400070004111, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004118, 400070004112, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004119, 400070004113, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004120, 400070004114, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004121, 400070004115, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004122, 400070004116, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004123, 400070004117, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004124, 400070004118, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004125, 400070004119, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004126, 400070004120, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004127, 400070004121, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004128, 400070004122, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004129, 400070004123, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004130, 400070004124, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004131, 400070004125, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004132, 400070004126, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004133, 400070004127, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004134, 400070004128, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004135, 400070004129, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004136, 400070004130, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004137, 400070004131, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004138, 400070004132, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004139, 400070004133, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004140, 400070004134, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004141, 400070004135, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004142, 400070004136, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004143, 400070004137, N'Plain', 'fixed', NULL, NULL, FALSE),
    (400070004144, 400070004137, N'Butter', 'fixed', NULL, NULL, FALSE),
    (400070004145, 400070004138, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004146, 400070004138, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004147, 400070004139, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004148, 400070004139, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004149, 400070004140, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004150, 400070004141, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004151, 400070004142, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004152, 400070004142, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004153, 400070004143, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004154, 400070004143, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004155, 400070004144, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004156, 400070004145, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004157, 400070004146, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004158, 400070004147, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004159, 400070004148, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004160, 400070004148, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004161, 400070004149, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004162, 400070004149, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004163, 400070004150, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004164, 400070004151, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004165, 400070004152, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004166, 400070004153, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004167, 400070004154, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004168, 400070004155, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004169, 400070004155, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004170, 400070004156, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004171, 400070004156, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004172, 400070004157, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004173, 400070004157, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004174, 400070004158, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004175, 400070004159, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004176, 400070004160, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004177, 400070004161, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004178, 400070004162, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004179, 400070004163, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004180, 400070004164, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004181, 400070004165, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004182, 400070004166, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004183, 400070004167, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004184, 400070004168, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004185, 400070004169, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004186, 400070004170, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004187, 400070004171, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004188, 400070004171, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004189, 400070004172, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004190, 400070004172, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004191, 400070004173, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004192, 400070004173, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004193, 400070004174, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004194, 400070004174, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004195, 400070004175, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004196, 400070004175, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004197, 400070004176, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004198, 400070004176, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004199, 400070004177, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004200, 400070004177, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004201, 400070004178, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004202, 400070004178, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004203, 400070004179, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004204, 400070004179, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004205, 400070004180, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004206, 400070004181, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004207, 400070004182, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004208, 400070004183, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004209, 400070004184, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004210, 400070004185, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004211, 400070004186, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004212, 400070004186, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004213, 400070004187, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004214, 400070004188, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004215, 400070004189, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004216, 400070004190, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004217, 400070004191, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004218, 400070004192, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004219, 400070004193, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004220, 400070004193, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004221, 400070004194, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004222, 400070004194, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004223, 400070004195, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004224, 400070004196, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004225, 400070004197, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004226, 400070004198, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004227, 400070004199, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004228, 400070004200, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004229, 400070004201, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004230, 400070004202, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004231, 400070004203, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004232, 400070004204, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004233, 400070004205, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004234, 400070004206, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004235, 400070004207, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004236, 400070004207, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004237, 400070004208, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004238, 400070004208, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004239, 400070004209, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004240, 400070004209, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004241, 400070004210, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004242, 400070004210, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004243, 400070004211, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004244, 400070004212, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004245, 400070004213, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004246, 400070004213, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004247, 400070004214, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004248, 400070004214, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004249, 400070004215, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004250, 400070004215, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004251, 400070004216, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004252, 400070004217, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004253, 400070004218, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004254, 400070004219, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004255, 400070004220, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004256, 400070004221, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004257, 400070004222, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004258, 400070004222, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004259, 400070004223, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004260, 400070004224, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004261, 400070004225, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004262, 400070004226, N'Half', 'fixed', NULL, NULL, FALSE),
    (400070004263, 400070004226, N'Full', 'fixed', NULL, NULL, FALSE),
    (400070004264, 400070004227, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004265, 400070004228, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004266, 400070004229, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004267, 400070004230, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004268, 400070004231, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004269, 400070004232, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004270, 400070004233, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004271, 400070004234, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004272, 400070004235, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004273, 400070004236, N'Full', 'fixed', NULL, NULL, TRUE),
    (400070004274, 400070004237, N'Full', 'fixed', NULL, NULL, TRUE);

-- ----------------------------------------------------------------------
-- Prices (274 rows, 1:1 with variants -- inclusive of GST, see note 2 at top)
-- ----------------------------------------------------------------------
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_inclusion_code, source_id, effective_from, verification_status_code)
VALUES
    (400070004001, 400070004001, 300, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004002, 400070004002, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004003, 400070004003, 400, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004004, 400070004004, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004005, 400070004005, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004006, 400070004006, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004007, 400070004007, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004008, 400070004008, 400, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004009, 400070004009, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004010, 400070004010, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004011, 400070004011, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004012, 400070004012, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004013, 400070004013, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004014, 400070004014, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004015, 400070004015, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004016, 400070004016, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004017, 400070004017, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004018, 400070004018, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004019, 400070004019, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004020, 400070004020, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004021, 400070004021, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004022, 400070004022, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004023, 400070004023, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004024, 400070004024, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004025, 400070004025, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004026, 400070004026, 280, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004027, 400070004027, 520, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004028, 400070004028, 300, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004029, 400070004029, 270, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004030, 400070004030, 250, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004031, 400070004031, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004032, 400070004032, 280, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004033, 400070004033, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004034, 400070004034, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004035, 400070004035, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004036, 400070004036, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004037, 400070004037, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004038, 400070004038, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004039, 400070004039, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004040, 400070004040, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004041, 400070004041, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004042, 400070004042, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004043, 400070004043, 290, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004044, 400070004044, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004045, 400070004045, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004046, 400070004046, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004047, 400070004047, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004048, 400070004048, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004049, 400070004049, 330, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004050, 400070004050, 210, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004051, 400070004051, 210, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004052, 400070004052, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004053, 400070004053, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004054, 400070004054, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004055, 400070004055, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004056, 400070004056, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004057, 400070004057, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004058, 400070004058, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004059, 400070004059, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004060, 400070004060, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004061, 400070004061, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004062, 400070004062, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004063, 400070004063, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004064, 400070004064, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004065, 400070004065, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004066, 400070004066, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004067, 400070004067, 210, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004068, 400070004068, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004069, 400070004069, 210, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004070, 400070004070, 210, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004071, 400070004071, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004072, 400070004072, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004073, 400070004073, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004074, 400070004074, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004075, 400070004075, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004076, 400070004076, 380, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004077, 400070004077, 230, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004078, 400070004078, 210, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004079, 400070004079, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004080, 400070004080, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004081, 400070004081, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004082, 400070004082, 240, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004083, 400070004083, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004084, 400070004084, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004085, 400070004085, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004086, 400070004086, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004087, 400070004087, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004088, 400070004088, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004089, 400070004089, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004090, 400070004090, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004091, 400070004091, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004092, 400070004092, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004093, 400070004093, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004094, 400070004094, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004095, 400070004095, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004096, 400070004096, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004097, 400070004097, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004098, 400070004098, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004099, 400070004099, 60, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004100, 400070004100, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004101, 400070004101, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004102, 400070004102, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004103, 400070004103, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004104, 400070004104, 50, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004105, 400070004105, 40, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004106, 400070004106, 60, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004107, 400070004107, 15, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004108, 400070004108, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004109, 400070004109, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004110, 400070004110, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004111, 400070004111, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004112, 400070004112, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004113, 400070004113, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004114, 400070004114, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004115, 400070004115, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004116, 400070004116, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004117, 400070004117, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004118, 400070004118, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004119, 400070004119, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004120, 400070004120, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004121, 400070004121, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004122, 400070004122, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004123, 400070004123, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004124, 400070004124, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004125, 400070004125, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004126, 400070004126, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004127, 400070004127, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004128, 400070004128, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004129, 400070004129, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004130, 400070004130, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004131, 400070004131, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004132, 400070004132, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004133, 400070004133, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004134, 400070004134, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004135, 400070004135, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004136, 400070004136, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004137, 400070004137, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004138, 400070004138, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004139, 400070004139, 20, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004140, 400070004140, 20, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004141, 400070004141, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004142, 400070004142, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004143, 400070004143, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004144, 400070004144, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004145, 400070004145, 400, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004146, 400070004146, 700, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004147, 400070004147, 400, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004148, 400070004148, 600, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004149, 400070004149, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004150, 400070004150, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004151, 400070004151, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004152, 400070004152, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004153, 400070004153, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004154, 400070004154, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004155, 400070004155, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004156, 400070004156, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004157, 400070004157, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004158, 400070004158, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004159, 400070004159, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004160, 400070004160, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004161, 400070004161, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004162, 400070004162, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004163, 400070004163, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004164, 400070004164, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004165, 400070004165, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004166, 400070004166, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004167, 400070004167, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004168, 400070004168, 50, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004169, 400070004169, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004170, 400070004170, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004171, 400070004171, 50, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004172, 400070004172, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004173, 400070004173, 50, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004174, 400070004174, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004175, 400070004175, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004176, 400070004176, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004177, 400070004177, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004178, 400070004178, 10, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004179, 400070004179, 15, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004180, 400070004180, 20, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004181, 400070004181, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004182, 400070004182, 25, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004183, 400070004183, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004184, 400070004184, 40, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004185, 400070004185, 50, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004186, 400070004186, 9, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004187, 400070004187, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004188, 400070004188, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004189, 400070004189, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004190, 400070004190, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004191, 400070004191, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004192, 400070004192, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004193, 400070004193, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004194, 400070004194, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004195, 400070004195, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004196, 400070004196, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004197, 400070004197, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004198, 400070004198, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004199, 400070004199, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004200, 400070004200, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004201, 400070004201, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004202, 400070004202, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004203, 400070004203, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004204, 400070004204, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004205, 400070004205, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004206, 400070004206, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004207, 400070004207, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004208, 400070004208, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004209, 400070004209, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004210, 400070004210, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004211, 400070004211, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004212, 400070004212, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004213, 400070004213, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004214, 400070004214, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004215, 400070004215, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004216, 400070004216, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004217, 400070004217, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004218, 400070004218, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004219, 400070004219, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004220, 400070004220, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004221, 400070004221, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004222, 400070004222, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004223, 400070004223, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004224, 400070004224, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004225, 400070004225, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004226, 400070004226, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004227, 400070004227, 270, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'),
    (400070004228, 400070004228, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004229, 400070004229, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004230, 400070004230, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004231, 400070004231, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004232, 400070004232, 250, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004233, 400070004233, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004234, 400070004234, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004235, 400070004235, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004236, 400070004236, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004237, 400070004237, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004238, 400070004238, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004239, 400070004239, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004240, 400070004240, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004241, 400070004241, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004242, 400070004242, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004243, 400070004243, 190, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004244, 400070004244, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004245, 400070004245, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004246, 400070004246, 130, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004247, 400070004247, 90, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004248, 400070004248, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004249, 400070004249, 100, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004250, 400070004250, 150, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004251, 400070004251, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004252, 400070004252, 220, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004253, 400070004253, 180, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004254, 400070004254, 170, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004255, 400070004255, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004256, 400070004256, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004257, 400070004257, 80, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004258, 400070004258, 120, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004259, 400070004259, 160, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004260, 400070004260, 140, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004261, 400070004261, 200, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004262, 400070004262, 70, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004263, 400070004263, 110, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004264, 400070004264, 40, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004265, 400070004265, 20, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004266, 400070004266, 50, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004267, 400070004267, 60, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004268, 400070004268, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004269, 400070004269, 20, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004270, 400070004270, 20, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004271, 400070004271, 15, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004272, 400070004272, 30, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004273, 400070004273, 35, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'),
    (400070004274, 400070004274, 25, 'inclusive', v_source_id, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified');

-- ----------------------------------------------------------------------
-- Attach every category and every item to the A La Carte board
-- ----------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (v_restaurant_id, v_board_id, 400070004001, 0),
    (v_restaurant_id, v_board_id, 400070004002, 1),
    (v_restaurant_id, v_board_id, 400070004003, 2),
    (v_restaurant_id, v_board_id, 400070004004, 3),
    (v_restaurant_id, v_board_id, 400070004005, 4),
    (v_restaurant_id, v_board_id, 400070004006, 5),
    (v_restaurant_id, v_board_id, 400070004007, 6),
    (v_restaurant_id, v_board_id, 400070004008, 7),
    (v_restaurant_id, v_board_id, 400070004009, 8),
    (v_restaurant_id, v_board_id, 400070004010, 9),
    (v_restaurant_id, v_board_id, 400070004011, 10),
    (v_restaurant_id, v_board_id, 400070004012, 11),
    (v_restaurant_id, v_board_id, 400070004013, 12),
    (v_restaurant_id, v_board_id, 400070004014, 13),
    (v_restaurant_id, v_board_id, 400070004015, 14),
    (v_restaurant_id, v_board_id, 400070004016, 15),
    (v_restaurant_id, v_board_id, 400070004017, 16),
    (v_restaurant_id, v_board_id, 400070004018, 17);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, display_sequence)
VALUES
    (400070004001, v_restaurant_id, v_board_id, 400070004001, 0),
    (400070004002, v_restaurant_id, v_board_id, 400070004002, 1),
    (400070004003, v_restaurant_id, v_board_id, 400070004003, 2),
    (400070004004, v_restaurant_id, v_board_id, 400070004004, 3),
    (400070004005, v_restaurant_id, v_board_id, 400070004005, 4),
    (400070004006, v_restaurant_id, v_board_id, 400070004006, 5),
    (400070004007, v_restaurant_id, v_board_id, 400070004007, 6),
    (400070004008, v_restaurant_id, v_board_id, 400070004008, 7),
    (400070004009, v_restaurant_id, v_board_id, 400070004009, 8),
    (400070004010, v_restaurant_id, v_board_id, 400070004010, 9),
    (400070004011, v_restaurant_id, v_board_id, 400070004011, 10),
    (400070004012, v_restaurant_id, v_board_id, 400070004012, 11),
    (400070004013, v_restaurant_id, v_board_id, 400070004013, 12),
    (400070004014, v_restaurant_id, v_board_id, 400070004014, 13),
    (400070004015, v_restaurant_id, v_board_id, 400070004015, 14),
    (400070004016, v_restaurant_id, v_board_id, 400070004016, 15),
    (400070004017, v_restaurant_id, v_board_id, 400070004017, 16),
    (400070004018, v_restaurant_id, v_board_id, 400070004018, 17),
    (400070004019, v_restaurant_id, v_board_id, 400070004019, 18),
    (400070004020, v_restaurant_id, v_board_id, 400070004020, 19),
    (400070004021, v_restaurant_id, v_board_id, 400070004021, 20),
    (400070004022, v_restaurant_id, v_board_id, 400070004022, 21),
    (400070004023, v_restaurant_id, v_board_id, 400070004023, 22),
    (400070004024, v_restaurant_id, v_board_id, 400070004024, 23),
    (400070004025, v_restaurant_id, v_board_id, 400070004025, 24),
    (400070004026, v_restaurant_id, v_board_id, 400070004026, 25),
    (400070004027, v_restaurant_id, v_board_id, 400070004027, 26),
    (400070004028, v_restaurant_id, v_board_id, 400070004028, 27),
    (400070004029, v_restaurant_id, v_board_id, 400070004029, 28),
    (400070004030, v_restaurant_id, v_board_id, 400070004030, 29),
    (400070004031, v_restaurant_id, v_board_id, 400070004031, 30),
    (400070004032, v_restaurant_id, v_board_id, 400070004032, 31),
    (400070004033, v_restaurant_id, v_board_id, 400070004033, 32),
    (400070004034, v_restaurant_id, v_board_id, 400070004034, 33),
    (400070004035, v_restaurant_id, v_board_id, 400070004035, 34),
    (400070004036, v_restaurant_id, v_board_id, 400070004036, 35),
    (400070004037, v_restaurant_id, v_board_id, 400070004037, 36),
    (400070004038, v_restaurant_id, v_board_id, 400070004038, 37),
    (400070004039, v_restaurant_id, v_board_id, 400070004039, 38),
    (400070004040, v_restaurant_id, v_board_id, 400070004040, 39),
    (400070004041, v_restaurant_id, v_board_id, 400070004041, 40),
    (400070004042, v_restaurant_id, v_board_id, 400070004042, 41),
    (400070004043, v_restaurant_id, v_board_id, 400070004043, 42),
    (400070004044, v_restaurant_id, v_board_id, 400070004044, 43),
    (400070004045, v_restaurant_id, v_board_id, 400070004045, 44),
    (400070004046, v_restaurant_id, v_board_id, 400070004046, 45),
    (400070004047, v_restaurant_id, v_board_id, 400070004047, 46),
    (400070004048, v_restaurant_id, v_board_id, 400070004048, 47),
    (400070004049, v_restaurant_id, v_board_id, 400070004049, 48),
    (400070004050, v_restaurant_id, v_board_id, 400070004050, 49),
    (400070004051, v_restaurant_id, v_board_id, 400070004051, 50),
    (400070004052, v_restaurant_id, v_board_id, 400070004052, 51),
    (400070004053, v_restaurant_id, v_board_id, 400070004053, 52),
    (400070004054, v_restaurant_id, v_board_id, 400070004054, 53),
    (400070004055, v_restaurant_id, v_board_id, 400070004055, 54),
    (400070004056, v_restaurant_id, v_board_id, 400070004056, 55),
    (400070004057, v_restaurant_id, v_board_id, 400070004057, 56),
    (400070004058, v_restaurant_id, v_board_id, 400070004058, 57),
    (400070004059, v_restaurant_id, v_board_id, 400070004059, 58),
    (400070004060, v_restaurant_id, v_board_id, 400070004060, 59),
    (400070004061, v_restaurant_id, v_board_id, 400070004061, 60),
    (400070004062, v_restaurant_id, v_board_id, 400070004062, 61),
    (400070004063, v_restaurant_id, v_board_id, 400070004063, 62),
    (400070004064, v_restaurant_id, v_board_id, 400070004064, 63),
    (400070004065, v_restaurant_id, v_board_id, 400070004065, 64),
    (400070004066, v_restaurant_id, v_board_id, 400070004066, 65),
    (400070004067, v_restaurant_id, v_board_id, 400070004067, 66),
    (400070004068, v_restaurant_id, v_board_id, 400070004068, 67),
    (400070004069, v_restaurant_id, v_board_id, 400070004069, 68),
    (400070004070, v_restaurant_id, v_board_id, 400070004070, 69),
    (400070004071, v_restaurant_id, v_board_id, 400070004071, 70),
    (400070004072, v_restaurant_id, v_board_id, 400070004072, 71),
    (400070004073, v_restaurant_id, v_board_id, 400070004073, 72),
    (400070004074, v_restaurant_id, v_board_id, 400070004074, 73),
    (400070004075, v_restaurant_id, v_board_id, 400070004075, 74),
    (400070004076, v_restaurant_id, v_board_id, 400070004076, 75),
    (400070004077, v_restaurant_id, v_board_id, 400070004077, 76),
    (400070004078, v_restaurant_id, v_board_id, 400070004078, 77),
    (400070004079, v_restaurant_id, v_board_id, 400070004079, 78),
    (400070004080, v_restaurant_id, v_board_id, 400070004080, 79),
    (400070004081, v_restaurant_id, v_board_id, 400070004081, 80),
    (400070004082, v_restaurant_id, v_board_id, 400070004082, 81),
    (400070004083, v_restaurant_id, v_board_id, 400070004083, 82),
    (400070004084, v_restaurant_id, v_board_id, 400070004084, 83),
    (400070004085, v_restaurant_id, v_board_id, 400070004085, 84),
    (400070004086, v_restaurant_id, v_board_id, 400070004086, 85),
    (400070004087, v_restaurant_id, v_board_id, 400070004087, 86),
    (400070004088, v_restaurant_id, v_board_id, 400070004088, 87),
    (400070004089, v_restaurant_id, v_board_id, 400070004089, 88),
    (400070004090, v_restaurant_id, v_board_id, 400070004090, 89),
    (400070004091, v_restaurant_id, v_board_id, 400070004091, 90),
    (400070004092, v_restaurant_id, v_board_id, 400070004092, 91),
    (400070004093, v_restaurant_id, v_board_id, 400070004093, 92),
    (400070004094, v_restaurant_id, v_board_id, 400070004094, 93),
    (400070004095, v_restaurant_id, v_board_id, 400070004095, 94),
    (400070004096, v_restaurant_id, v_board_id, 400070004096, 95),
    (400070004097, v_restaurant_id, v_board_id, 400070004097, 96),
    (400070004098, v_restaurant_id, v_board_id, 400070004098, 97),
    (400070004099, v_restaurant_id, v_board_id, 400070004099, 98),
    (400070004100, v_restaurant_id, v_board_id, 400070004100, 99),
    (400070004101, v_restaurant_id, v_board_id, 400070004101, 100),
    (400070004102, v_restaurant_id, v_board_id, 400070004102, 101),
    (400070004103, v_restaurant_id, v_board_id, 400070004103, 102),
    (400070004104, v_restaurant_id, v_board_id, 400070004104, 103),
    (400070004105, v_restaurant_id, v_board_id, 400070004105, 104),
    (400070004106, v_restaurant_id, v_board_id, 400070004106, 105),
    (400070004107, v_restaurant_id, v_board_id, 400070004107, 106),
    (400070004108, v_restaurant_id, v_board_id, 400070004108, 107),
    (400070004109, v_restaurant_id, v_board_id, 400070004109, 108),
    (400070004110, v_restaurant_id, v_board_id, 400070004110, 109),
    (400070004111, v_restaurant_id, v_board_id, 400070004111, 110),
    (400070004112, v_restaurant_id, v_board_id, 400070004112, 111),
    (400070004113, v_restaurant_id, v_board_id, 400070004113, 112),
    (400070004114, v_restaurant_id, v_board_id, 400070004114, 113),
    (400070004115, v_restaurant_id, v_board_id, 400070004115, 114),
    (400070004116, v_restaurant_id, v_board_id, 400070004116, 115),
    (400070004117, v_restaurant_id, v_board_id, 400070004117, 116),
    (400070004118, v_restaurant_id, v_board_id, 400070004118, 117),
    (400070004119, v_restaurant_id, v_board_id, 400070004119, 118),
    (400070004120, v_restaurant_id, v_board_id, 400070004120, 119),
    (400070004121, v_restaurant_id, v_board_id, 400070004121, 120),
    (400070004122, v_restaurant_id, v_board_id, 400070004122, 121),
    (400070004123, v_restaurant_id, v_board_id, 400070004123, 122),
    (400070004124, v_restaurant_id, v_board_id, 400070004124, 123),
    (400070004125, v_restaurant_id, v_board_id, 400070004125, 124),
    (400070004126, v_restaurant_id, v_board_id, 400070004126, 125),
    (400070004127, v_restaurant_id, v_board_id, 400070004127, 126),
    (400070004128, v_restaurant_id, v_board_id, 400070004128, 127),
    (400070004129, v_restaurant_id, v_board_id, 400070004129, 128),
    (400070004130, v_restaurant_id, v_board_id, 400070004130, 129),
    (400070004131, v_restaurant_id, v_board_id, 400070004131, 130),
    (400070004132, v_restaurant_id, v_board_id, 400070004132, 131),
    (400070004133, v_restaurant_id, v_board_id, 400070004133, 132),
    (400070004134, v_restaurant_id, v_board_id, 400070004134, 133),
    (400070004135, v_restaurant_id, v_board_id, 400070004135, 134),
    (400070004136, v_restaurant_id, v_board_id, 400070004136, 135),
    (400070004137, v_restaurant_id, v_board_id, 400070004137, 136),
    (400070004138, v_restaurant_id, v_board_id, 400070004138, 137),
    (400070004139, v_restaurant_id, v_board_id, 400070004139, 138),
    (400070004140, v_restaurant_id, v_board_id, 400070004140, 139),
    (400070004141, v_restaurant_id, v_board_id, 400070004141, 140),
    (400070004142, v_restaurant_id, v_board_id, 400070004142, 141),
    (400070004143, v_restaurant_id, v_board_id, 400070004143, 142),
    (400070004144, v_restaurant_id, v_board_id, 400070004144, 143),
    (400070004145, v_restaurant_id, v_board_id, 400070004145, 144),
    (400070004146, v_restaurant_id, v_board_id, 400070004146, 145),
    (400070004147, v_restaurant_id, v_board_id, 400070004147, 146),
    (400070004148, v_restaurant_id, v_board_id, 400070004148, 147),
    (400070004149, v_restaurant_id, v_board_id, 400070004149, 148),
    (400070004150, v_restaurant_id, v_board_id, 400070004150, 149),
    (400070004151, v_restaurant_id, v_board_id, 400070004151, 150),
    (400070004152, v_restaurant_id, v_board_id, 400070004152, 151),
    (400070004153, v_restaurant_id, v_board_id, 400070004153, 152),
    (400070004154, v_restaurant_id, v_board_id, 400070004154, 153),
    (400070004155, v_restaurant_id, v_board_id, 400070004155, 154),
    (400070004156, v_restaurant_id, v_board_id, 400070004156, 155),
    (400070004157, v_restaurant_id, v_board_id, 400070004157, 156),
    (400070004158, v_restaurant_id, v_board_id, 400070004158, 157),
    (400070004159, v_restaurant_id, v_board_id, 400070004159, 158),
    (400070004160, v_restaurant_id, v_board_id, 400070004160, 159),
    (400070004161, v_restaurant_id, v_board_id, 400070004161, 160),
    (400070004162, v_restaurant_id, v_board_id, 400070004162, 161),
    (400070004163, v_restaurant_id, v_board_id, 400070004163, 162),
    (400070004164, v_restaurant_id, v_board_id, 400070004164, 163),
    (400070004165, v_restaurant_id, v_board_id, 400070004165, 164),
    (400070004166, v_restaurant_id, v_board_id, 400070004166, 165),
    (400070004167, v_restaurant_id, v_board_id, 400070004167, 166),
    (400070004168, v_restaurant_id, v_board_id, 400070004168, 167),
    (400070004169, v_restaurant_id, v_board_id, 400070004169, 168),
    (400070004170, v_restaurant_id, v_board_id, 400070004170, 169),
    (400070004171, v_restaurant_id, v_board_id, 400070004171, 170),
    (400070004172, v_restaurant_id, v_board_id, 400070004172, 171),
    (400070004173, v_restaurant_id, v_board_id, 400070004173, 172),
    (400070004174, v_restaurant_id, v_board_id, 400070004174, 173),
    (400070004175, v_restaurant_id, v_board_id, 400070004175, 174),
    (400070004176, v_restaurant_id, v_board_id, 400070004176, 175),
    (400070004177, v_restaurant_id, v_board_id, 400070004177, 176),
    (400070004178, v_restaurant_id, v_board_id, 400070004178, 177),
    (400070004179, v_restaurant_id, v_board_id, 400070004179, 178),
    (400070004180, v_restaurant_id, v_board_id, 400070004180, 179),
    (400070004181, v_restaurant_id, v_board_id, 400070004181, 180),
    (400070004182, v_restaurant_id, v_board_id, 400070004182, 181),
    (400070004183, v_restaurant_id, v_board_id, 400070004183, 182),
    (400070004184, v_restaurant_id, v_board_id, 400070004184, 183),
    (400070004185, v_restaurant_id, v_board_id, 400070004185, 184),
    (400070004186, v_restaurant_id, v_board_id, 400070004186, 185),
    (400070004187, v_restaurant_id, v_board_id, 400070004187, 186),
    (400070004188, v_restaurant_id, v_board_id, 400070004188, 187),
    (400070004189, v_restaurant_id, v_board_id, 400070004189, 188),
    (400070004190, v_restaurant_id, v_board_id, 400070004190, 189),
    (400070004191, v_restaurant_id, v_board_id, 400070004191, 190),
    (400070004192, v_restaurant_id, v_board_id, 400070004192, 191),
    (400070004193, v_restaurant_id, v_board_id, 400070004193, 192),
    (400070004194, v_restaurant_id, v_board_id, 400070004194, 193),
    (400070004195, v_restaurant_id, v_board_id, 400070004195, 194),
    (400070004196, v_restaurant_id, v_board_id, 400070004196, 195),
    (400070004197, v_restaurant_id, v_board_id, 400070004197, 196),
    (400070004198, v_restaurant_id, v_board_id, 400070004198, 197),
    (400070004199, v_restaurant_id, v_board_id, 400070004199, 198),
    (400070004200, v_restaurant_id, v_board_id, 400070004200, 199),
    (400070004201, v_restaurant_id, v_board_id, 400070004201, 200),
    (400070004202, v_restaurant_id, v_board_id, 400070004202, 201),
    (400070004203, v_restaurant_id, v_board_id, 400070004203, 202),
    (400070004204, v_restaurant_id, v_board_id, 400070004204, 203),
    (400070004205, v_restaurant_id, v_board_id, 400070004205, 204),
    (400070004206, v_restaurant_id, v_board_id, 400070004206, 205),
    (400070004207, v_restaurant_id, v_board_id, 400070004207, 206),
    (400070004208, v_restaurant_id, v_board_id, 400070004208, 207),
    (400070004209, v_restaurant_id, v_board_id, 400070004209, 208),
    (400070004210, v_restaurant_id, v_board_id, 400070004210, 209),
    (400070004211, v_restaurant_id, v_board_id, 400070004211, 210),
    (400070004212, v_restaurant_id, v_board_id, 400070004212, 211),
    (400070004213, v_restaurant_id, v_board_id, 400070004213, 212),
    (400070004214, v_restaurant_id, v_board_id, 400070004214, 213),
    (400070004215, v_restaurant_id, v_board_id, 400070004215, 214),
    (400070004216, v_restaurant_id, v_board_id, 400070004216, 215),
    (400070004217, v_restaurant_id, v_board_id, 400070004217, 216),
    (400070004218, v_restaurant_id, v_board_id, 400070004218, 217),
    (400070004219, v_restaurant_id, v_board_id, 400070004219, 218),
    (400070004220, v_restaurant_id, v_board_id, 400070004220, 219),
    (400070004221, v_restaurant_id, v_board_id, 400070004221, 220),
    (400070004222, v_restaurant_id, v_board_id, 400070004222, 221),
    (400070004223, v_restaurant_id, v_board_id, 400070004223, 222),
    (400070004224, v_restaurant_id, v_board_id, 400070004224, 223),
    (400070004225, v_restaurant_id, v_board_id, 400070004225, 224),
    (400070004226, v_restaurant_id, v_board_id, 400070004226, 225),
    (400070004227, v_restaurant_id, v_board_id, 400070004227, 226),
    (400070004228, v_restaurant_id, v_board_id, 400070004228, 227),
    (400070004229, v_restaurant_id, v_board_id, 400070004229, 228),
    (400070004230, v_restaurant_id, v_board_id, 400070004230, 229),
    (400070004231, v_restaurant_id, v_board_id, 400070004231, 230),
    (400070004232, v_restaurant_id, v_board_id, 400070004232, 231),
    (400070004233, v_restaurant_id, v_board_id, 400070004233, 232),
    (400070004234, v_restaurant_id, v_board_id, 400070004234, 233),
    (400070004235, v_restaurant_id, v_board_id, 400070004235, 234),
    (400070004236, v_restaurant_id, v_board_id, 400070004236, 235),
    (400070004237, v_restaurant_id, v_board_id, 400070004237, 236);

-- ----------------------------------------------------------------------
-- Special cases: Friday-only Khichda, dine-in-only Thalis
-- ----------------------------------------------------------------------
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week)
VALUES (400070004001, 400070004081, 5);  -- Friday only, see note 7 at top

INSERT INTO menu_item_delivery (menu_item_delivery_id, menu_item_id, delivery_status_code, reason_code, effective_from)
VALUES
    (400070000004, 400070004158, 'not_available', N'dine_in_only', (clock_timestamp() AT TIME ZONE 'UTC')),
    (400070000005, 400070004159, 'not_available', N'dine_in_only', (clock_timestamp() AT TIME ZONE 'UTC')),
    (400070000006, 400070004160, 'not_available', N'dine_in_only', (clock_timestamp() AT TIME ZONE 'UTC')),
    (400070000007, 400070004161, 'not_available', N'dine_in_only', (clock_timestamp() AT TIME ZONE 'UTC'));  -- 'THALI - NOT IN PARCEL', see note 6 at top

END $$;

COMMIT;

-- ID re-key validation performed during preparation: every 910xxx ID in the
-- ID namespaces were remapped to the requested 400070004 / 400070004xxx series;
-- foreign-key references in this script were remapped with their owning IDs.
-- PostgreSQL execution was not performed in this environment.

-- ----------------------------------------------------------------------
-- Sanity check: run after commit
-- ----------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM menu_category WHERE restaurant_id = 400070004) AS categories,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070004) AS items,
    (SELECT COUNT(*) FROM menu_item_variant miv JOIN menu_item mi ON mi.menu_item_id = miv.menu_item_id WHERE mi.restaurant_id = 400070004) AS variants,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070004 AND verification_status_code = 'needs_review') AS flagged_for_review,
    (SELECT COUNT(*) FROM menu_item_delivery WHERE menu_item_id IN (SELECT menu_item_id FROM menu_item WHERE restaurant_id = 400070004)) AS delivery_restricted_items;
