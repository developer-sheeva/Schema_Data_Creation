-- =====================================================================
-- khaustan_menu_data_UtsavBarRestaurant_400070010_KhaustanRestaurantMenu.sql
--
-- RESTAURANT : Utsav Bar & Restaurant
--              196, L.B.S. Marg, Opp. Kalpana Cinema, Kurla (W), Mumbai - 400 070
-- IDS        : establishment_id = restaurant_id = source_id = 400070010
-- SOURCE     : Utsav_Bar_Restaurant_Menu_OCR.json  (OCR JSON, 9 menu-page images)
-- TARGET     : PostgreSQL, database "KhaustanRestaurantMenu" (one transaction)
-- SCHEMA REF : khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql
-- LOOKUP REF : khaustan_lookup_data_seed_KhaustanRestaurantMenu.sql (READ-ONLY - see below)
--
-- HOW TO RUN  psql -v ON_ERROR_STOP=1 -f <this file>
--             Run it once in a disposable/staging database first. It could not be
--             executed against PostgreSQL where it was produced.
--
-- LOOKUP TABLES ARE READ-ONLY IN THIS SCRIPT. It never inserts, updates or deletes a
-- service_mode, protein_type, delivery_provider or platform_tag row - it only reads
-- protein_type by code. No platform_tag, delivery_provider or service_mode row is
-- needed for this restaurant (see judgement calls below), so the pre-flight check only
-- verifies protein_type. It aborts before writing anything if a needed row is missing.
--
-- RUN ORDER DEPENDENCY: this script inserts bar_product rows with product_type_code =
-- 'BRANDY' and 'RTD'. Run khaustan_alter_bar_product_type_KhaustanRestaurantMenu.sql
-- FIRST (once, on the shared schema) - it widens bar_product's CHECK constraint to allow
-- those values. Without it this script's transaction fails cleanly on that CHECK and
-- nothing is written (ON_ERROR_STOP + one transaction), so the two scripts can't run
-- out of order and leave a partial load.
--
-- ID SCHEME (mandatory namespace from the brief - NOTE: different from the docx-based
-- Sahara Hotel script). establishment_id = restaurant_id = source_id = 400070010, a
-- SUPPLIED 9-digit value, not generated here. Every child table below that the brief
-- names as deterministic (menu_board, menu_category, menu_item, menu_item_variant,
-- menu_item_price, menu_board_item) gets its OWN counter, each starting at
-- 400070010001 = 400070010*1000+1 and incrementing by 1 in source order within that table -
-- these are six independent per-table counters that happen to share a starting literal,
-- not one shared sequence. menu_item_source and menu_item_price_source reuse the parent
-- menu_item_id/price_id (no id column of their own, matching the schema). menu_item_availability
-- is not used (no day/time-window text anywhere in the JSON). Everything else
-- (restaurant_phone_id, menu_extraction_batch_id, canonical_dish_id, canonical_dish_name_id,
-- bar_product_id) uses one ordinary helper sequence, since the brief leaves those to the
-- schema's normal application-generated approach.
--
-- ROWS LOADED
--   establishment 1 | restaurant 1 | restaurant_phone 1 | source_record 1
--   menu_extraction_batch 1 | menu_board 1 | menu_category 32 | menu_board_category 32
--   canonical_dish up to 131 (food items only) | menu_item 191 (134 food + 57 bar)
--   menu_item_source 191 | menu_item_variant 367 | menu_item_price 340
--   (27 variants have no legible price -> no price row) | menu_item_price_source 340
--   bar_product up to 51 | bar_menu_item 57 | menu_board_item 191
--
-- CONVENTIONS / DECISIONS
--  1. Names are stored exactly as printed (upper case as OCR'd); normalized_name = lower-case
--     with collapsed whitespace; nothing is expanded, corrected or re-spelled (kept as printed
--     even where the OCR looks wrong, e.g. "CARLSBERA ELEPHANT", "BUDWISER", "SMIROFF FLEVER").
--  2. Portion variants: the JSON already encodes most FULL/HALF and ml-ladder splits as an
--     explicit "prices" array on one item - those map straight to menu_item_variant rows,
--     labels kept exactly as printed ("FULL","HALF","180ml.","60 ml." - note the inconsistent
--     spacing before "ml." is preserved verbatim). Five dishes print FULL and HALF as two
--     separate single-price JSON entries with the size baked into the name text instead
--     (CHICKEN MALWANI/KADAI/HANDI, JEERA RICE, and BUTTER CHICKEN) - these were merged into
--     one item with two variants, same as the array-based ones, because Full/Half is a size
--     of one dish regardless of how the source JSON happened to structure it. BUTTER CHICKEN
--     printed BOTH lines as "(Full)" (210 and 120, no "(Half)" text anywhere) - confirmed as a
--     mislabelled Half and merged to FULL=210 / HALF=120 rather than left as printed.
--  2a. Four more items were restructured the same way on confirmation that the JSON's line
--     breaks did not match the real product boundaries: "SODA (330ml. + 300ml.)" and
--     "SODA (500ml.)" are one product with 3 size variants, not two; "COLD DRINKS
--     (700ml.+600ml.)", "COLD DRINKS (330ml.+300ml.)" and "COLD DRINKS (200ml.)" are one
--     product with 5 size variants, not three (FRESH LIME SODA, printed alongside them, is a
--     different product and was left alone); BISLERI's one variant is labelled "1 Ltr" rather
--     than "Regular". All of these stay priceless, as printed.
--  3. Categories: 32 menu_category rows, one per JSON section in page/source order, all
--     flat (parent_category_id NULL - the JSON has no parent/child category structure). Two
--     categories are literally both named "VODKA" (page 7 and page 8, printed as two separate
--     blocks) - both are loaded as separate category rows, not merged, matching "one row per
--     JSON section."
--  4. One a_la_carte menu_board covers the whole file: the JSON has no explicit board field
--     separating food from bar, and the brief says not to invent multiple boards without one.
--  5. food_classification_code is derived only from evidence already in the JSON: a definitional
--     ingredient/animal/egg word in the item's own name (chicken/mutton/fish/prawns -> non_veg;
--     egg/omelette -> egg; a vegetable, legume or dairy word -> veg), or, failing that, the
--     category heading itself when it says "(Veg)"/"(Non-Veg)"/"Non-Veg" or is a bread/rice/
--     raita/salad/papad section, or "INDIAN FISH STARTER" (-> non_veg/seafood, since none of its
--     fish-species item names carry a generic word). It is NULL for 4 items with
--     no such evidence (FINGER CHIPS, HARA BARA KABAB, UTSAV SPECIAL ROGAN HANDI, UTSAV SPECIAL
--     CHINESE SNACKS). LIVER OIL FRY and POTTA OIL FRY are non_veg (category "STARTER (Non-Veg)")
--     with protein_type_id left NULL (liver/gizzard does not say which animal). is_jain /
--     is_vegan / is_eggless / spice_level are NULL everywhere - nothing in the JSON asserts them.
--     Every item on the two bar pages (7-8) leaves food_classification_code and the three
--     booleans NULL entirely, per the schema's own convention for bar items.
--  6. Bar modeling: every item on pages 7-8 gets a bar_menu_item row. product_type_code is read
--     from the category heading (PREMIUM/DELUXE/REGULAR WHISK(E)Y -> whisky, RUM -> rum,
--     STRONG/MILD BEER -> beer, BRANDY -> brandy, VODKA -> vodka) UNLESS the item's own name or
--     brand identity says otherwise: BACARDI LEMON WHITE RUM -> rum and ROYAL GREEN WHISKY ->
--     whisky from their own printed name; and, confirmed as a menu-printing mistake rather than
--     an extraction error, eight more items under the page-8 "VODKA" heading are well-known
--     brands of a different spirit with no such word of their own in the JSON - product_type_code
--     was corrected by brand identity: BALLONTIES, STERLING RESERVE BT, AMERICAN PRIDE, BLACK &
--     WHITE, BLACK LABEL, VAT 69 and 100 PIPER -> whisky; BLACK BACARDI -> rum. raw_category_text
--     stays "VODKA" as printed (that's still what the menu shows); only the bar_product's own
--     type reflects the correction. BACARDI BREEZER, a flavoured alcoholic RTD with no closer
--     fit among the original 9 values, is stored as the new 'rtd' value. RED BULL, SODA and COLD
--     DRINKS lines -> bar_item_type_code 'mixer', bar_product_id NULL (they are not themselves a
--     catalogued alcoholic product). bar_product rows are identify-or-create on product_name
--     text, so "LONDON PILSNER" (printed once under STRONG BEER with bottle sizes, once under
--     MILD BEER with a single price) resolves to the SAME bar_product row from two different
--     menu_item rows - one product, two serving formats. Nothing in the schema stops this: there
--     is no unique constraint on bar_product.product_name or on bar_menu_item.bar_product_id, so
--     no ALTER was needed for it.
--  7. Canonical dishes (food items only; bar items are identified via bar_product instead):
--     exact-normalized-name match, 131 distinct dishes. A duplicate line in the SAME
--     category ("CHI. SCHZ. TRIPPLE RICE" x2) still resolves to ONE canonical dish, since it is
--     the same dish printed twice. DAL MAKHANI, printed under both "RICE" (Rs.130) and
--     "INDIAN VEG" (Rs.100) with no distinguishing text, is treated as two possibly-different
--     preparations - canonical_dish_id is left NULL for both, flagged.
--  8. Prices: no date or "rates effective from" text appears anywhere in the JSON, so
--     effective_from uses the extraction timestamp for every price row. No GST/tax wording
--     appears anywhere either, so all tax_* columns are NULL. "APS" (3 fish items) ->
--     is_market_price = TRUE, price_amount NULL. A blank or "--" price (27 variants
--     across 16 items/variant-lines) is NOT treated as a market price (nothing in
--     the JSON says so) - no menu_item_price row is inserted for that variant at all, flagged.
--     9 spirit prices that the OCR read from handwriting were re-read against the physical menu
--     and corrected where they differed from the JSON: BLACK DOG, ROYAL CHALLENGE, MCD LUXURY,
--     DSP BLACK, BAGPIPER, ROMANOV FLAVOR and ROMANOV each have one or more variant prices
--     replaced (see REVIEW BLOCK 2 for the exact old -> new values); OAK SMITH SILVER and
--     BLENDER'S PRIDE were re-read too but matched the JSON exactly, so nothing changed for them.
--  9. has_bar = TRUE and bar_license_type = 'full_bar' (whisky/vodka/rum/brandy content, not
--     just beer/wine) are read directly from the menu's own drink categories, not looked up
--     elsewhere. veg_nonveg_status = 'veg_and_nonveg' (both veg and non-veg dishes present).
-- 10. Not loaded (no restaurant-level column and/or no JSON evidence): opening hours, delivery
--     partners, GST/tax regime, geographic coordinates (latitude was blank in the JSON) - see
--     the trailing notes block.
-- 11. "INDIAN FISH STARTER" and "PAPAD" are ordinary menu_category rows like every other section
--     (Surmai Tawa Fry, Bangda Tawa/Oil Fry, Bombil Rawa Fry, Pomfret Tawa and Rawas Tawa sit
--     under the former) - menu_category has no lookup dependency of its own; only the item-level
--     protein_type_id lookup (Step above) touches a lookup table.
-- =====================================================================

--\connect "KhaustanRestaurantMenu"
\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 0a. Helper sequence for the standalone (non-deterministic) IDs listed above.
--     Never used for menu_board/menu_category/menu_item/menu_item_variant/menu_item_price/
--     menu_board_item - those use the mandatory per-table 400070010001+ namespace instead.
-- ---------------------------------------------------------------------
DO $seq$
DECLARE
    v_max BIGINT;
BEGIN
    SELECT GREATEST(
        COALESCE((SELECT MAX(restaurant_phone_id) FROM restaurant_phone), 0),
        COALESCE((SELECT MAX(extraction_batch_id) FROM menu_extraction_batch), 0),
        COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
        COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0),
        COALESCE((SELECT MAX(bar_product_id) FROM bar_product), 0)
    ) INTO v_max;
    EXECUTE format('CREATE SEQUENCE IF NOT EXISTS khaustan_utsav_helper_seq START WITH %s', v_max + 1);
END
$seq$;

-- ---------------------------------------------------------------------
-- 0b. PRE-FLIGHT (reads only; raises before anything is written)
-- ---------------------------------------------------------------------
DO $pre$
DECLARE
    v_missing text;
BEGIN
    SELECT string_agg(m.item, ', ' ORDER BY m.item)
      INTO v_missing
      FROM (
            SELECT 'protein_type.' || t.code AS item
              FROM (VALUES ('CHICKEN'), ('MUTTON'), ('SEAFOOD'), ('EGG')) AS t(code)
             WHERE NOT EXISTS (SELECT 1 FROM protein_type p WHERE p.code = t.code)
           ) AS m;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Utsav Bar & Restaurant load aborted - lookup rows missing: %. Run the lookup seed script first.', v_missing;
    END IF;

    IF EXISTS (SELECT 1 FROM menu_item WHERE restaurant_id = 400070010)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400070010)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 400070010) THEN
        RAISE EXCEPTION 'Utsav Bar & Restaurant (restaurant_id 400070010) already has menu data or source_id 400070010 is in use - refusing to load twice.';
    END IF;

    IF EXISTS (SELECT 1 FROM establishment
                WHERE normalized_name = 'utsav bar & restaurant' AND postal_code = '400070'
                  AND establishment_id <> 400070010) THEN
        RAISE EXCEPTION 'An establishment named utsav bar & restaurant already exists in 400070 under a different id - resolve before loading.';
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------
-- 1. Establishment + restaurant. City/state are left to the schema's own DEFAULT
--    ('Mumbai'/'Maharashtra') rather than inserted literally - the JSON's address text
--    is consistent with those defaults but does not itself assert a state name.
-- ---------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, latitude, longitude)
SELECT 400070010, 'Utsav Bar & Restaurant', 'utsav bar & restaurant',
       '196, L.B.S. Marg, Opp. Kalpana Cinema', 'Kurla (W)', '400070', 19.076616681856446, 72.87773102038592
WHERE NOT EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400070010);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, veg_nonveg_status, has_bar, bar_license_type)
SELECT 400070010, 400070010, 'Utsav Bar & Restaurant', 'utsav bar & restaurant', 'veg_and_nonveg', TRUE, 'full_bar'
WHERE NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400070010);

-- ---------------------------------------------------------------------
-- 2. Phone (JSON restaurant.phone "9323707699", also printed as "Cell : 9323707699" on the
--    cover page - one number, no distinction between a business and personal line is stated,
--    so is_personal_number keeps its default FALSE)
-- ---------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES (nextval('khaustan_utsav_helper_seq'), 400070010, '9323707699', TRUE);

-- ---------------------------------------------------------------------
-- 3. Provenance: one source record (source_id = 400070010, per the mandatory ID rule) and one
--    extraction batch
-- ---------------------------------------------------------------------
INSERT INTO source_record (source_id, source_type_code, source_uri) VALUES
(400070010, 'ai_menu_extraction', 'Utsav_Bar_Restaurant_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, extractor_version, started_at, completed_at, status_code) VALUES
(nextval('khaustan_utsav_helper_seq'), 400070010, 400070010, 'claude-sonnet-5 (json menu prompt, schema-resolved)', (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

-- ---------------------------------------------------------------------
-- 4. Menu board (single a_la_carte board = the whole JSON; no board field in the source)
-- ---------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, display_sequence) VALUES
(400070010001, 400070010, 'Utsav Bar & Restaurant Menu', 'a_la_carte', 1);

-- ---------------------------------------------------------------------
-- 5. menu_category, one per JSON section in page/source order (flat - no parent/child structure
--    in the JSON). "VODKA" appears twice (page 7, page 8) as two separate category rows.
-- ---------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence) VALUES
-- page 2
(400070010001, 400070010, 'INDIAN STARTER', 1),
(400070010002, 400070010, 'INDIAN SOUP', 2),
(400070010003, 400070010, 'CHINESE VEG SOUP', 3),
(400070010004, 400070010, 'CHINESE NON-VEG SOUP', 4),
-- page 3
(400070010005, 400070010, 'CHINESE VEG. STARTER', 5),
(400070010006, 400070010, 'INDIAN FISH STARTER', 6),
(400070010007, 400070010, 'STARTER (Non-Veg)', 7),
-- page 4
(400070010008, 400070010, 'INDIAN VEG', 8),
(400070010009, 400070010, 'RAITA', 9),
(400070010010, 400070010, 'SALAD', 10),
-- page 5
(400070010011, 400070010, 'CURRY (Non-Veg)', 11),
(400070010012, 400070010, 'Utsav Special', 12),
-- page 6
(400070010013, 400070010, 'CHAPATI', 13),
(400070010014, 400070010, 'RICE', 14),
(400070010015, 400070010, 'RICE (Non-Veg)', 15),
(400070010016, 400070010, 'PAPAD', 16),
-- page 7
(400070010017, 400070010, 'CHICKEN CHINESE STARTER', 17),
(400070010018, 400070010, 'CHINESE RICE (Veg)', 18),
(400070010019, 400070010, 'CHINESE RICE (Non-Veg)', 19),
(400070010020, 400070010, 'CHINESE NOODLES (Veg)', 20),
(400070010021, 400070010, 'CHINESE NOODLES (Non-Veg)', 21),
-- page 8
(400070010022, 400070010, 'PREMIUM WHISKEY', 22),
(400070010023, 400070010, 'DELUXE WHISKEY', 23),
(400070010024, 400070010, 'REGULAR WHISKY', 24),
(400070010025, 400070010, 'VODKA', 25),
-- page 9
(400070010026, 400070010, 'VODKA', 26),
(400070010027, 400070010, 'RUM', 27),
(400070010028, 400070010, 'BRANDY', 28),
(400070010029, 400070010, 'STRONG BEER', 29),
(400070010030, 400070010, 'MILD BEER', 30),
(400070010031, 400070010, 'OTHER BEVERAGES', 31),
(400070010032, 400070010, 'COLD DRINKS', 32);

-- ---------------------------------------------------------------------
-- 6. menu_board_category: every category is exposed on the single board
-- ---------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
(400070010, 400070010001, 400070010001, 1),
(400070010, 400070010001, 400070010002, 2),
(400070010, 400070010001, 400070010003, 3),
(400070010, 400070010001, 400070010004, 4),
(400070010, 400070010001, 400070010005, 5),
(400070010, 400070010001, 400070010006, 6),
(400070010, 400070010001, 400070010007, 7),
(400070010, 400070010001, 400070010008, 8),
(400070010, 400070010001, 400070010009, 9),
(400070010, 400070010001, 400070010010, 10),
(400070010, 400070010001, 400070010011, 11),
(400070010, 400070010001, 400070010012, 12),
(400070010, 400070010001, 400070010013, 13),
(400070010, 400070010001, 400070010014, 14),
(400070010, 400070010001, 400070010015, 15),
(400070010, 400070010001, 400070010016, 16),
(400070010, 400070010001, 400070010017, 17),
(400070010, 400070010001, 400070010018, 18),
(400070010, 400070010001, 400070010019, 19),
(400070010, 400070010001, 400070010020, 20),
(400070010, 400070010001, 400070010021, 21),
(400070010, 400070010001, 400070010022, 22),
(400070010, 400070010001, 400070010023, 23),
(400070010, 400070010001, 400070010024, 24),
(400070010, 400070010001, 400070010025, 25),
(400070010, 400070010001, 400070010026, 26),
(400070010, 400070010001, 400070010027, 27),
(400070010, 400070010001, 400070010028, 28),
(400070010, 400070010001, 400070010029, 29),
(400070010, 400070010001, 400070010030, 30),
(400070010, 400070010001, 400070010031, 31),
(400070010, 400070010001, 400070010032, 32);

-- ---------------------------------------------------------------------
-- 7. canonical_dish + canonical_dish_name for FOOD items only (identify-or-create on exact
--    normalised name; canonical_dish has no unique constraint, hence NOT EXISTS). Bar items are
--    identified via bar_product instead (Step 9) and never get a canonical_dish_id.
--    DAL MAKHANI is deliberately NOT given a canonical row here (see header note 7); its two
--    menu_item rows link canonical_dish_id = NULL.
-- ---------------------------------------------------------------------
WITH v(cname, nname) AS (VALUES
('CHEESE', 'cheese'),
('CHEESE PAKODA', 'cheese pakoda'),
('FINGER CHIPS', 'finger chips'),
('ALOO CHAT CHANA', 'aloo chat chana'),
('CHANA OIL FRY', 'chana oil fry'),
('CHANA GARLIC FRY', 'chana garlic fry'),
('CHANA KOLIWADA', 'chana koliwada'),
('PANEER BHURJI', 'paneer bhurji'),
('PANEER PAKODA', 'paneer pakoda'),
('VEG PAKODA', 'veg pakoda'),
('HARA BARA KABAB', 'hara bara kabab'),
('TOMATO SOUP', 'tomato soup'),
('PALAK SOUP', 'palak soup'),
('VEG SOUP', 'veg soup'),
('VEG MANCHOW SOUP', 'veg manchow soup'),
('VEG HOT & SOUR SOUP', 'veg hot & sour soup'),
('VEG CLEAR SOUP', 'veg clear soup'),
('VEG SWEET CORN SOUP', 'veg sweet corn soup'),
('CHI. MANCHOW SOUP', 'chi. manchow soup'),
('CHI. HOT & SOUR SOUP', 'chi. hot & sour soup'),
('CHI. TALIMEIM SOUP', 'chi. talimeim soup'),
('CHI. CLEAR SOUP', 'chi. clear soup'),
('CHI. LUNG FUNG SOUP', 'chi. lung fung soup'),
('VEG. CHILLY DRY', 'veg. chilly dry'),
('VEG. MANCHURIAN', 'veg. manchurian'),
('GOBI MANCHURIAN', 'gobi manchurian'),
('PANEER CHILLY', 'paneer chilly'),
('VEG. CRISPY', 'veg. crispy'),
('CRISPY CHILLY POTATO', 'crispy chilly potato'),
('SURMAI TAWA FRY', 'surmai tawa fry'),
('BANGDA TAWA / OIL FRY', 'bangda tawa / oil fry'),
('MANDELI FRY', 'mandeli fry'),
('BOMBIL RAWA FRY', 'bombil rawa fry'),
('POMFRET TAWA', 'pomfret tawa'),
('RAWAS TAWA', 'rawas tawa'),
('CHICKEN KOLIWADA', 'chicken koliwada'),
('CHICKEN PAKODA', 'chicken pakoda'),
('FISH KOLIWADA', 'fish koliwada'),
('FISH TAWA FRY', 'fish tawa fry'),
('LIVER OIL FRY', 'liver oil fry'),
('POTTA OIL FRY', 'potta oil fry'),
('BOILED EGG', 'boiled egg'),
('OMELETTE', 'omelette'),
('EGG BHURGI', 'egg bhurgi'),
('EGG PAKODA', 'egg pakoda'),
('ALOO GOBI', 'aloo gobi'),
('ALOO MUTTER', 'aloo mutter'),
('DUM ALOO PUNJABI', 'dum aloo punjabi'),
('MIX VEG', 'mix veg'),
('VEG HANDI', 'veg handi'),
('VEG KADAI', 'veg kadai'),
('VEG MAKHANWALA', 'veg makhanwala'),
('VEG HYDRABADI', 'veg hydrabadi'),
('PANEER MUTTER', 'paneer mutter'),
('PANEER MASALA', 'paneer masala'),
('PANEER KADAI', 'paneer kadai'),
('PANEER DO PYAZA', 'paneer do pyaza'),
('PALAK PANEER', 'palak paneer'),
('VEG PATIALA', 'veg patiala'),
('PANEER MIX', 'paneer mix'),
('ALOO PALAK', 'aloo palak'),
('VEG KOLHAPURI', 'veg kolhapuri'),
('CHANA MASALA', 'chana masala'),
('DAL PALAK', 'dal palak'),
('DAL FRY', 'dal fry'),
('DAL TADKA', 'dal tadka'),
('DAL SORBA', 'dal sorba'),
('VEG RAITA', 'veg raita'),
('BUNDI RAITA', 'bundi raita'),
('DAHI', 'dahi'),
('GREEN SALAD', 'green salad'),
('KACHUMBER SALAD', 'kachumber salad'),
('CUCUMBER SALAD', 'cucumber salad'),
('FINGER CUT SALAD', 'finger cut salad'),
('CHICKEN MALWANI', 'chicken malwani'),
('CHICKEN SUKKA', 'chicken sukka'),
('CHICKEN MASALA FRY', 'chicken masala fry'),
('CHICKEN MASALA', 'chicken masala'),
('CHICKEN KOLHAPURI', 'chicken kolhapuri'),
('CHICKEN KADAI', 'chicken kadai'),
('CHICKEN HANDI', 'chicken handi'),
('CHICKEN LEVER MASALA', 'chicken lever masala'),
('CHICKEN POTTA MASALA', 'chicken potta masala'),
('CHICKEN DO PYAZA', 'chicken do pyaza'),
('CHICKEN LAZIZ', 'chicken laziz'),
('CHICKEN PATIYALA', 'chicken patiyala'),
('CHICKEN AGRI MASALA', 'chicken agri masala'),
('UTSAV SPECIAL ROGAN HANDI', 'utsav special rogan handi'),
('UTSAV SPECIAL CHICKEN', 'utsav special chicken'),
('UTSAV SPECIAL CHINESE SNACKS', 'utsav special chinese snacks'),
('CHAPATI', 'chapati'),
('BUTTER CHAPATI', 'butter chapati'),
('ROTI', 'roti'),
('BUTTER ROTI', 'butter roti'),
('JEERA RICE', 'jeera rice'),
('STEAM RICE', 'steam rice'),
('VEG. PULAO', 'veg. pulao'),
('DAL KICHADI', 'dal kichadi'),
('PALAK KICHADI', 'palak kichadi'),
('VEG. BIRYANI', 'veg. biryani'),
('EGG BIRYANI', 'egg biryani'),
('CHICKEN BIRYANI', 'chicken biryani'),
('CHICKEN PULAO', 'chicken pulao'),
('CHICKEN BATKAI', 'chicken batkai'),
('CHICKEN HYDRABADI', 'chicken hydrabadi'),
('CHI. HANDI BIRYANI', 'chi. handi biryani'),
('FRY PAPAD', 'fry papad'),
('ROASTED PAPAD', 'roasted papad'),
('MASALA PAPAD', 'masala papad'),
('CHICKEN CHILLY', 'chicken chilly'),
('CHICKEN MANCHURIAN', 'chicken manchurian'),
('CHICKEN LOLLYPOP', 'chicken lollypop'),
('CHICKEN CRISPY', 'chicken crispy'),
('CHICKEN 65', 'chicken 65'),
('CHICKEN GARLIC', 'chicken garlic'),
('CHICKEN SCHEZWAN', 'chicken schezwan'),
('CHI. CHILLY GINGER GARLIC', 'chi. chilly ginger garlic'),
('VEG. FRIED RICE', 'veg. fried rice'),
('VEG. SCHZ. TRIPPLE RICE', 'veg. schz. tripple rice'),
('VEG. SCHEZWAN RICE', 'veg. schezwan rice'),
('VEG. MANCHURIAN RICE', 'veg. manchurian rice'),
('CHICKEN FRIED RICE', 'chicken fried rice'),
('CHI. SCHZ. TRIPPLE RICE', 'chi. schz. tripple rice'),
('CHI. SCHEZWAN RICE', 'chi. schezwan rice'),
('VEG. HAKKA NOODLES', 'veg. hakka noodles'),
('VEG. SCHEZWAN NOODLES', 'veg. schezwan noodles'),
('VEG. CHOWMEN NOODLES', 'veg. chowmen noodles'),
('CHI. HAKKA NOODLES', 'chi. hakka noodles'),
('CH. SCHEZWAN NOODLES', 'ch. schezwan noodles'),
('CHI. AMERICAN CHOPSEY', 'chi. american chopsey'),
('BUTTER CHICKEN', 'butter chicken')
)
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
SELECT nextval('khaustan_utsav_helper_seq'), v.cname, v.nname FROM v
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish c WHERE c.normalized_name = v.nname);

INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_utsav_helper_seq'), c.canonical_dish_id, 'en', c.canonical_name, c.normalized_name, 'primary'
FROM canonical_dish c
WHERE c.normalized_name IN ('cheese',
       'cheese pakoda',
       'finger chips',
       'aloo chat chana',
       'chana oil fry',
       'chana garlic fry',
       'chana koliwada',
       'paneer bhurji',
       'paneer pakoda',
       'veg pakoda',
       'hara bara kabab',
       'tomato soup',
       'palak soup',
       'veg soup',
       'veg manchow soup',
       'veg hot & sour soup',
       'veg clear soup',
       'veg sweet corn soup',
       'chi. manchow soup',
       'chi. hot & sour soup',
       'chi. talimeim soup',
       'chi. clear soup',
       'chi. lung fung soup',
       'veg. chilly dry',
       'veg. manchurian',
       'gobi manchurian',
       'paneer chilly',
       'veg. crispy',
       'crispy chilly potato',
       'surmai tawa fry',
       'bangda tawa / oil fry',
       'mandeli fry',
       'bombil rawa fry',
       'pomfret tawa',
       'rawas tawa',
       'chicken koliwada',
       'chicken pakoda',
       'fish koliwada',
       'fish tawa fry',
       'liver oil fry',
       'potta oil fry',
       'boiled egg',
       'omelette',
       'egg bhurgi',
       'egg pakoda',
       'aloo gobi',
       'aloo mutter',
       'dum aloo punjabi',
       'mix veg',
       'veg handi',
       'veg kadai',
       'veg makhanwala',
       'veg hydrabadi',
       'paneer mutter',
       'paneer masala',
       'paneer kadai',
       'paneer do pyaza',
       'palak paneer',
       'veg patiala',
       'paneer mix',
       'aloo palak',
       'veg kolhapuri',
       'chana masala',
       'dal palak',
       'dal fry',
       'dal tadka',
       'dal sorba',
       'veg raita',
       'bundi raita',
       'dahi',
       'green salad',
       'kachumber salad',
       'cucumber salad',
       'finger cut salad',
       'chicken malwani',
       'chicken sukka',
       'chicken masala fry',
       'chicken masala',
       'chicken kolhapuri',
       'chicken kadai',
       'chicken handi',
       'chicken lever masala',
       'chicken potta masala',
       'chicken do pyaza',
       'chicken laziz',
       'chicken patiyala',
       'chicken agri masala',
       'utsav special rogan handi',
       'utsav special chicken',
       'utsav special chinese snacks',
       'chapati',
       'butter chapati',
       'roti',
       'butter roti',
       'jeera rice',
       'steam rice',
       'veg. pulao',
       'dal kichadi',
       'palak kichadi',
       'veg. biryani',
       'egg biryani',
       'chicken biryani',
       'chicken pulao',
       'chicken batkai',
       'chicken hydrabadi',
       'chi. handi biryani',
       'fry papad',
       'roasted papad',
       'masala papad',
       'chicken chilly',
       'chicken manchurian',
       'chicken lollypop',
       'chicken crispy',
       'chicken 65',
       'chicken garlic',
       'chicken schezwan',
       'chi. chilly ginger garlic',
       'veg. fried rice',
       'veg. schz. tripple rice',
       'veg. schezwan rice',
       'veg. manchurian rice',
       'chicken fried rice',
       'chi. schz. tripple rice',
       'chi. schezwan rice',
       'veg. hakka noodles',
       'veg. schezwan noodles',
       'veg. chowmen noodles',
       'chi. hakka noodles',
       'ch. schezwan noodles',
       'chi. american chopsey',
       'butter chicken')
  AND NOT EXISTS (SELECT 1 FROM canonical_dish_name n WHERE n.canonical_dish_id = c.canonical_dish_id AND n.name_type_code = 'primary');

-- ---------------------------------------------------------------------
-- 8. bar_product (identify-or-create on product_name; NOT EXISTS, no unique constraint on the
--    table). One row per distinct printed brand/product name across the whole file - "LONDON
--    PILSNER" is created once and reused by both its STRONG BEER and MILD BEER menu_item rows.
-- ---------------------------------------------------------------------

INSERT INTO bar_product (bar_product_id, product_type_id, product_name)
WITH v(ptype_code, pname, matchname) AS (
    VALUES
    ('WHYSKY', 'OAK SMITH SILVER', 'OAK SMITH SILVER'),
    ('WHYSKY', 'OAK SMITH GOLD', 'OAK SMITH GOLD'),
    ('WHYSKY', 'BLACK DOG', 'BLACK DOG'),
    ('WHYSKY', 'TEACHERS', 'TEACHERS'),
    ('WHYSKY', 'BLENDER''S PRIDE', 'BLENDER''S PRIDE'),
    ('WHYSKY', 'SIGNATURE', 'SIGNATURE'),
    ('WHYSKY', 'ROYAL CHALLENGE', 'ROYAL CHALLENGE'),
    ('WHYSKY', 'RSD BARAL', 'RSD BARAL'),
    ('WHYSKY', 'OC BLUE', 'OC BLUE'),
    ('WHYSKY', 'MCD LUXURY', 'MCD LUXURY'),
    ('WHYSKY', 'ROYAL STAG', 'ROYAL STAG'),
    ('WHYSKY', 'McDOWELL''S NO. 1', 'McDOWELL''S NO. 1'),
    ('WHYSKY', 'IMPERIAL BLUE', 'IMPERIAL BLUE'),
    ('WHYSKY', 'DSP BLACK', 'DSP BLACK'),
    ('WHYSKY', 'BAGPIPER', 'BAGPIPER'),
    ('WHYSKY', 'DIRECTOR''S SPECIAL', 'DIRECTOR''S SPECIAL'),
    ('WHYSKY', 'OFFICER''S CHOICE', 'OFFICER''S CHOICE'),
    ('WHYSKY', 'HAYWARD', 'HAYWARD'),
    ('VODKA', 'SMIROFF FLEVER', 'SMIROFF FLEVER'),
    ('VODKA', 'SIMIRONOFF', 'SIMIRONOFF'),
    ('VODKA', 'ROMANOV FLAVOR', 'ROMANOV FLAVOR'),
    ('VODKA', 'ROMANOV', 'ROMANOV'),
    ('VODKA', 'MAGIC MOVEMENT', 'MAGIC MOVEMENT'),
    ('VODKA', 'WHITE MICHIEF', 'WHITE MICHIEF'),
    ('VODKA', 'MAGIC MOVEMENT APPLE', 'MAGIC MOVEMENT APPLE'),
    ('WHYSKY', 'BALLONTIES', 'BALLONTIES'),
    ('VODKA', 'ABSOLUTE VODKA', 'ABSOLUTE VODKA'),
    ('WHYSKY', 'STERLING RESERVE BT', 'STERLING RESERVE BT'),
    ('WHYSKY', 'AMERICAN PRIDE', 'AMERICAN PRIDE'),
    ('VODKA', 'GRAND MASTER VODKA', 'GRAND MASTER VODKA'),
    ('RUM', 'BACARDI LEMON WHITE RUM', 'BACARDI LEMON WHITE RUM'),
    ('WHYSKY', 'ROYAL GREEN WHISKY', 'ROYAL GREEN WHISKY'),
    ('RUM', 'BLACK BACARDI', 'BLACK BACARDI'),
    ('WHYSKY', 'BLACK & WHITE', 'BLACK & WHITE'),
    ('WHYSKY', 'BLACK LABEL', 'BLACK LABEL'),
    ('WHYSKY', 'VAT 69', 'VAT 69'),
    ('WHYSKY', '100 PIPER', '100 PIPER'),
    ('RUM', 'BACARDI WHITE RUM LEMON', 'BACARDI WHITE RUM LEMON'),
    ('RUM', 'OLD MONK RUM', 'OLD MONK RUM'),
    ('RUM', 'MCD No. 1 CELEBERATION', 'MCD No. 1 CELEBERATION'),
    ('BRANDY', 'DR. BRANDY', 'DR. BRANDY'),
    ('STRONG_BEER', 'TUBROG STRONG', 'TUBROG STRONG'),
    ('STRONG_BEER', 'HAYWARD 2000', 'HAYWARD 2000'),
    ('STRONG_BEER', 'LONDON PILSNER', 'LONDON PILSNER'),
    ('STRONG_BEER', 'CARLSBERA ELEPHANT', 'CARLSBERA ELEPHANT'),
    ('STRONG_BEER', 'BUDWISER MAGNIUM', 'BUDWISER MAGNIUM'),
    ('MILD_BEER', 'CARLIBERG', 'CARLIBERG'),
    ('MILD_BEER', 'BUDWISER', 'BUDWISER'),
    ('MILD_BEER', 'KINGFISHER MILD', 'KINGFISHER MILD'),
    ('MILD_BEER', 'KF ULTRA', 'KF ULTRA'),
    ('BREEZER', 'BACARDI BREEZER', 'BACARDI BREEZER')
)
SELECT 
    nextval('khaustan_utsav_helper_seq'), 
    pt.bar_product_type_id, 
    v.pname
FROM v
-- Automatically fetch the correct IDs by joining the product type table
JOIN bar_product_type pt 
  ON upper(pt.bar_product_code) = v.ptype_code
WHERE NOT EXISTS (
    SELECT 1 FROM bar_product b WHERE b.product_name = v.matchname
);

-- ---------------------------------------------------------------------
-- 9. menu_item, in JSON/source order (page, then section, then item).
-- ---------------------------------------------------------------------
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code) VALUES
-- Source: JSON, page 2, "INDIAN STARTER" section
(400070010001, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheese' ORDER BY canonical_dish_id LIMIT 1), 'CHEESE', 'cheese', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010002, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheese pakoda' ORDER BY canonical_dish_id LIMIT 1), 'CHEESE PAKODA', 'cheese pakoda', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010003, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'finger chips' ORDER BY canonical_dish_id LIMIT 1), 'FINGER CHIPS', 'finger chips', 'INDIAN STARTER', NULL, NULL, 'unverified'),
(400070010004, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo chat chana' ORDER BY canonical_dish_id LIMIT 1), 'ALOO CHAT CHANA', 'aloo chat chana', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010005, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chana oil fry' ORDER BY canonical_dish_id LIMIT 1), 'CHANA OIL FRY', 'chana oil fry', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010006, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chana garlic fry' ORDER BY canonical_dish_id LIMIT 1), 'CHANA GARLIC FRY', 'chana garlic fry', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010007, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chana koliwada' ORDER BY canonical_dish_id LIMIT 1), 'CHANA KOLIWADA', 'chana koliwada', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010008, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer bhurji' ORDER BY canonical_dish_id LIMIT 1), 'PANEER BHURJI', 'paneer bhurji', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010009, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer pakoda' ORDER BY canonical_dish_id LIMIT 1), 'PANEER PAKODA', 'paneer pakoda', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010010, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg pakoda' ORDER BY canonical_dish_id LIMIT 1), 'VEG PAKODA', 'veg pakoda', 'INDIAN STARTER', 'veg', NULL, 'unverified'),
(400070010011, 400070010, 400070010001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hara bara kabab' ORDER BY canonical_dish_id LIMIT 1), 'HARA BARA KABAB', 'hara bara kabab', 'INDIAN STARTER', NULL, NULL, 'unverified'),
-- Source: JSON, page 2, "INDIAN SOUP" section
(400070010012, 400070010, 400070010002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tomato soup' ORDER BY canonical_dish_id LIMIT 1), 'TOMATO SOUP', 'tomato soup', 'INDIAN SOUP', 'veg', NULL, 'unverified'),
(400070010013, 400070010, 400070010002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'palak soup' ORDER BY canonical_dish_id LIMIT 1), 'PALAK SOUP', 'palak soup', 'INDIAN SOUP', 'veg', NULL, 'unverified'),
(400070010014, 400070010, 400070010002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg soup' ORDER BY canonical_dish_id LIMIT 1), 'VEG SOUP', 'veg soup', 'INDIAN SOUP', 'veg', NULL, 'unverified'),
-- Source: JSON, page 2, "CHINESE VEG SOUP" section
(400070010015, 400070010, 400070010003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg manchow soup' ORDER BY canonical_dish_id LIMIT 1), 'VEG MANCHOW SOUP', 'veg manchow soup', 'CHINESE VEG SOUP', 'veg', NULL, 'unverified'),
(400070010016, 400070010, 400070010003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hot & sour soup' ORDER BY canonical_dish_id LIMIT 1), 'VEG HOT & SOUR SOUP', 'veg hot & sour soup', 'CHINESE VEG SOUP', 'veg', NULL, 'unverified'),
(400070010017, 400070010, 400070010003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg clear soup' ORDER BY canonical_dish_id LIMIT 1), 'VEG CLEAR SOUP', 'veg clear soup', 'CHINESE VEG SOUP', 'veg', NULL, 'unverified'),
(400070010018, 400070010, 400070010003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg sweet corn soup' ORDER BY canonical_dish_id LIMIT 1), 'VEG SWEET CORN SOUP', 'veg sweet corn soup', 'CHINESE VEG SOUP', 'veg', NULL, 'unverified'),
-- Source: JSON, page 2, "CHINESE NON-VEG SOUP" section
(400070010019, 400070010, 400070010004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. manchow soup' ORDER BY canonical_dish_id LIMIT 1), 'CHI. MANCHOW SOUP', 'chi. manchow soup', 'CHINESE NON-VEG SOUP', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010020, 400070010, 400070010004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. hot & sour soup' ORDER BY canonical_dish_id LIMIT 1), 'CHI. HOT & SOUR SOUP', 'chi. hot & sour soup', 'CHINESE NON-VEG SOUP', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010021, 400070010, 400070010004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. talimeim soup' ORDER BY canonical_dish_id LIMIT 1), 'CHI. TALIMEIM SOUP', 'chi. talimeim soup', 'CHINESE NON-VEG SOUP', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010022, 400070010, 400070010004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. clear soup' ORDER BY canonical_dish_id LIMIT 1), 'CHI. CLEAR SOUP', 'chi. clear soup', 'CHINESE NON-VEG SOUP', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010023, 400070010, 400070010004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. lung fung soup' ORDER BY canonical_dish_id LIMIT 1), 'CHI. LUNG FUNG SOUP', 'chi. lung fung soup', 'CHINESE NON-VEG SOUP', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- Source: JSON, page 3, "CHINESE VEG. STARTER" section
(400070010024, 400070010, 400070010005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. chilly dry' ORDER BY canonical_dish_id LIMIT 1), 'VEG. CHILLY DRY', 'veg. chilly dry', 'CHINESE VEG. STARTER', 'veg', NULL, 'unverified'),
(400070010025, 400070010, 400070010005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. manchurian' ORDER BY canonical_dish_id LIMIT 1), 'VEG. MANCHURIAN', 'veg. manchurian', 'CHINESE VEG. STARTER', 'veg', NULL, 'unverified'),
(400070010026, 400070010, 400070010005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'gobi manchurian' ORDER BY canonical_dish_id LIMIT 1), 'GOBI MANCHURIAN', 'gobi manchurian', 'CHINESE VEG. STARTER', 'veg', NULL, 'unverified'),
(400070010027, 400070010, 400070010005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chilly' ORDER BY canonical_dish_id LIMIT 1), 'PANEER CHILLY', 'paneer chilly', 'CHINESE VEG. STARTER', 'veg', NULL, 'unverified'),
(400070010028, 400070010, 400070010005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. crispy' ORDER BY canonical_dish_id LIMIT 1), 'VEG. CRISPY', 'veg. crispy', 'CHINESE VEG. STARTER', 'veg', NULL, 'unverified'),
(400070010029, 400070010, 400070010005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'crispy chilly potato' ORDER BY canonical_dish_id LIMIT 1), 'CRISPY CHILLY POTATO', 'crispy chilly potato', 'CHINESE VEG. STARTER', 'veg', NULL, 'unverified'),
-- Source: JSON, page 3, "INDIAN FISH STARTER" section
(400070010030, 400070010, 400070010006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'surmai tawa fry' ORDER BY canonical_dish_id LIMIT 1), 'SURMAI TAWA FRY', 'surmai tawa fry', 'INDIAN FISH STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010031, 400070010, 400070010006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'bangda tawa / oil fry' ORDER BY canonical_dish_id LIMIT 1), 'BANGDA TAWA / OIL FRY', 'bangda tawa / oil fry', 'INDIAN FISH STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010032, 400070010, 400070010006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mandeli fry' ORDER BY canonical_dish_id LIMIT 1), 'MANDELI FRY', 'mandeli fry', 'INDIAN FISH STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010033, 400070010, 400070010006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'bombil rawa fry' ORDER BY canonical_dish_id LIMIT 1), 'BOMBIL RAWA FRY', 'bombil rawa fry', 'INDIAN FISH STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010034, 400070010, 400070010006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pomfret tawa' ORDER BY canonical_dish_id LIMIT 1), 'POMFRET TAWA', 'pomfret tawa', 'INDIAN FISH STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010035, 400070010, 400070010006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'rawas tawa' ORDER BY canonical_dish_id LIMIT 1), 'RAWAS TAWA', 'rawas tawa', 'INDIAN FISH STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
-- Source: JSON, page 3, "STARTER (Non-Veg)" section
(400070010036, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken koliwada' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN KOLIWADA', 'chicken koliwada', 'STARTER (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010037, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken pakoda' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN PAKODA', 'chicken pakoda', 'STARTER (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010038, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fish koliwada' ORDER BY canonical_dish_id LIMIT 1), 'FISH KOLIWADA', 'fish koliwada', 'STARTER (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010039, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fish tawa fry' ORDER BY canonical_dish_id LIMIT 1), 'FISH TAWA FRY', 'fish tawa fry', 'STARTER (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'),
(400070010040, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'liver oil fry' ORDER BY canonical_dish_id LIMIT 1), 'LIVER OIL FRY', 'liver oil fry', 'STARTER (Non-Veg)', 'non_veg', NULL, 'unverified'),
(400070010041, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'potta oil fry' ORDER BY canonical_dish_id LIMIT 1), 'POTTA OIL FRY', 'potta oil fry', 'STARTER (Non-Veg)', 'non_veg', NULL, 'unverified'),
(400070010042, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'boiled egg' ORDER BY canonical_dish_id LIMIT 1), 'BOILED EGG', 'boiled egg', 'STARTER (Non-Veg)', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), 'unverified'),
(400070010043, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'omelette' ORDER BY canonical_dish_id LIMIT 1), 'OMELETTE', 'omelette', 'STARTER (Non-Veg)', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), 'unverified'),
(400070010044, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg bhurgi' ORDER BY canonical_dish_id LIMIT 1), 'EGG BHURGI', 'egg bhurgi', 'STARTER (Non-Veg)', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), 'unverified'),
(400070010045, 400070010, 400070010007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg pakoda' ORDER BY canonical_dish_id LIMIT 1), 'EGG PAKODA', 'egg pakoda', 'STARTER (Non-Veg)', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), 'unverified'),
-- Source: JSON, page 4, "INDIAN VEG" section
(400070010046, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo gobi' ORDER BY canonical_dish_id LIMIT 1), 'ALOO GOBI', 'aloo gobi', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010047, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo mutter' ORDER BY canonical_dish_id LIMIT 1), 'ALOO MUTTER', 'aloo mutter', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010048, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dum aloo punjabi' ORDER BY canonical_dish_id LIMIT 1), 'DUM ALOO PUNJABI', 'dum aloo punjabi', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010049, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix veg' ORDER BY canonical_dish_id LIMIT 1), 'MIX VEG', 'mix veg', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010050, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg handi' ORDER BY canonical_dish_id LIMIT 1), 'VEG HANDI', 'veg handi', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010051, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg kadai' ORDER BY canonical_dish_id LIMIT 1), 'VEG KADAI', 'veg kadai', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010052, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg makhanwala' ORDER BY canonical_dish_id LIMIT 1), 'VEG MAKHANWALA', 'veg makhanwala', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010053, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hydrabadi' ORDER BY canonical_dish_id LIMIT 1), 'VEG HYDRABADI', 'veg hydrabadi', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010054, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer mutter' ORDER BY canonical_dish_id LIMIT 1), 'PANEER MUTTER', 'paneer mutter', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010055, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer masala' ORDER BY canonical_dish_id LIMIT 1), 'PANEER MASALA', 'paneer masala', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010056, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kadai' ORDER BY canonical_dish_id LIMIT 1), 'PANEER KADAI', 'paneer kadai', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010057, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer do pyaza' ORDER BY canonical_dish_id LIMIT 1), 'PANEER DO PYAZA', 'paneer do pyaza', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010058, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'palak paneer' ORDER BY canonical_dish_id LIMIT 1), 'PALAK PANEER', 'palak paneer', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010059, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg patiala' ORDER BY canonical_dish_id LIMIT 1), 'VEG PATIALA', 'veg patiala', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010060, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer mix' ORDER BY canonical_dish_id LIMIT 1), 'PANEER MIX', 'paneer mix', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010061, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo palak' ORDER BY canonical_dish_id LIMIT 1), 'ALOO PALAK', 'aloo palak', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010062, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg kolhapuri' ORDER BY canonical_dish_id LIMIT 1), 'VEG KOLHAPURI', 'veg kolhapuri', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010063, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chana masala' ORDER BY canonical_dish_id LIMIT 1), 'CHANA MASALA', 'chana masala', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010064, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal palak' ORDER BY canonical_dish_id LIMIT 1), 'DAL PALAK', 'dal palak', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010065, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal fry' ORDER BY canonical_dish_id LIMIT 1), 'DAL FRY', 'dal fry', 'INDIAN VEG', 'veg', NULL, 'unverified'),
(400070010066, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal tadka' ORDER BY canonical_dish_id LIMIT 1), 'DAL TADKA', 'dal tadka', 'INDIAN VEG', 'veg', NULL, 'unverified'),
-- NEEDS_REVIEW item: same printed name also appears under RICE (a different section) -> canonical_dish_id left NULL so two possibly-different products are not merged
(400070010067, 400070010, 400070010008, NULL, 'DAL MAKHANI', 'dal makhani', 'INDIAN VEG', 'veg', NULL, 'needs_review'),
(400070010068, 400070010, 400070010008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal sorba' ORDER BY canonical_dish_id LIMIT 1), 'DAL SORBA', 'dal sorba', 'INDIAN VEG', 'veg', NULL, 'unverified'),
-- Source: JSON, page 4, "RAITA" section
(400070010069, 400070010, 400070010009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg raita' ORDER BY canonical_dish_id LIMIT 1), 'VEG RAITA', 'veg raita', 'RAITA', 'veg', NULL, 'unverified'),
(400070010070, 400070010, 400070010009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'bundi raita' ORDER BY canonical_dish_id LIMIT 1), 'BUNDI RAITA', 'bundi raita', 'RAITA', 'veg', NULL, 'unverified'),
(400070010071, 400070010, 400070010009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dahi' ORDER BY canonical_dish_id LIMIT 1), 'DAHI', 'dahi', 'RAITA', 'veg', NULL, 'unverified'),
-- Source: JSON, page 4, "SALAD" section
(400070010072, 400070010, 400070010010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'green salad' ORDER BY canonical_dish_id LIMIT 1), 'GREEN SALAD', 'green salad', 'SALAD', 'veg', NULL, 'unverified'),
(400070010073, 400070010, 400070010010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kachumber salad' ORDER BY canonical_dish_id LIMIT 1), 'KACHUMBER SALAD', 'kachumber salad', 'SALAD', 'veg', NULL, 'unverified'),
(400070010074, 400070010, 400070010010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cucumber salad' ORDER BY canonical_dish_id LIMIT 1), 'CUCUMBER SALAD', 'cucumber salad', 'SALAD', 'veg', NULL, 'unverified'),
(400070010075, 400070010, 400070010010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'finger cut salad' ORDER BY canonical_dish_id LIMIT 1), 'FINGER CUT SALAD', 'finger cut salad', 'SALAD', 'veg', NULL, 'unverified'),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
-- merged printed rows: CHICKEN MALWANI (Full) | CHICKEN MALWANI (Half) -> one item, 2 variants
(400070010076, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken malwani' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN MALWANI', 'chicken malwani', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010077, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken sukka' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN SUKKA', 'chicken sukka', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010078, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken masala fry' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN MASALA FRY', 'chicken masala fry', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010079, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken masala' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN MASALA', 'chicken masala', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010080, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN KOLHAPURI', 'chicken kolhapuri', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- merged printed rows: CHICKEN KADAI (Full) | CHICKEN KADAI (Half) -> one item, 2 variants
(400070010081, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kadai' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN KADAI', 'chicken kadai', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- merged printed rows: CHICKEN HANDI (Full) | CHICKEN HANDI (Half) -> one item, 2 variants
(400070010082, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken handi' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN HANDI', 'chicken handi', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010083, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lever masala' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN LEVER MASALA', 'chicken lever masala', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010084, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken potta masala' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN POTTA MASALA', 'chicken potta masala', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010085, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken do pyaza' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN DO PYAZA', 'chicken do pyaza', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010086, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken laziz' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN LAZIZ', 'chicken laziz', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010087, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken patiyala' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN PATIYALA', 'chicken patiyala', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010088, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken agri masala' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN AGRI MASALA', 'chicken agri masala', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- Source: JSON, page 5, "Utsav Special" section
(400070010089, 400070010, 400070010012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'utsav special rogan handi' ORDER BY canonical_dish_id LIMIT 1), 'UTSAV SPECIAL ROGAN HANDI', 'utsav special rogan handi', 'Utsav Special', NULL, NULL, 'unverified'),
(400070010090, 400070010, 400070010012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'utsav special chicken' ORDER BY canonical_dish_id LIMIT 1), 'UTSAV SPECIAL CHICKEN', 'utsav special chicken', 'Utsav Special', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010091, 400070010, 400070010012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'utsav special chinese snacks' ORDER BY canonical_dish_id LIMIT 1), 'UTSAV SPECIAL CHINESE SNACKS', 'utsav special chinese snacks', 'Utsav Special', NULL, NULL, 'unverified'),
-- Source: JSON, page 6, "CHAPATI" section
(400070010092, 400070010, 400070010013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chapati' ORDER BY canonical_dish_id LIMIT 1), 'CHAPATI', 'chapati', 'CHAPATI', 'veg', NULL, 'unverified'),
(400070010093, 400070010, 400070010013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter chapati' ORDER BY canonical_dish_id LIMIT 1), 'BUTTER CHAPATI', 'butter chapati', 'CHAPATI', 'veg', NULL, 'unverified'),
(400070010094, 400070010, 400070010013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roti' ORDER BY canonical_dish_id LIMIT 1), 'ROTI', 'roti', 'CHAPATI', 'veg', NULL, 'unverified'),
(400070010095, 400070010, 400070010013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter roti' ORDER BY canonical_dish_id LIMIT 1), 'BUTTER ROTI', 'butter roti', 'CHAPATI', 'veg', NULL, 'unverified'),
-- Source: JSON, page 6, "RICE" section
-- merged printed rows: JEERA RICE (FULL) | JEERA RICE (HALF) -> one item, 2 variants
(400070010096, 400070010, 400070010014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'jeera rice' ORDER BY canonical_dish_id LIMIT 1), 'JEERA RICE', 'jeera rice', 'RICE', 'veg', NULL, 'unverified'),
(400070010097, 400070010, 400070010014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'steam rice' ORDER BY canonical_dish_id LIMIT 1), 'STEAM RICE', 'steam rice', 'RICE', 'veg', NULL, 'unverified'),
(400070010098, 400070010, 400070010014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. pulao' ORDER BY canonical_dish_id LIMIT 1), 'VEG. PULAO', 'veg. pulao', 'RICE', 'veg', NULL, 'unverified'),
(400070010099, 400070010, 400070010014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal kichadi' ORDER BY canonical_dish_id LIMIT 1), 'DAL KICHADI', 'dal kichadi', 'RICE', 'veg', NULL, 'unverified'),
(400070010100, 400070010, 400070010014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'palak kichadi' ORDER BY canonical_dish_id LIMIT 1), 'PALAK KICHADI', 'palak kichadi', 'RICE', 'veg', NULL, 'unverified'),
(400070010101, 400070010, 400070010014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. biryani' ORDER BY canonical_dish_id LIMIT 1), 'VEG. BIRYANI', 'veg. biryani', 'RICE', 'veg', NULL, 'unverified'),
-- NEEDS_REVIEW item: same printed name also appears under INDIAN VEG (a different section) -> canonical_dish_id left NULL so two possibly-different products are not merged
(400070010102, 400070010, 400070010014, NULL, 'DAL MAKHANI', 'dal makhani', 'RICE', 'veg', NULL, 'needs_review'),
-- Source: JSON, page 6, "RICE (Non-Veg)" section
(400070010103, 400070010, 400070010015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg biryani' ORDER BY canonical_dish_id LIMIT 1), 'EGG BIRYANI', 'egg biryani', 'RICE (Non-Veg)', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), 'unverified'),
(400070010104, 400070010, 400070010015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken biryani' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN BIRYANI', 'chicken biryani', 'RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010105, 400070010, 400070010015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken pulao' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN PULAO', 'chicken pulao', 'RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010106, 400070010, 400070010015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken batkai' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN BATKAI', 'chicken batkai', 'RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010107, 400070010, 400070010015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN HYDRABADI', 'chicken hydrabadi', 'RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010108, 400070010, 400070010015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. handi biryani' ORDER BY canonical_dish_id LIMIT 1), 'CHI. HANDI BIRYANI', 'chi. handi biryani', 'RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- Source: JSON, page 6, "PAPAD" section
(400070010109, 400070010, 400070010016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'fry papad' ORDER BY canonical_dish_id LIMIT 1), 'FRY PAPAD', 'fry papad', 'PAPAD', 'veg', NULL, 'unverified'),
(400070010110, 400070010, 400070010016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'roasted papad' ORDER BY canonical_dish_id LIMIT 1), 'ROASTED PAPAD', 'roasted papad', 'PAPAD', 'veg', NULL, 'unverified'),
(400070010111, 400070010, 400070010016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'masala papad' ORDER BY canonical_dish_id LIMIT 1), 'MASALA PAPAD', 'masala papad', 'PAPAD', 'veg', NULL, 'unverified'),
-- Source: JSON, page 7, "CHICKEN CHINESE STARTER" section
(400070010112, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chilly' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN CHILLY', 'chicken chilly', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010113, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken manchurian' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN MANCHURIAN', 'chicken manchurian', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010114, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lollypop' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN LOLLYPOP', 'chicken lollypop', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010115, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken crispy' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN CRISPY', 'chicken crispy', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010116, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken 65' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN 65', 'chicken 65', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010117, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken garlic' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN GARLIC', 'chicken garlic', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010118, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN SCHEZWAN', 'chicken schezwan', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010119, 400070010, 400070010017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. chilly ginger garlic' ORDER BY canonical_dish_id LIMIT 1), 'CHI. CHILLY GINGER GARLIC', 'chi. chilly ginger garlic', 'CHICKEN CHINESE STARTER', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- Source: JSON, page 7, "CHINESE RICE (Veg)" section
(400070010120, 400070010, 400070010018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. fried rice' ORDER BY canonical_dish_id LIMIT 1), 'VEG. FRIED RICE', 'veg. fried rice', 'CHINESE RICE (Veg)', 'veg', NULL, 'unverified'),
(400070010121, 400070010, 400070010018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. schz. tripple rice' ORDER BY canonical_dish_id LIMIT 1), 'VEG. SCHZ. TRIPPLE RICE', 'veg. schz. tripple rice', 'CHINESE RICE (Veg)', 'veg', NULL, 'unverified'),
(400070010122, 400070010, 400070010018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. schezwan rice' ORDER BY canonical_dish_id LIMIT 1), 'VEG. SCHEZWAN RICE', 'veg. schezwan rice', 'CHINESE RICE (Veg)', 'veg', NULL, 'unverified'),
(400070010123, 400070010, 400070010018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. manchurian rice' ORDER BY canonical_dish_id LIMIT 1), 'VEG. MANCHURIAN RICE', 'veg. manchurian rice', 'CHINESE RICE (Veg)', 'veg', NULL, 'unverified'),
-- Source: JSON, page 7, "CHINESE RICE (Non-Veg)" section
(400070010124, 400070010, 400070010019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken fried rice' ORDER BY canonical_dish_id LIMIT 1), 'CHICKEN FRIED RICE', 'chicken fried rice', 'CHINESE RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- NEEDS_REVIEW item: duplicate line in the source JSON - "CHI. SCHZ. TRIPPLE RICE" appears 2 times in category "CHINESE RICE (Non-Veg)" with no distinguishing text; kept as separate menu_item rows, not merged
(400070010125, 400070010, 400070010019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. schz. tripple rice' ORDER BY canonical_dish_id LIMIT 1), 'CHI. SCHZ. TRIPPLE RICE', 'chi. schz. tripple rice', 'CHINESE RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'),
(400070010126, 400070010, 400070010019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. schezwan rice' ORDER BY canonical_dish_id LIMIT 1), 'CHI. SCHEZWAN RICE', 'chi. schezwan rice', 'CHINESE RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- NEEDS_REVIEW item: duplicate line in the source JSON - "CHI. SCHZ. TRIPPLE RICE" appears 2 times in category "CHINESE RICE (Non-Veg)" with no distinguishing text; kept as separate menu_item rows, not merged
(400070010127, 400070010, 400070010019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. schz. tripple rice' ORDER BY canonical_dish_id LIMIT 1), 'CHI. SCHZ. TRIPPLE RICE', 'chi. schz. tripple rice', 'CHINESE RICE (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'),
-- Source: JSON, page 7, "CHINESE NOODLES (Veg)" section
(400070010128, 400070010, 400070010020, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. hakka noodles' ORDER BY canonical_dish_id LIMIT 1), 'VEG. HAKKA NOODLES', 'veg. hakka noodles', 'CHINESE NOODLES (Veg)', 'veg', NULL, 'unverified'),
(400070010129, 400070010, 400070010020, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. schezwan noodles' ORDER BY canonical_dish_id LIMIT 1), 'VEG. SCHEZWAN NOODLES', 'veg. schezwan noodles', 'CHINESE NOODLES (Veg)', 'veg', NULL, 'unverified'),
(400070010130, 400070010, 400070010020, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. chowmen noodles' ORDER BY canonical_dish_id LIMIT 1), 'VEG. CHOWMEN NOODLES', 'veg. chowmen noodles', 'CHINESE NOODLES (Veg)', 'veg', NULL, 'unverified'),
-- Source: JSON, page 7, "CHINESE NOODLES (Non-Veg)" section
(400070010131, 400070010, 400070010021, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. hakka noodles' ORDER BY canonical_dish_id LIMIT 1), 'CHI. HAKKA NOODLES', 'chi. hakka noodles', 'CHINESE NOODLES (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010132, 400070010, 400070010021, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'ch. schezwan noodles' ORDER BY canonical_dish_id LIMIT 1), 'CH. SCHEZWAN NOODLES', 'ch. schezwan noodles', 'CHINESE NOODLES (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
(400070010133, 400070010, 400070010021, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chi. american chopsey' ORDER BY canonical_dish_id LIMIT 1), 'CHI. AMERICAN CHOPSEY', 'chi. american chopsey', 'CHINESE NOODLES (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- Source: JSON, page 8, "PREMIUM WHISKEY" section
(400070010134, 400070010, 400070010022, NULL, 'OAK SMITH SILVER', 'oak smith silver', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010135, 400070010, 400070010022, NULL, 'OAK SMITH GOLD', 'oak smith gold', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010136, 400070010, 400070010022, NULL, 'BLACK DOG', 'black dog', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010137, 400070010, 400070010022, NULL, 'TEACHERS', 'teachers', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010138, 400070010, 400070010022, NULL, 'BLENDER''S PRIDE', 'blender''s pride', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010139, 400070010, 400070010022, NULL, 'SIGNATURE', 'signature', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010140, 400070010, 400070010022, NULL, 'ROYAL CHALLENGE', 'royal challenge', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
(400070010141, 400070010, 400070010022, NULL, 'RSD BARAL', 'rsd baral', 'PREMIUM WHISKEY', NULL, NULL, 'unverified'),
-- Source: JSON, page 8, "DELUXE WHISKEY" section
(400070010142, 400070010, 400070010023, NULL, 'OC BLUE', 'oc blue', 'DELUXE WHISKEY', NULL, NULL, 'unverified'),
(400070010143, 400070010, 400070010023, NULL, 'MCD LUXURY', 'mcd luxury', 'DELUXE WHISKEY', NULL, NULL, 'unverified'),
(400070010144, 400070010, 400070010023, NULL, 'ROYAL STAG', 'royal stag', 'DELUXE WHISKEY', NULL, NULL, 'unverified'),
(400070010145, 400070010, 400070010023, NULL, 'McDOWELL''S NO. 1', 'mcdowell''s no. 1', 'DELUXE WHISKEY', NULL, NULL, 'unverified'),
-- Source: JSON, page 8, "REGULAR WHISKY" section
(400070010146, 400070010, 400070010024, NULL, 'IMPERIAL BLUE', 'imperial blue', 'REGULAR WHISKY', NULL, NULL, 'unverified'),
(400070010147, 400070010, 400070010024, NULL, 'DSP BLACK', 'dsp black', 'REGULAR WHISKY', NULL, NULL, 'unverified'),
(400070010148, 400070010, 400070010024, NULL, 'BAGPIPER', 'bagpiper', 'REGULAR WHISKY', NULL, NULL, 'unverified'),
(400070010149, 400070010, 400070010024, NULL, 'DIRECTOR''S SPECIAL', 'director''s special', 'REGULAR WHISKY', NULL, NULL, 'unverified'),
(400070010150, 400070010, 400070010024, NULL, 'OFFICER''S CHOICE', 'officer''s choice', 'REGULAR WHISKY', NULL, NULL, 'unverified'),
(400070010151, 400070010, 400070010024, NULL, 'HAYWARD', 'hayward', 'REGULAR WHISKY', NULL, NULL, 'unverified'),
-- Source: JSON, page 8, "VODKA" section
(400070010152, 400070010, 400070010025, NULL, 'SMIROFF FLEVER', 'smiroff flever', 'VODKA', NULL, NULL, 'unverified'),
(400070010153, 400070010, 400070010025, NULL, 'SIMIRONOFF', 'simironoff', 'VODKA', NULL, NULL, 'unverified'),
(400070010154, 400070010, 400070010025, NULL, 'ROMANOV FLAVOR', 'romanov flavor', 'VODKA', NULL, NULL, 'unverified'),
(400070010155, 400070010, 400070010025, NULL, 'ROMANOV', 'romanov', 'VODKA', NULL, NULL, 'unverified'),
(400070010156, 400070010, 400070010025, NULL, 'MAGIC MOVEMENT', 'magic movement', 'VODKA', NULL, NULL, 'unverified'),
(400070010157, 400070010, 400070010025, NULL, 'WHITE MICHIEF', 'white michief', 'VODKA', NULL, NULL, 'unverified'),
(400070010158, 400070010, 400070010025, NULL, 'MAGIC MOVEMENT APPLE', 'magic movement apple', 'VODKA', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "VODKA" section
(400070010159, 400070010, 400070010026, NULL, 'BALLONTIES', 'ballonties', 'VODKA', NULL, NULL, 'unverified'),
(400070010160, 400070010, 400070010026, NULL, 'ABSOLUTE VODKA', 'absolute vodka', 'VODKA', NULL, NULL, 'unverified'),
(400070010161, 400070010, 400070010026, NULL, 'STERLING RESERVE BT', 'sterling reserve bt', 'VODKA', NULL, NULL, 'unverified'),
(400070010162, 400070010, 400070010026, NULL, 'AMERICAN PRIDE', 'american pride', 'VODKA', NULL, NULL, 'unverified'),
(400070010163, 400070010, 400070010026, NULL, 'GRAND MASTER VODKA', 'grand master vodka', 'VODKA', NULL, NULL, 'unverified'),
(400070010164, 400070010, 400070010026, NULL, 'BACARDI LEMON WHITE RUM', 'bacardi lemon white rum', 'VODKA', NULL, NULL, 'unverified'),
(400070010165, 400070010, 400070010026, NULL, 'ROYAL GREEN WHISKY', 'royal green whisky', 'VODKA', NULL, NULL, 'unverified'),
(400070010166, 400070010, 400070010026, NULL, 'BLACK BACARDI', 'black bacardi', 'VODKA', NULL, NULL, 'unverified'),
(400070010167, 400070010, 400070010026, NULL, 'BLACK & WHITE', 'black & white', 'VODKA', NULL, NULL, 'unverified'),
(400070010168, 400070010, 400070010026, NULL, 'BLACK LABEL', 'black label', 'VODKA', NULL, NULL, 'unverified'),
(400070010169, 400070010, 400070010026, NULL, 'VAT 69', 'vat 69', 'VODKA', NULL, NULL, 'unverified'),
(400070010170, 400070010, 400070010026, NULL, '100 PIPER', '100 piper', 'VODKA', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "RUM" section
(400070010171, 400070010, 400070010027, NULL, 'BACARDI WHITE RUM LEMON', 'bacardi white rum lemon', 'RUM', NULL, NULL, 'unverified'),
(400070010172, 400070010, 400070010027, NULL, 'OLD MONK RUM', 'old monk rum', 'RUM', NULL, NULL, 'unverified'),
(400070010173, 400070010, 400070010027, NULL, 'MCD No. 1 CELEBERATION', 'mcd no. 1 celeberation', 'RUM', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "BRANDY" section
(400070010174, 400070010, 400070010028, NULL, 'DR. BRANDY', 'dr. brandy', 'BRANDY', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "STRONG BEER" section
(400070010175, 400070010, 400070010029, NULL, 'TUBROG STRONG', 'tubrog strong', 'STRONG BEER', NULL, NULL, 'unverified'),
(400070010176, 400070010, 400070010029, NULL, 'HAYWARD 2000', 'hayward 2000', 'STRONG BEER', NULL, NULL, 'unverified'),
(400070010177, 400070010, 400070010029, NULL, 'LONDON PILSNER', 'london pilsner', 'STRONG BEER', NULL, NULL, 'unverified'),
(400070010178, 400070010, 400070010029, NULL, 'CARLSBERA ELEPHANT', 'carlsbera elephant', 'STRONG BEER', NULL, NULL, 'unverified'),
(400070010179, 400070010, 400070010029, NULL, 'BUDWISER MAGNIUM', 'budwiser magnium', 'STRONG BEER', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "MILD BEER" section
(400070010180, 400070010, 400070010030, NULL, 'CARLIBERG', 'carliberg', 'MILD BEER', NULL, NULL, 'unverified'),
(400070010181, 400070010, 400070010030, NULL, 'BUDWISER', 'budwiser', 'MILD BEER', NULL, NULL, 'unverified'),
(400070010182, 400070010, 400070010030, NULL, 'KINGFISHER MILD', 'kingfisher mild', 'MILD BEER', NULL, NULL, 'unverified'),
(400070010183, 400070010, 400070010030, NULL, 'LONDON PILSNER', 'london pilsner', 'MILD BEER', NULL, NULL, 'unverified'),
(400070010184, 400070010, 400070010030, NULL, 'KF ULTRA', 'kf ultra', 'MILD BEER', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010185, 400070010, 400070010031, NULL, 'BACARDI BREEZER', 'bacardi breezer', 'OTHER BEVERAGES', NULL, NULL, 'unverified'),
(400070010186, 400070010, 400070010031, NULL, 'RED BULL', 'red bull', 'OTHER BEVERAGES', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010187, 400070010, 400070010032, NULL, 'FRESH LIME SODA', 'fresh lime soda', 'COLD DRINKS', NULL, NULL, 'unverified'),
(400070010188, 400070010, 400070010032, NULL, 'BISLERI', 'bisleri', 'COLD DRINKS', NULL, NULL, 'unverified'),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
-- merged printed rows: BUTTER CHICKEN (Full) | BUTTER CHICKEN (Full) -> one item, 2 variants
(400070010189, 400070010, 400070010011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter chicken' ORDER BY canonical_dish_id LIMIT 1), 'BUTTER CHICKEN', 'butter chicken', 'CURRY (Non-Veg)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
-- merged printed rows: SODA (330ml. + 300ml.) | SODA (500ml.) -> one item, 3 variants
(400070010190, 400070010, 400070010031, NULL, 'SODA', 'soda', 'OTHER BEVERAGES', NULL, NULL, 'unverified'),
-- Source: JSON, page 9, "COLD DRINKS" section
-- merged printed rows: COLD DRINKS (700ml. + 600 ml.) | COLD DRINKS (330ml. + 300 ml.) | COLD DRINKS (200ml.) -> one item, 5 variants
(400070010191, 400070010, 400070010032, NULL, 'COLD DRINKS', 'cold drinks', 'COLD DRINKS', NULL, NULL, 'unverified');

-- ---------------------------------------------------------------------
-- 10. menu_item_source: item existence/name confidence for this batch (composite PK - no
--     separate id column; menu_item_id is the exact id assigned above). extraction_batch_id is
--     looked up rather than hardcoded, since it was assigned from the helper sequence in step 3.
-- ---------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) VALUES
(400070010001, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010002, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010003, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010004, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010005, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010006, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010007, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010008, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010009, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010010, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010011, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010012, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010013, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010014, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010015, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010016, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010017, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010018, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010019, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010020, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010021, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010022, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010023, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010024, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010025, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010026, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010027, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010028, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010029, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010030, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010031, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010032, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010033, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010034, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010035, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010036, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010037, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010038, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010039, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010040, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010041, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010042, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010043, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010044, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010045, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010046, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010047, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010048, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010049, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010050, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010051, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010052, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010053, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010054, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010055, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010056, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010057, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010058, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010059, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010060, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010061, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010062, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010063, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010064, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010065, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010066, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010067, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'needs_review'),
(400070010068, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010069, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010070, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010071, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010072, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010073, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010074, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010075, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010076, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010077, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010078, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010079, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010080, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010081, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010082, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010083, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010084, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010085, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010086, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010087, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010088, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010089, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010090, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010091, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010092, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010093, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010094, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010095, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010096, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010097, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010098, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010099, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010100, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010101, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010102, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'needs_review'),
(400070010103, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010104, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010105, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010106, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010107, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010108, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010109, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010110, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010111, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010112, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010113, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010114, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010115, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010116, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010117, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010118, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010119, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010120, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010121, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010122, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010123, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010124, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010125, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'needs_review'),
(400070010126, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010127, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'needs_review'),
(400070010128, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010129, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010130, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010131, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010132, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010133, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010134, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010135, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010136, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010137, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010138, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010139, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010140, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010141, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010142, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010143, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010144, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010145, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010146, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010147, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010148, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010149, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010150, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010151, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010152, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010153, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010154, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010155, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010156, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010157, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010158, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010159, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010160, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010161, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010162, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010163, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010164, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010165, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010166, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010167, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010168, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010169, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010170, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010171, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010172, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010173, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010174, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010175, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010176, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010177, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010178, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010179, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010180, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010181, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010182, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010183, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010184, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010185, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010186, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010187, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010188, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010189, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010190, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified'),
(400070010191, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95, 'unverified');

-- ---------------------------------------------------------------------
-- 11. menu_item_variant. A single-price item gets one 'Regular' variant. A FULL/HALF pair
--     defaults to FULL; a size ladder (ml.) defaults to the first-listed (largest) size.
-- ---------------------------------------------------------------------
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
-- Source: JSON, page 2, "INDIAN STARTER" section
(400070010001, 400070010001, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010002, 400070010002, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010003, 400070010003, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010004, 400070010004, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010005, 400070010005, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010006, 400070010006, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010007, 400070010007, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010008, 400070010008, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010009, 400070010009, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010010, 400070010010, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010011, 400070010011, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 2, "INDIAN SOUP" section
(400070010012, 400070010012, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010013, 400070010013, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010014, 400070010014, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 2, "CHINESE VEG SOUP" section
(400070010015, 400070010015, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010016, 400070010016, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010017, 400070010017, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010018, 400070010018, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 2, "CHINESE NON-VEG SOUP" section
(400070010019, 400070010019, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010020, 400070010020, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010021, 400070010021, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010022, 400070010022, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010023, 400070010023, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 3, "CHINESE VEG. STARTER" section
(400070010024, 400070010024, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010025, 400070010024, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010026, 400070010025, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010027, 400070010025, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010028, 400070010026, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010029, 400070010026, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010030, 400070010027, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010031, 400070010027, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010032, 400070010028, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010033, 400070010028, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010034, 400070010029, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010035, 400070010029, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 3, "INDIAN FISH STARTER" section
(400070010036, 400070010030, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010037, 400070010031, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010038, 400070010032, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010039, 400070010033, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010040, 400070010034, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010041, 400070010035, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 3, "STARTER (Non-Veg)" section
(400070010042, 400070010036, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010043, 400070010037, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010044, 400070010038, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010045, 400070010039, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010046, 400070010040, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010047, 400070010041, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010048, 400070010042, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010049, 400070010043, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010050, 400070010044, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010051, 400070010045, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 4, "INDIAN VEG" section
(400070010052, 400070010046, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010053, 400070010047, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010054, 400070010048, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010055, 400070010049, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010056, 400070010050, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010057, 400070010051, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010058, 400070010052, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010059, 400070010053, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010060, 400070010054, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010061, 400070010055, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010062, 400070010056, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010063, 400070010057, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010064, 400070010058, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010065, 400070010059, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010066, 400070010060, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010067, 400070010061, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010068, 400070010062, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010069, 400070010063, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010070, 400070010064, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010071, 400070010065, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010072, 400070010066, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010073, 400070010067, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010074, 400070010068, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 4, "RAITA" section
(400070010075, 400070010069, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010076, 400070010070, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010077, 400070010071, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 4, "SALAD" section
(400070010078, 400070010072, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010079, 400070010072, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010080, 400070010073, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010081, 400070010073, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010082, 400070010074, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010083, 400070010074, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010084, 400070010075, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010085, 400070010075, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
(400070010086, 400070010076, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010087, 400070010076, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010088, 400070010077, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010089, 400070010078, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010090, 400070010079, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010091, 400070010080, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010092, 400070010081, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010093, 400070010081, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010094, 400070010082, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010095, 400070010082, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010096, 400070010083, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010097, 400070010084, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010098, 400070010085, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010099, 400070010086, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010100, 400070010087, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010101, 400070010088, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 5, "Utsav Special" section
(400070010102, 400070010089, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010103, 400070010090, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010104, 400070010091, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 6, "CHAPATI" section
(400070010105, 400070010092, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010106, 400070010093, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010107, 400070010094, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010108, 400070010095, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 6, "RICE" section
(400070010109, 400070010096, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010110, 400070010096, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010111, 400070010097, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010112, 400070010098, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010113, 400070010099, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010114, 400070010100, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010115, 400070010101, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010116, 400070010102, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 6, "RICE (Non-Veg)" section
(400070010117, 400070010103, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010118, 400070010103, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010119, 400070010104, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010120, 400070010104, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010121, 400070010105, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010122, 400070010105, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010123, 400070010106, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010124, 400070010106, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010125, 400070010107, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010126, 400070010107, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010127, 400070010108, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010128, 400070010108, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 6, "PAPAD" section
(400070010129, 400070010109, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010130, 400070010110, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010131, 400070010111, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 7, "CHICKEN CHINESE STARTER" section
(400070010132, 400070010112, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010133, 400070010112, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010134, 400070010113, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010135, 400070010113, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010136, 400070010114, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010137, 400070010114, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010138, 400070010115, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010139, 400070010115, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010140, 400070010116, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010141, 400070010116, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010142, 400070010117, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010143, 400070010117, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010144, 400070010118, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010145, 400070010118, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010146, 400070010119, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010147, 400070010119, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 7, "CHINESE RICE (Veg)" section
(400070010148, 400070010120, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010149, 400070010120, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010150, 400070010121, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010151, 400070010121, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010152, 400070010122, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010153, 400070010122, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010154, 400070010123, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010155, 400070010123, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 7, "CHINESE RICE (Non-Veg)" section
(400070010156, 400070010124, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010157, 400070010124, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010158, 400070010125, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010159, 400070010125, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010160, 400070010126, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010161, 400070010126, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
(400070010162, 400070010127, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010163, 400070010127, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 7, "CHINESE NOODLES (Veg)" section
(400070010164, 400070010128, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010165, 400070010129, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010166, 400070010130, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 7, "CHINESE NOODLES (Non-Veg)" section
(400070010167, 400070010131, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010168, 400070010132, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010169, 400070010133, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 8, "PREMIUM WHISKEY" section
(400070010170, 400070010134, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010171, 400070010134, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010172, 400070010134, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010173, 400070010134, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010174, 400070010135, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010175, 400070010135, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010176, 400070010135, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010177, 400070010135, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010178, 400070010136, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010179, 400070010136, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010180, 400070010136, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010181, 400070010136, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010182, 400070010137, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010183, 400070010137, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010184, 400070010137, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010185, 400070010137, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010186, 400070010138, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010187, 400070010138, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010188, 400070010138, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010189, 400070010138, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010190, 400070010139, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010191, 400070010139, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010192, 400070010139, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010193, 400070010139, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010194, 400070010140, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010195, 400070010140, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010196, 400070010140, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010197, 400070010140, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010198, 400070010141, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010199, 400070010141, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010200, 400070010141, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010201, 400070010141, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 8, "DELUXE WHISKEY" section
(400070010202, 400070010142, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010203, 400070010142, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010204, 400070010142, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010205, 400070010142, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010206, 400070010143, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010207, 400070010143, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010208, 400070010143, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010209, 400070010143, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010210, 400070010144, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010211, 400070010144, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010212, 400070010144, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010213, 400070010144, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010214, 400070010145, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010215, 400070010145, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010216, 400070010145, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010217, 400070010145, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 8, "REGULAR WHISKY" section
(400070010218, 400070010146, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010219, 400070010146, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010220, 400070010146, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010221, 400070010146, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010222, 400070010147, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010223, 400070010147, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010224, 400070010147, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010225, 400070010147, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010226, 400070010148, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010227, 400070010148, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010228, 400070010148, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010229, 400070010148, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010230, 400070010149, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010231, 400070010149, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010232, 400070010149, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010233, 400070010149, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010234, 400070010150, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010235, 400070010150, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010236, 400070010150, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010237, 400070010150, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010238, 400070010151, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010239, 400070010151, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010240, 400070010151, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010241, 400070010151, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 8, "VODKA" section
(400070010242, 400070010152, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010243, 400070010152, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010244, 400070010152, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010245, 400070010152, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010246, 400070010153, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010247, 400070010153, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010248, 400070010153, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010249, 400070010153, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010250, 400070010154, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010251, 400070010154, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010252, 400070010154, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010253, 400070010154, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010254, 400070010155, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010255, 400070010155, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010256, 400070010155, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010257, 400070010155, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010258, 400070010156, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010259, 400070010156, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010260, 400070010156, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010261, 400070010156, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010262, 400070010157, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010263, 400070010157, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010264, 400070010157, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010265, 400070010157, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010266, 400070010158, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010267, 400070010158, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010268, 400070010158, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010269, 400070010158, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 9, "VODKA" section
(400070010270, 400070010159, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010271, 400070010159, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010272, 400070010159, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010273, 400070010159, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010274, 400070010160, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010275, 400070010160, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010276, 400070010160, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010277, 400070010160, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010278, 400070010161, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010279, 400070010161, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010280, 400070010161, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010281, 400070010161, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010282, 400070010162, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010283, 400070010162, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010284, 400070010162, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010285, 400070010162, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010286, 400070010163, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010287, 400070010163, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010288, 400070010163, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010289, 400070010163, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010290, 400070010164, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010291, 400070010164, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010292, 400070010164, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010293, 400070010164, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010294, 400070010165, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010295, 400070010165, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010296, 400070010165, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010297, 400070010165, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010298, 400070010166, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010299, 400070010166, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010300, 400070010166, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010301, 400070010166, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010302, 400070010167, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010303, 400070010167, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010304, 400070010167, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010305, 400070010167, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010306, 400070010168, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010307, 400070010168, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010308, 400070010168, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010309, 400070010168, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010310, 400070010169, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010311, 400070010169, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010312, 400070010169, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010313, 400070010169, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010314, 400070010170, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010315, 400070010170, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010316, 400070010170, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010317, 400070010170, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 9, "RUM" section
(400070010318, 400070010171, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010319, 400070010171, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010320, 400070010171, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010321, 400070010171, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010322, 400070010172, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010323, 400070010172, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010324, 400070010172, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010325, 400070010172, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
(400070010326, 400070010173, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010327, 400070010173, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010328, 400070010173, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010329, 400070010173, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 9, "BRANDY" section
(400070010330, 400070010174, '180ml.', 'fixed', 180, 'ml', 1, TRUE),
(400070010331, 400070010174, '90ml.', 'fixed', 90, 'ml', 2, FALSE),
(400070010332, 400070010174, '60 ml.', 'fixed', 60, 'ml', 3, FALSE),
(400070010333, 400070010174, '30 ml.', 'fixed', 30, 'ml', 4, FALSE),
-- Source: JSON, page 9, "STRONG BEER" section
(400070010334, 400070010175, '750ml.', 'fixed', 750, 'ml', 1, TRUE),
(400070010335, 400070010175, '500ml.', 'fixed', 500, 'ml', 2, FALSE),
(400070010336, 400070010175, '330ml.', 'fixed', 330, 'ml', 3, FALSE),
(400070010337, 400070010176, '750ml.', 'fixed', 750, 'ml', 1, TRUE),
(400070010338, 400070010176, '500ml.', 'fixed', 500, 'ml', 2, FALSE),
(400070010339, 400070010176, '330ml.', 'fixed', 330, 'ml', 3, FALSE),
(400070010340, 400070010177, '750ml.', 'fixed', 750, 'ml', 1, TRUE),
(400070010341, 400070010177, '500ml.', 'fixed', 500, 'ml', 2, FALSE),
(400070010342, 400070010177, '330ml.', 'fixed', 330, 'ml', 3, FALSE),
(400070010343, 400070010178, '750ml.', 'fixed', 750, 'ml', 1, TRUE),
(400070010344, 400070010178, '500ml.', 'fixed', 500, 'ml', 2, FALSE),
(400070010345, 400070010178, '330ml.', 'fixed', 330, 'ml', 3, FALSE),
(400070010346, 400070010179, '750ml.', 'fixed', 750, 'ml', 1, TRUE),
(400070010347, 400070010179, '500ml.', 'fixed', 500, 'ml', 2, FALSE),
(400070010348, 400070010179, '330ml.', 'fixed', 330, 'ml', 3, FALSE),
-- Source: JSON, page 9, "MILD BEER" section
(400070010349, 400070010180, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010350, 400070010181, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010351, 400070010182, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010352, 400070010183, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010353, 400070010184, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010354, 400070010185, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010355, 400070010186, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010356, 400070010187, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
(400070010357, 400070010188, '1 Ltr', 'fixed', NULL, NULL, 1, TRUE),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
(400070010358, 400070010189, 'FULL', 'fixed', NULL, NULL, 1, TRUE),
(400070010359, 400070010189, 'HALF', 'fixed', NULL, NULL, 2, FALSE),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010360, 400070010190, '330ml.', 'fixed', 330, 'ml', 1, TRUE),
(400070010361, 400070010190, '300ml.', 'fixed', 300, 'ml', 2, FALSE),
(400070010362, 400070010190, '500ml.', 'fixed', 500, 'ml', 3, FALSE),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010363, 400070010191, '700ml.', 'fixed', 700, 'ml', 1, TRUE),
(400070010364, 400070010191, '600 ml.', 'fixed', 600, 'ml', 2, FALSE),
(400070010365, 400070010191, '330ml.', 'fixed', 330, 'ml', 3, FALSE),
(400070010366, 400070010191, '300 ml.', 'fixed', 300, 'ml', 4, FALSE),
(400070010367, 400070010191, '200ml.', 'fixed', 200, 'ml', 5, FALSE);

-- ---------------------------------------------------------------------
-- 12. menu_item_price. INR; tax columns NULL (no GST text in the JSON); effective_from = the
--     extraction timestamp (no rate-effective date printed anywhere). A variant with no legible
--     price gets no row at all (see header note 8) - "APS" gets is_market_price = TRUE instead.
-- ---------------------------------------------------------------------
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, verification_status_code, source_id) VALUES
-- Source: JSON, page 2, "INDIAN STARTER" section
(400070010001, 400070010001, 40.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010002, 400070010002, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010003, 400070010003, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010004, 400070010004, 90.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010005, 400070010005, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010006, 400070010006, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010007, 400070010007, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010008, 400070010008, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010009, 400070010009, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010010, 400070010010, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010011, 400070010011, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 2, "INDIAN SOUP" section
(400070010012, 400070010012, 90.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010013, 400070010013, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010014, 400070010014, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 2, "CHINESE VEG SOUP" section
(400070010015, 400070010015, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010016, 400070010016, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010017, 400070010017, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010018, 400070010018, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 2, "CHINESE NON-VEG SOUP" section
(400070010019, 400070010019, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010020, 400070010020, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010021, 400070010021, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010022, 400070010022, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010023, 400070010023, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 3, "CHINESE VEG. STARTER" section
(400070010024, 400070010024, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010025, 400070010025, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010026, 400070010026, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010027, 400070010027, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010028, 400070010028, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010029, 400070010029, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010030, 400070010030, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010031, 400070010031, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010032, 400070010032, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010033, 400070010033, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010034, 400070010034, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010035, 400070010035, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 3, "INDIAN FISH STARTER" section
-- NEEDS_REVIEW price printed as "APS" -> stored as market price (is_market_price = TRUE, price_amount NULL)
(400070010036, 400070010036, NULL, TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400070010),
(400070010037, 400070010037, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010038, 400070010038, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010039, 400070010039, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NEEDS_REVIEW price printed as "APS" -> stored as market price (is_market_price = TRUE, price_amount NULL)
(400070010040, 400070010040, NULL, TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400070010),
-- NEEDS_REVIEW price printed as "APS" -> stored as market price (is_market_price = TRUE, price_amount NULL)
(400070010041, 400070010041, NULL, TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review', 400070010),
-- Source: JSON, page 3, "STARTER (Non-Veg)" section
(400070010042, 400070010042, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010043, 400070010043, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010044, 400070010044, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010045, 400070010045, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010046, 400070010046, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010047, 400070010047, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010048, 400070010048, 40.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010049, 400070010049, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010050, 400070010050, 70.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010051, 400070010051, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 4, "INDIAN VEG" section
(400070010052, 400070010052, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010053, 400070010053, 170.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010054, 400070010054, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010055, 400070010055, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010056, 400070010056, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010057, 400070010057, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010058, 400070010058, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010059, 400070010059, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010060, 400070010060, 220.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010061, 400070010061, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010062, 400070010062, 250.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010063, 400070010063, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010064, 400070010064, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010065, 400070010065, 240.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010066, 400070010066, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010067, 400070010067, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010068, 400070010068, 170.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010069, 400070010069, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010070, 400070010070, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010071, 400070010071, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010072, 400070010072, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010073, 400070010073, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010074, 400070010074, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 4, "RAITA" section
(400070010075, 400070010075, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010076, 400070010076, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010077, 400070010077, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 4, "SALAD" section
(400070010078, 400070010078, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010079, 400070010079, 30.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010080, 400070010080, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010081, 400070010081, 30.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010082, 400070010082, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010083, 400070010083, 30.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010084, 400070010084, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010085, 400070010085, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
(400070010086, 400070010086, 340.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010087, 400070010087, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010088, 400070010088, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010089, 400070010089, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010090, 400070010090, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010091, 400070010091, 170.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010092, 400070010092, 400.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010093, 400070010093, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010094, 400070010094, 400.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010095, 400070010095, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010096, 400070010096, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010097, 400070010097, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010098, 400070010098, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010099, 400070010099, 220.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010100, 400070010100, 250.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010101, 400070010101, 280.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 5, "Utsav Special" section
-- NO PRICE ROW for UTSAV SPECIAL ROGAN HANDI / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for UTSAV SPECIAL CHICKEN / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for UTSAV SPECIAL CHINESE SNACKS / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- Source: JSON, page 6, "CHAPATI" section
(400070010102, 400070010105, 15.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010103, 400070010106, 20.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010104, 400070010107, 20.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010105, 400070010108, 30.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 6, "RICE" section
(400070010106, 400070010109, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010107, 400070010110, 70.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010108, 400070010111, 90.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010109, 400070010112, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010110, 400070010113, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010111, 400070010114, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010112, 400070010115, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010113, 400070010116, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 6, "RICE (Non-Veg)" section
(400070010114, 400070010117, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010115, 400070010118, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010116, 400070010119, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010117, 400070010120, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010118, 400070010121, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010119, 400070010122, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010120, 400070010123, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010121, 400070010124, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010122, 400070010125, 220.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010123, 400070010126, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010124, 400070010127, 250.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010125, 400070010128, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 6, "PAPAD" section
(400070010126, 400070010129, 30.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010127, 400070010130, 20.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010128, 400070010131, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 7, "CHICKEN CHINESE STARTER" section
(400070010129, 400070010132, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010130, 400070010133, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010131, 400070010134, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010132, 400070010135, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010133, 400070010136, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010134, 400070010137, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010135, 400070010138, 230.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for CHICKEN CRISPY / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010136, 400070010140, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for CHICKEN 65 / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010137, 400070010142, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for CHICKEN GARLIC / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010138, 400070010144, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for CHICKEN SCHEZWAN / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010139, 400070010146, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for CHI. CHILLY GINGER GARLIC / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- Source: JSON, page 7, "CHINESE RICE (Veg)" section
(400070010140, 400070010148, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010141, 400070010149, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010142, 400070010150, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010143, 400070010151, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010144, 400070010152, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010145, 400070010153, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010146, 400070010154, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010147, 400070010155, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 7, "CHINESE RICE (Non-Veg)" section
(400070010148, 400070010156, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010149, 400070010157, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010150, 400070010158, 250.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010151, 400070010159, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010152, 400070010160, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010153, 400070010161, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010154, 400070010162, 250.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010155, 400070010163, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 7, "CHINESE NOODLES (Veg)" section
(400070010156, 400070010164, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010157, 400070010165, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010158, 400070010166, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 7, "CHINESE NOODLES (Non-Veg)" section
(400070010159, 400070010167, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010160, 400070010168, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010161, 400070010169, 170.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 8, "PREMIUM WHISKEY" section
(400070010162, 400070010170, 430.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010163, 400070010171, 230.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010164, 400070010172, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010165, 400070010173, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for OAK SMITH GOLD / 180ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for OAK SMITH GOLD / 90ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for OAK SMITH GOLD / 60 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for OAK SMITH GOLD / 30 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010166, 400070010178, 1110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010167, 400070010179, 560.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010168, 400070010180, 390.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010169, 400070010181, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010170, 400070010182, 1000.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010171, 400070010183, 510.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010172, 400070010184, 350.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010173, 400070010185, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010174, 400070010186, 520.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010175, 400070010187, 280.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010176, 400070010188, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010177, 400070010189, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010178, 400070010190, 490.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010179, 400070010191, 260.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010180, 400070010192, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010181, 400070010193, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010182, 400070010194, 340.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010183, 400070010195, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010184, 400070010196, 125.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010185, 400070010197, 85.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010186, 400070010198, 330.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010187, 400070010199, 175.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010188, 400070010200, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010189, 400070010201, 70.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 8, "DELUXE WHISKEY" section
(400070010190, 400070010202, 240.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010191, 400070010203, 125.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010192, 400070010204, 90.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010193, 400070010205, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010194, 400070010206, 260.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010195, 400070010207, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010196, 400070010208, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010197, 400070010209, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010198, 400070010210, 340.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010199, 400070010211, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010200, 400070010212, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010201, 400070010213, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010202, 400070010214, 300.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010203, 400070010215, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010204, 400070010216, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010205, 400070010217, 75.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 8, "REGULAR WHISKY" section
(400070010206, 400070010218, 300.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010207, 400070010219, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010208, 400070010220, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010209, 400070010221, 75.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010210, 400070010222, 290.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010211, 400070010223, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010212, 400070010224, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010213, 400070010225, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010214, 400070010226, 290.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010215, 400070010227, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010216, 400070010228, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010217, 400070010229, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010218, 400070010230, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010219, 400070010231, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010220, 400070010232, 70.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010221, 400070010233, 40.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010222, 400070010234, 280.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010223, 400070010235, 150.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010224, 400070010236, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010225, 400070010237, 55.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010226, 400070010238, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010227, 400070010239, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010228, 400070010240, 70.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010229, 400070010241, 40.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 8, "VODKA" section
(400070010230, 400070010242, 590.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010231, 400070010243, 305.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010232, 400070010244, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010233, 400070010245, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010234, 400070010246, 570.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010235, 400070010247, 290.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010236, 400070010248, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010237, 400070010249, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010238, 400070010250, 330.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010239, 400070010251, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010240, 400070010252, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010241, 400070010253, 75.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010242, 400070010254, 330.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010243, 400070010255, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010244, 400070010256, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010245, 400070010257, 75.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010246, 400070010258, 300.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010247, 400070010259, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010248, 400070010260, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010249, 400070010261, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010250, 400070010262, 260.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010251, 400070010263, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010252, 400070010264, 90.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010253, 400070010265, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010254, 400070010266, 370.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010255, 400070010267, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010256, 400070010268, 125.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010257, 400070010269, 75.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 9, "VODKA" section
(400070010258, 400070010270, 965.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010259, 400070010271, 490.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010260, 400070010272, 330.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010261, 400070010273, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010262, 400070010274, 1040.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010263, 400070010275, 530.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010264, 400070010276, 360.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010265, 400070010277, 190.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010266, 400070010278, 270.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010267, 400070010279, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010268, 400070010280, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010269, 400070010281, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010270, 400070010282, 440.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010271, 400070010283, 230.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010272, 400070010284, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010273, 400070010285, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010274, 400070010286, 320.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010275, 400070010287, 170.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010276, 400070010288, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010277, 400070010289, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010278, 400070010290, 590.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010279, 400070010291, 300.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010280, 400070010292, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010281, 400070010293, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010282, 400070010294, 300.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010283, 400070010295, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010284, 400070010296, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010285, 400070010297, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010286, 400070010298, 250.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010287, 400070010299, 130.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010288, 400070010300, 100.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010289, 400070010301, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010290, 400070010302, 920.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010291, 400070010303, 470.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010292, 400070010304, 320.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010293, 400070010305, 170.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010294, 400070010306, 1740.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010295, 400070010307, 880.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010296, 400070010308, 600.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010297, 400070010309, 310.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010298, 400070010310, 900.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010299, 400070010311, 460.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010300, 400070010312, 310.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010301, 400070010313, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010302, 400070010314, 990.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010303, 400070010315, 500.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010304, 400070010316, 340.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010305, 400070010317, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 9, "RUM" section
(400070010306, 400070010318, 590.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010307, 400070010319, 305.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010308, 400070010320, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010309, 400070010321, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010310, 400070010322, 300.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010311, 400070010323, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010312, 400070010324, 110.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010313, 400070010325, 75.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010314, 400070010326, 230.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010315, 400070010327, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010316, 400070010328, 80.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010317, 400070010329, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 9, "BRANDY" section
(400070010318, 400070010330, 270.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010319, 400070010331, 140.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010320, 400070010332, 90.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010321, 400070010333, 60.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 9, "STRONG BEER" section
(400070010322, 400070010334, 270.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010323, 400070010335, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010324, 400070010336, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010325, 400070010337, 230.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010326, 400070010338, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010327, 400070010339, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010328, 400070010340, 240.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010329, 400070010341, 180.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for LONDON PILSNER / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010330, 400070010343, 350.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for CARLSBERA ELEPHANT / 500ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for CARLSBERA ELEPHANT / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
(400070010331, 400070010346, 350.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- NO PRICE ROW for BUDWISER MAGNIUM / 500ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for BUDWISER MAGNIUM / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- Source: JSON, page 9, "MILD BEER" section
(400070010332, 400070010349, 320.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010333, 400070010350, 320.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010334, 400070010351, 270.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010335, 400070010352, 230.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010336, 400070010353, 320.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010337, 400070010354, 200.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010338, 400070010355, 160.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
-- Source: JSON, page 9, "COLD DRINKS" section
-- NO PRICE ROW for FRESH LIME SODA / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for BISLERI / 1 Ltr: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
(400070010339, 400070010358, 210.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010),
(400070010340, 400070010359, 120.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400070010);
-- Source: JSON, page 9, "OTHER BEVERAGES" section
-- NO PRICE ROW for SODA / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for SODA / 300ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for SODA / 500ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- Source: JSON, page 9, "COLD DRINKS" section
-- NO PRICE ROW for COLD DRINKS / 700ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for COLD DRINKS / 600 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for COLD DRINKS / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for COLD DRINKS / 300 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- NO PRICE ROW for COLD DRINKS / 200ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant

-- ---------------------------------------------------------------------
-- 13. menu_item_price_source: price extraction confidence (composite PK; extraction_batch_id
--     looked up as in step 10)
-- ---------------------------------------------------------------------
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence) VALUES
(400070010001, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010002, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010003, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010004, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010005, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010006, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010007, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010008, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010009, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010010, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010011, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010012, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010013, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010014, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010015, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010016, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010017, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010018, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010019, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010020, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010021, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010022, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010023, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010024, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010025, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010026, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010027, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010028, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010029, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010030, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010031, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010032, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010033, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010034, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010035, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010036, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.60),
(400070010037, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010038, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010039, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010040, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.60),
(400070010041, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.60),
(400070010042, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010043, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010044, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010045, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010046, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010047, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010048, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010049, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010050, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010051, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010052, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010053, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010054, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010055, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010056, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010057, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010058, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010059, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010060, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010061, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010062, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010063, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010064, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010065, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010066, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010067, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010068, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010069, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010070, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010071, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010072, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010073, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010074, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010075, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010076, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010077, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010078, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010079, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010080, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010081, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010082, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010083, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010084, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010085, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010086, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010087, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010088, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010089, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010090, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010091, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010092, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010093, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010094, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010095, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010096, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010097, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010098, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010099, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010100, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010101, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010102, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010103, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010104, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010105, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010106, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010107, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010108, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010109, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010110, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010111, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010112, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010113, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010114, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010115, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010116, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010117, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010118, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010119, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010120, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010121, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010122, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010123, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010124, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010125, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010126, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010127, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010128, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010129, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010130, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010131, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010132, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010133, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010134, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010135, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010136, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010137, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010138, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010139, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010140, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010141, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010142, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010143, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010144, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010145, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010146, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010147, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010148, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010149, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010150, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010151, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010152, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010153, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010154, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010155, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010156, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010157, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010158, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010159, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010160, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010161, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010162, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010163, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010164, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010165, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010166, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010167, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010168, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010169, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010170, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010171, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010172, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010173, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010174, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010175, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010176, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010177, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010178, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010179, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010180, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010181, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010182, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010183, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010184, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010185, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010186, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010187, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010188, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010189, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010190, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010191, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010192, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010193, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010194, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010195, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010196, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010197, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010198, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010199, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010200, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010201, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010202, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010203, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010204, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010205, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010206, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010207, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010208, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010209, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010210, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010211, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010212, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010213, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010214, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010215, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010216, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010217, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010218, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010219, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010220, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010221, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010222, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010223, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010224, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010225, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010226, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010227, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010228, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010229, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010230, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010231, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010232, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010233, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010234, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010235, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010236, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010237, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010238, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010239, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010240, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010241, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010242, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010243, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010244, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010245, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010246, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010247, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010248, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010249, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010250, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010251, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010252, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010253, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010254, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010255, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010256, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010257, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010258, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010259, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010260, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010261, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010262, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010263, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010264, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010265, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010266, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010267, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010268, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010269, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010270, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010271, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010272, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010273, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010274, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010275, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010276, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010277, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010278, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010279, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010280, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010281, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010282, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010283, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010284, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010285, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010286, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010287, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010288, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010289, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010290, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010291, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010292, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010293, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010294, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010295, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010296, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010297, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010298, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010299, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010300, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010301, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010302, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010303, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010304, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010305, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010306, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010307, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010308, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010309, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010310, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010311, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010312, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010313, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010314, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010315, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010316, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010317, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010318, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010319, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010320, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010321, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010322, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010323, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010324, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010325, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010326, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010327, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010328, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010329, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010330, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010331, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010332, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010333, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010334, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010335, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010336, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010337, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010338, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010339, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95),
(400070010340, 400070010, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400070010 AND source_id = 400070010), 0.95);

-- ---------------------------------------------------------------------
-- 14. bar_menu_item: 1:1 extension of menu_item for every item on the two bar pages.
--     bar_product_id is NULL for the non-alcoholic mixer lines (soda/cold drinks/Red Bull).
-- ---------------------------------------------------------------------
INSERT INTO bar_menu_item (menu_item_id, bar_product_id, bar_item_type_code) VALUES
-- Source: JSON, page 8, "PREMIUM WHISKEY" section
(400070010134, (SELECT bar_product_id FROM bar_product WHERE product_name = 'OAK SMITH SILVER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010135, (SELECT bar_product_id FROM bar_product WHERE product_name = 'OAK SMITH GOLD' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010136, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BLACK DOG' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010137, (SELECT bar_product_id FROM bar_product WHERE product_name = 'TEACHERS' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010138, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BLENDER''S PRIDE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010139, (SELECT bar_product_id FROM bar_product WHERE product_name = 'SIGNATURE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010140, (SELECT bar_product_id FROM bar_product WHERE product_name = 'ROYAL CHALLENGE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010141, (SELECT bar_product_id FROM bar_product WHERE product_name = 'RSD BARAL' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 8, "DELUXE WHISKEY" section
(400070010142, (SELECT bar_product_id FROM bar_product WHERE product_name = 'OC BLUE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010143, (SELECT bar_product_id FROM bar_product WHERE product_name = 'MCD LUXURY' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010144, (SELECT bar_product_id FROM bar_product WHERE product_name = 'ROYAL STAG' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010145, (SELECT bar_product_id FROM bar_product WHERE product_name = 'McDOWELL''S NO. 1' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 8, "REGULAR WHISKY" section
(400070010146, (SELECT bar_product_id FROM bar_product WHERE product_name = 'IMPERIAL BLUE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010147, (SELECT bar_product_id FROM bar_product WHERE product_name = 'DSP BLACK' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010148, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BAGPIPER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010149, (SELECT bar_product_id FROM bar_product WHERE product_name = 'DIRECTOR''S SPECIAL' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010150, (SELECT bar_product_id FROM bar_product WHERE product_name = 'OFFICER''S CHOICE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010151, (SELECT bar_product_id FROM bar_product WHERE product_name = 'HAYWARD' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 8, "VODKA" section
(400070010152, (SELECT bar_product_id FROM bar_product WHERE product_name = 'SMIROFF FLEVER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010153, (SELECT bar_product_id FROM bar_product WHERE product_name = 'SIMIRONOFF' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010154, (SELECT bar_product_id FROM bar_product WHERE product_name = 'ROMANOV FLAVOR' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010155, (SELECT bar_product_id FROM bar_product WHERE product_name = 'ROMANOV' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010156, (SELECT bar_product_id FROM bar_product WHERE product_name = 'MAGIC MOVEMENT' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010157, (SELECT bar_product_id FROM bar_product WHERE product_name = 'WHITE MICHIEF' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010158, (SELECT bar_product_id FROM bar_product WHERE product_name = 'MAGIC MOVEMENT APPLE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 9, "VODKA" section
(400070010159, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BALLONTIES' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010160, (SELECT bar_product_id FROM bar_product WHERE product_name = 'ABSOLUTE VODKA' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010161, (SELECT bar_product_id FROM bar_product WHERE product_name = 'STERLING RESERVE BT' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010162, (SELECT bar_product_id FROM bar_product WHERE product_name = 'AMERICAN PRIDE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010163, (SELECT bar_product_id FROM bar_product WHERE product_name = 'GRAND MASTER VODKA' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010164, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BACARDI LEMON WHITE RUM' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010165, (SELECT bar_product_id FROM bar_product WHERE product_name = 'ROYAL GREEN WHISKY' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010166, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BLACK BACARDI' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010167, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BLACK & WHITE' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010168, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BLACK LABEL' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010169, (SELECT bar_product_id FROM bar_product WHERE product_name = 'VAT 69' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010170, (SELECT bar_product_id FROM bar_product WHERE product_name = '100 PIPER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 9, "RUM" section
(400070010171, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BACARDI WHITE RUM LEMON' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010172, (SELECT bar_product_id FROM bar_product WHERE product_name = 'OLD MONK RUM' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010173, (SELECT bar_product_id FROM bar_product WHERE product_name = 'MCD No. 1 CELEBERATION' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 9, "BRANDY" section
(400070010174, (SELECT bar_product_id FROM bar_product WHERE product_name = 'DR. BRANDY' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 9, "STRONG BEER" section
(400070010175, (SELECT bar_product_id FROM bar_product WHERE product_name = 'TUBROG STRONG' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010176, (SELECT bar_product_id FROM bar_product WHERE product_name = 'HAYWARD 2000' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010177, (SELECT bar_product_id FROM bar_product WHERE product_name = 'LONDON PILSNER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010178, (SELECT bar_product_id FROM bar_product WHERE product_name = 'CARLSBERA ELEPHANT' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010179, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BUDWISER MAGNIUM' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 9, "MILD BEER" section
(400070010180, (SELECT bar_product_id FROM bar_product WHERE product_name = 'CARLIBERG' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010181, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BUDWISER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010182, (SELECT bar_product_id FROM bar_product WHERE product_name = 'KINGFISHER MILD' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010183, (SELECT bar_product_id FROM bar_product WHERE product_name = 'LONDON PILSNER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010184, (SELECT bar_product_id FROM bar_product WHERE product_name = 'KF ULTRA' ORDER BY bar_product_id LIMIT 1), 'spirit'),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010185, (SELECT bar_product_id FROM bar_product WHERE product_name = 'BACARDI BREEZER' ORDER BY bar_product_id LIMIT 1), 'spirit'),
(400070010186, NULL, 'mixer'),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010187, NULL, 'mixer'),
(400070010188, NULL, 'mixer'),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010190, NULL, 'mixer'),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010191, NULL, 'mixer');

-- ---------------------------------------------------------------------
-- 15. menu_board_item; display_sequence = document order
-- ---------------------------------------------------------------------
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence) VALUES
-- Source: JSON, page 2, "INDIAN STARTER" section
(400070010001, 400070010, 400070010001, 400070010001, 400070010001, 1),
(400070010002, 400070010, 400070010001, 400070010002, 400070010001, 2),
(400070010003, 400070010, 400070010001, 400070010003, 400070010001, 3),
(400070010004, 400070010, 400070010001, 400070010004, 400070010001, 4),
(400070010005, 400070010, 400070010001, 400070010005, 400070010001, 5),
(400070010006, 400070010, 400070010001, 400070010006, 400070010001, 6),
(400070010007, 400070010, 400070010001, 400070010007, 400070010001, 7),
(400070010008, 400070010, 400070010001, 400070010008, 400070010001, 8),
(400070010009, 400070010, 400070010001, 400070010009, 400070010001, 9),
(400070010010, 400070010, 400070010001, 400070010010, 400070010001, 10),
(400070010011, 400070010, 400070010001, 400070010011, 400070010001, 11),
-- Source: JSON, page 2, "INDIAN SOUP" section
(400070010012, 400070010, 400070010001, 400070010012, 400070010002, 12),
(400070010013, 400070010, 400070010001, 400070010013, 400070010002, 13),
(400070010014, 400070010, 400070010001, 400070010014, 400070010002, 14),
-- Source: JSON, page 2, "CHINESE VEG SOUP" section
(400070010015, 400070010, 400070010001, 400070010015, 400070010003, 15),
(400070010016, 400070010, 400070010001, 400070010016, 400070010003, 16),
(400070010017, 400070010, 400070010001, 400070010017, 400070010003, 17),
(400070010018, 400070010, 400070010001, 400070010018, 400070010003, 18),
-- Source: JSON, page 2, "CHINESE NON-VEG SOUP" section
(400070010019, 400070010, 400070010001, 400070010019, 400070010004, 19),
(400070010020, 400070010, 400070010001, 400070010020, 400070010004, 20),
(400070010021, 400070010, 400070010001, 400070010021, 400070010004, 21),
(400070010022, 400070010, 400070010001, 400070010022, 400070010004, 22),
(400070010023, 400070010, 400070010001, 400070010023, 400070010004, 23),
-- Source: JSON, page 3, "CHINESE VEG. STARTER" section
(400070010024, 400070010, 400070010001, 400070010024, 400070010005, 24),
(400070010025, 400070010, 400070010001, 400070010025, 400070010005, 25),
(400070010026, 400070010, 400070010001, 400070010026, 400070010005, 26),
(400070010027, 400070010, 400070010001, 400070010027, 400070010005, 27),
(400070010028, 400070010, 400070010001, 400070010028, 400070010005, 28),
(400070010029, 400070010, 400070010001, 400070010029, 400070010005, 29),
-- Source: JSON, page 3, "INDIAN FISH STARTER" section
(400070010030, 400070010, 400070010001, 400070010030, 400070010006, 30),
(400070010031, 400070010, 400070010001, 400070010031, 400070010006, 31),
(400070010032, 400070010, 400070010001, 400070010032, 400070010006, 32),
(400070010033, 400070010, 400070010001, 400070010033, 400070010006, 33),
(400070010034, 400070010, 400070010001, 400070010034, 400070010006, 34),
(400070010035, 400070010, 400070010001, 400070010035, 400070010006, 35),
-- Source: JSON, page 3, "STARTER (Non-Veg)" section
(400070010036, 400070010, 400070010001, 400070010036, 400070010007, 36),
(400070010037, 400070010, 400070010001, 400070010037, 400070010007, 37),
(400070010038, 400070010, 400070010001, 400070010038, 400070010007, 38),
(400070010039, 400070010, 400070010001, 400070010039, 400070010007, 39),
(400070010040, 400070010, 400070010001, 400070010040, 400070010007, 40),
(400070010041, 400070010, 400070010001, 400070010041, 400070010007, 41),
(400070010042, 400070010, 400070010001, 400070010042, 400070010007, 42),
(400070010043, 400070010, 400070010001, 400070010043, 400070010007, 43),
(400070010044, 400070010, 400070010001, 400070010044, 400070010007, 44),
(400070010045, 400070010, 400070010001, 400070010045, 400070010007, 45),
-- Source: JSON, page 4, "INDIAN VEG" section
(400070010046, 400070010, 400070010001, 400070010046, 400070010008, 46),
(400070010047, 400070010, 400070010001, 400070010047, 400070010008, 47),
(400070010048, 400070010, 400070010001, 400070010048, 400070010008, 48),
(400070010049, 400070010, 400070010001, 400070010049, 400070010008, 49),
(400070010050, 400070010, 400070010001, 400070010050, 400070010008, 50),
(400070010051, 400070010, 400070010001, 400070010051, 400070010008, 51),
(400070010052, 400070010, 400070010001, 400070010052, 400070010008, 52),
(400070010053, 400070010, 400070010001, 400070010053, 400070010008, 53),
(400070010054, 400070010, 400070010001, 400070010054, 400070010008, 54),
(400070010055, 400070010, 400070010001, 400070010055, 400070010008, 55),
(400070010056, 400070010, 400070010001, 400070010056, 400070010008, 56),
(400070010057, 400070010, 400070010001, 400070010057, 400070010008, 57),
(400070010058, 400070010, 400070010001, 400070010058, 400070010008, 58),
(400070010059, 400070010, 400070010001, 400070010059, 400070010008, 59),
(400070010060, 400070010, 400070010001, 400070010060, 400070010008, 60),
(400070010061, 400070010, 400070010001, 400070010061, 400070010008, 61),
(400070010062, 400070010, 400070010001, 400070010062, 400070010008, 62),
(400070010063, 400070010, 400070010001, 400070010063, 400070010008, 63),
(400070010064, 400070010, 400070010001, 400070010064, 400070010008, 64),
(400070010065, 400070010, 400070010001, 400070010065, 400070010008, 65),
(400070010066, 400070010, 400070010001, 400070010066, 400070010008, 66),
(400070010067, 400070010, 400070010001, 400070010067, 400070010008, 67),
(400070010068, 400070010, 400070010001, 400070010068, 400070010008, 68),
-- Source: JSON, page 4, "RAITA" section
(400070010069, 400070010, 400070010001, 400070010069, 400070010009, 69),
(400070010070, 400070010, 400070010001, 400070010070, 400070010009, 70),
(400070010071, 400070010, 400070010001, 400070010071, 400070010009, 71),
-- Source: JSON, page 4, "SALAD" section
(400070010072, 400070010, 400070010001, 400070010072, 400070010010, 72),
(400070010073, 400070010, 400070010001, 400070010073, 400070010010, 73),
(400070010074, 400070010, 400070010001, 400070010074, 400070010010, 74),
(400070010075, 400070010, 400070010001, 400070010075, 400070010010, 75),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
(400070010076, 400070010, 400070010001, 400070010076, 400070010011, 76),
(400070010077, 400070010, 400070010001, 400070010077, 400070010011, 77),
(400070010078, 400070010, 400070010001, 400070010078, 400070010011, 78),
(400070010079, 400070010, 400070010001, 400070010079, 400070010011, 79),
(400070010080, 400070010, 400070010001, 400070010080, 400070010011, 80),
(400070010081, 400070010, 400070010001, 400070010081, 400070010011, 81),
(400070010082, 400070010, 400070010001, 400070010082, 400070010011, 82),
(400070010083, 400070010, 400070010001, 400070010083, 400070010011, 83),
(400070010084, 400070010, 400070010001, 400070010084, 400070010011, 84),
(400070010085, 400070010, 400070010001, 400070010085, 400070010011, 85),
(400070010086, 400070010, 400070010001, 400070010086, 400070010011, 86),
(400070010087, 400070010, 400070010001, 400070010087, 400070010011, 87),
(400070010088, 400070010, 400070010001, 400070010088, 400070010011, 88),
-- Source: JSON, page 5, "Utsav Special" section
(400070010089, 400070010, 400070010001, 400070010089, 400070010012, 89),
(400070010090, 400070010, 400070010001, 400070010090, 400070010012, 90),
(400070010091, 400070010, 400070010001, 400070010091, 400070010012, 91),
-- Source: JSON, page 6, "CHAPATI" section
(400070010092, 400070010, 400070010001, 400070010092, 400070010013, 92),
(400070010093, 400070010, 400070010001, 400070010093, 400070010013, 93),
(400070010094, 400070010, 400070010001, 400070010094, 400070010013, 94),
(400070010095, 400070010, 400070010001, 400070010095, 400070010013, 95),
-- Source: JSON, page 6, "RICE" section
(400070010096, 400070010, 400070010001, 400070010096, 400070010014, 96),
(400070010097, 400070010, 400070010001, 400070010097, 400070010014, 97),
(400070010098, 400070010, 400070010001, 400070010098, 400070010014, 98),
(400070010099, 400070010, 400070010001, 400070010099, 400070010014, 99),
(400070010100, 400070010, 400070010001, 400070010100, 400070010014, 100),
(400070010101, 400070010, 400070010001, 400070010101, 400070010014, 101),
(400070010102, 400070010, 400070010001, 400070010102, 400070010014, 102),
-- Source: JSON, page 6, "RICE (Non-Veg)" section
(400070010103, 400070010, 400070010001, 400070010103, 400070010015, 103),
(400070010104, 400070010, 400070010001, 400070010104, 400070010015, 104),
(400070010105, 400070010, 400070010001, 400070010105, 400070010015, 105),
(400070010106, 400070010, 400070010001, 400070010106, 400070010015, 106),
(400070010107, 400070010, 400070010001, 400070010107, 400070010015, 107),
(400070010108, 400070010, 400070010001, 400070010108, 400070010015, 108),
-- Source: JSON, page 6, "PAPAD" section
(400070010109, 400070010, 400070010001, 400070010109, 400070010016, 109),
(400070010110, 400070010, 400070010001, 400070010110, 400070010016, 110),
(400070010111, 400070010, 400070010001, 400070010111, 400070010016, 111),
-- Source: JSON, page 7, "CHICKEN CHINESE STARTER" section
(400070010112, 400070010, 400070010001, 400070010112, 400070010017, 112),
(400070010113, 400070010, 400070010001, 400070010113, 400070010017, 113),
(400070010114, 400070010, 400070010001, 400070010114, 400070010017, 114),
(400070010115, 400070010, 400070010001, 400070010115, 400070010017, 115),
(400070010116, 400070010, 400070010001, 400070010116, 400070010017, 116),
(400070010117, 400070010, 400070010001, 400070010117, 400070010017, 117),
(400070010118, 400070010, 400070010001, 400070010118, 400070010017, 118),
(400070010119, 400070010, 400070010001, 400070010119, 400070010017, 119),
-- Source: JSON, page 7, "CHINESE RICE (Veg)" section
(400070010120, 400070010, 400070010001, 400070010120, 400070010018, 120),
(400070010121, 400070010, 400070010001, 400070010121, 400070010018, 121),
(400070010122, 400070010, 400070010001, 400070010122, 400070010018, 122),
(400070010123, 400070010, 400070010001, 400070010123, 400070010018, 123),
-- Source: JSON, page 7, "CHINESE RICE (Non-Veg)" section
(400070010124, 400070010, 400070010001, 400070010124, 400070010019, 124),
(400070010125, 400070010, 400070010001, 400070010125, 400070010019, 125),
(400070010126, 400070010, 400070010001, 400070010126, 400070010019, 126),
(400070010127, 400070010, 400070010001, 400070010127, 400070010019, 127),
-- Source: JSON, page 7, "CHINESE NOODLES (Veg)" section
(400070010128, 400070010, 400070010001, 400070010128, 400070010020, 128),
(400070010129, 400070010, 400070010001, 400070010129, 400070010020, 129),
(400070010130, 400070010, 400070010001, 400070010130, 400070010020, 130),
-- Source: JSON, page 7, "CHINESE NOODLES (Non-Veg)" section
(400070010131, 400070010, 400070010001, 400070010131, 400070010021, 131),
(400070010132, 400070010, 400070010001, 400070010132, 400070010021, 132),
(400070010133, 400070010, 400070010001, 400070010133, 400070010021, 133),
-- Source: JSON, page 8, "PREMIUM WHISKEY" section
(400070010134, 400070010, 400070010001, 400070010134, 400070010022, 134),
(400070010135, 400070010, 400070010001, 400070010135, 400070010022, 135),
(400070010136, 400070010, 400070010001, 400070010136, 400070010022, 136),
(400070010137, 400070010, 400070010001, 400070010137, 400070010022, 137),
(400070010138, 400070010, 400070010001, 400070010138, 400070010022, 138),
(400070010139, 400070010, 400070010001, 400070010139, 400070010022, 139),
(400070010140, 400070010, 400070010001, 400070010140, 400070010022, 140),
(400070010141, 400070010, 400070010001, 400070010141, 400070010022, 141),
-- Source: JSON, page 8, "DELUXE WHISKEY" section
(400070010142, 400070010, 400070010001, 400070010142, 400070010023, 142),
(400070010143, 400070010, 400070010001, 400070010143, 400070010023, 143),
(400070010144, 400070010, 400070010001, 400070010144, 400070010023, 144),
(400070010145, 400070010, 400070010001, 400070010145, 400070010023, 145),
-- Source: JSON, page 8, "REGULAR WHISKY" section
(400070010146, 400070010, 400070010001, 400070010146, 400070010024, 146),
(400070010147, 400070010, 400070010001, 400070010147, 400070010024, 147),
(400070010148, 400070010, 400070010001, 400070010148, 400070010024, 148),
(400070010149, 400070010, 400070010001, 400070010149, 400070010024, 149),
(400070010150, 400070010, 400070010001, 400070010150, 400070010024, 150),
(400070010151, 400070010, 400070010001, 400070010151, 400070010024, 151),
-- Source: JSON, page 8, "VODKA" section
(400070010152, 400070010, 400070010001, 400070010152, 400070010025, 152),
(400070010153, 400070010, 400070010001, 400070010153, 400070010025, 153),
(400070010154, 400070010, 400070010001, 400070010154, 400070010025, 154),
(400070010155, 400070010, 400070010001, 400070010155, 400070010025, 155),
(400070010156, 400070010, 400070010001, 400070010156, 400070010025, 156),
(400070010157, 400070010, 400070010001, 400070010157, 400070010025, 157),
(400070010158, 400070010, 400070010001, 400070010158, 400070010025, 158),
-- Source: JSON, page 9, "VODKA" section
(400070010159, 400070010, 400070010001, 400070010159, 400070010026, 159),
(400070010160, 400070010, 400070010001, 400070010160, 400070010026, 160),
(400070010161, 400070010, 400070010001, 400070010161, 400070010026, 161),
(400070010162, 400070010, 400070010001, 400070010162, 400070010026, 162),
(400070010163, 400070010, 400070010001, 400070010163, 400070010026, 163),
(400070010164, 400070010, 400070010001, 400070010164, 400070010026, 164),
(400070010165, 400070010, 400070010001, 400070010165, 400070010026, 165),
(400070010166, 400070010, 400070010001, 400070010166, 400070010026, 166),
(400070010167, 400070010, 400070010001, 400070010167, 400070010026, 167),
(400070010168, 400070010, 400070010001, 400070010168, 400070010026, 168),
(400070010169, 400070010, 400070010001, 400070010169, 400070010026, 169),
(400070010170, 400070010, 400070010001, 400070010170, 400070010026, 170),
-- Source: JSON, page 9, "RUM" section
(400070010171, 400070010, 400070010001, 400070010171, 400070010027, 171),
(400070010172, 400070010, 400070010001, 400070010172, 400070010027, 172),
(400070010173, 400070010, 400070010001, 400070010173, 400070010027, 173),
-- Source: JSON, page 9, "BRANDY" section
(400070010174, 400070010, 400070010001, 400070010174, 400070010028, 174),
-- Source: JSON, page 9, "STRONG BEER" section
(400070010175, 400070010, 400070010001, 400070010175, 400070010029, 175),
(400070010176, 400070010, 400070010001, 400070010176, 400070010029, 176),
(400070010177, 400070010, 400070010001, 400070010177, 400070010029, 177),
(400070010178, 400070010, 400070010001, 400070010178, 400070010029, 178),
(400070010179, 400070010, 400070010001, 400070010179, 400070010029, 179),
-- Source: JSON, page 9, "MILD BEER" section
(400070010180, 400070010, 400070010001, 400070010180, 400070010030, 180),
(400070010181, 400070010, 400070010001, 400070010181, 400070010030, 181),
(400070010182, 400070010, 400070010001, 400070010182, 400070010030, 182),
(400070010183, 400070010, 400070010001, 400070010183, 400070010030, 183),
(400070010184, 400070010, 400070010001, 400070010184, 400070010030, 184),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010185, 400070010, 400070010001, 400070010185, 400070010031, 185),
(400070010186, 400070010, 400070010001, 400070010186, 400070010031, 186),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010187, 400070010, 400070010001, 400070010187, 400070010032, 187),
(400070010188, 400070010, 400070010001, 400070010188, 400070010032, 188),
-- Source: JSON, page 5, "CURRY (Non-Veg)" section
(400070010189, 400070010, 400070010001, 400070010189, 400070010011, 189),
-- Source: JSON, page 9, "OTHER BEVERAGES" section
(400070010190, 400070010, 400070010001, 400070010190, 400070010031, 190),
-- Source: JSON, page 9, "COLD DRINKS" section
(400070010191, 400070010, 400070010001, 400070010191, 400070010032, 191);

-- ---------------------------------------------------------------------
-- 16. POST-LOAD CHECK (raises -> whole transaction rolls back)
-- ---------------------------------------------------------------------
DO $post$
DECLARE
    n_cat bigint; n_item bigint; n_var bigint; n_price bigint;
    n_bc bigint; n_bi bigint; n_bar bigint;
BEGIN
    SELECT count(*) INTO n_cat FROM menu_category WHERE restaurant_id = 400070010;
    SELECT count(*) INTO n_item FROM menu_item WHERE restaurant_id = 400070010;
    SELECT count(*) INTO n_var FROM menu_item_variant v
      JOIN menu_item i ON i.menu_item_id = v.menu_item_id WHERE i.restaurant_id = 400070010;
    SELECT count(*) INTO n_price FROM menu_item_price p
      JOIN menu_item_variant v ON v.variant_id = p.variant_id
      JOIN menu_item i ON i.menu_item_id = v.menu_item_id WHERE i.restaurant_id = 400070010;
    SELECT count(*) INTO n_bc FROM menu_board_category WHERE restaurant_id = 400070010;
    SELECT count(*) INTO n_bi FROM menu_board_item WHERE restaurant_id = 400070010;
    SELECT count(*) INTO n_bar FROM bar_menu_item b
      JOIN menu_item i ON i.menu_item_id = b.menu_item_id WHERE i.restaurant_id = 400070010;

    IF n_cat <> 32 OR n_item <> 191 OR n_var <> 367 OR n_price <> 340
       OR n_bc <> 32 OR n_bi <> 191 OR n_bar <> 57 THEN
        RAISE EXCEPTION 'Utsav load check failed: categories=%, items=%, variants=%, prices=%, board_categories=%, board_items=%, bar_items=%',
            n_cat, n_item, n_var, n_price, n_bc, n_bi, n_bar;
    END IF;

    IF EXISTS (SELECT 1 FROM menu_item i
                WHERE i.restaurant_id = 400070010
                  AND NOT EXISTS (SELECT 1 FROM menu_item_variant v WHERE v.menu_item_id = i.menu_item_id)) THEN
        RAISE EXCEPTION 'Utsav load check failed: a menu_item has no variant';
    END IF;

    RAISE NOTICE 'Utsav Bar & Restaurant loaded: % categories, % items, % variants, % prices, % bar items', n_cat, n_item, n_var, n_price, n_bar;
END
$post$;

COMMIT;

-- =====================================================================
-- REVIEW BLOCK 1 - rows with verification_status_code = 'needs_review' or confidence < 0.8
-- =====================================================================
-- menu_item_price 400070010036  SURMAI TAWA FRY / Regular  (confidence 0.60): price printed as "APS" -> stored as market price (is_market_price = TRUE, price_amount NULL)
-- menu_item_price 400070010040  POMFRET TAWA / Regular  (confidence 0.60): price printed as "APS" -> stored as market price (is_market_price = TRUE, price_amount NULL)
-- menu_item_price 400070010041  RAWAS TAWA / Regular  (confidence 0.60): price printed as "APS" -> stored as market price (is_market_price = TRUE, price_amount NULL)
-- menu_item 400070010067  DAL MAKHANI  [INDIAN VEG]: same printed name also appears under RICE (a different section) -> canonical_dish_id left NULL so two possibly-different products are not merged
-- (no price row)  UTSAV SPECIAL ROGAN HANDI / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  UTSAV SPECIAL CHICKEN / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  UTSAV SPECIAL CHINESE SNACKS / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- menu_item 400070010102  DAL MAKHANI  [RICE]: same printed name also appears under INDIAN VEG (a different section) -> canonical_dish_id left NULL so two possibly-different products are not merged
-- (no price row)  CHICKEN CRISPY / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  CHICKEN 65 / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  CHICKEN GARLIC / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  CHICKEN SCHEZWAN / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  CHI. CHILLY GINGER GARLIC / HALF: price printed as "--" (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- menu_item 400070010125  CHI. SCHZ. TRIPPLE RICE  [CHINESE RICE (Non-Veg)]: duplicate line in the source JSON - "CHI. SCHZ. TRIPPLE RICE" appears 2 times in category "CHINESE RICE (Non-Veg)" with no distinguishing text; kept as separate menu_item rows, not merged
-- menu_item 400070010127  CHI. SCHZ. TRIPPLE RICE  [CHINESE RICE (Non-Veg)]: duplicate line in the source JSON - "CHI. SCHZ. TRIPPLE RICE" appears 2 times in category "CHINESE RICE (Non-Veg)" with no distinguishing text; kept as separate menu_item rows, not merged
-- (no price row)  OAK SMITH GOLD / 180ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  OAK SMITH GOLD / 90ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  OAK SMITH GOLD / 60 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  OAK SMITH GOLD / 30 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  LONDON PILSNER / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  CARLSBERA ELEPHANT / 500ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  CARLSBERA ELEPHANT / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  BUDWISER MAGNIUM / 500ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  BUDWISER MAGNIUM / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  FRESH LIME SODA / Regular: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  BISLERI / 1 Ltr: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  SODA / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  SODA / 300ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  SODA / 500ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  COLD DRINKS / 700ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  COLD DRINKS / 600 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  COLD DRINKS / 330ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  COLD DRINKS / 300 ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant
-- (no price row)  COLD DRINKS / 200ml.: price printed as blank (not a number, not "APS") -> no menu_item_price row inserted for this variant

-- =====================================================================
-- REVIEW BLOCK 2 - restaurant-level completeness notes and structural questions
-- =====================================================================
--
-- NOT PRESENT IN THE JSON (no rows written, nothing to load)
-- * Opening hours: the JSON has no hours/schedule text anywhere (restaurant_hours not populated).
-- * Delivery partners: no delivery-partner name is printed anywhere in the JSON
--   (restaurant_delivery / restaurant_delivery_provider not populated, per the brief's rule that
--   a delivery partner is only used when the JSON explicitly names one).
-- * GST / tax: no GST or "taxes extra" text anywhere -> menu_item_price.tax_regime_code /
--   tax_inclusion_code / tax_rate are NULL on every row.
-- * Coordinates: restaurant.latitude in the JSON is an empty string -> establishment.latitude /
--   longitude left NULL.
-- * email / website: both empty strings in the JSON restaurant object; the schema has no email
--   column, and establishment.website_url was left NULL rather than set to an empty string.
--
-- SCHEMA / RUN-ORDER DEPENDENCY
-- * bar_product.product_type_code's CHECK constraint, as supplied, has no v_brandy_id or 'rtd'
--   value. khaustan_alter_bar_product_type_KhaustanRestaurantMenu.sql widens it to add those
--   (plus a few other standard categories, see that file) and MUST run before this script -
--   DR. BRANDY and BACARDI BREEZER insert those two values (see header note 6).
--
-- CONFIRMED-BY-RESTAURANT CORRECTIONS (kept out of the needs_review flags above, since they are
-- no longer uncertain extractions - they are the restaurant's own correction of a printing/
-- OCR error, applied once and documented here rather than left silently invisible)
-- * The page-8 "VODKA" heading mixing whisky/rum/vodka brands together was confirmed as a menu
--   printing mistake, not an extraction error - see header note 6 for the corrected brands.
-- * "BUTTER CHICKEN (Full)" printed twice (210, 120) was confirmed to be Full/Half, not a
--   duplicate line - merged to FULL=210 / HALF=120 (header note 2).
-- * SODA, COLD DRINKS and BISLERI were restructured from 5 source lines into 3 products with
--   3, 5 and 1 (relabelled "1 Ltr") variants respectively - see header note 2a.
-- * 9 spirit items' prices were re-read against the physical menu (handwriting was unclear to
--   OCR); where the reading differed from the JSON, the new value was used:
--     BLACK DOG            90ml.  550 -> 560
--     ROYAL CHALLENGE      180ml. 840 -> 340,  90ml. 480 -> 180,  30 ml. 80 -> 85
--     MCD LUXURY           60 ml. 100 -> 110
--     DSP BLACK            180ml. 230 -> 290
--     BAGPIPER             180ml. 220 -> 290
--     ROMANOV FLAVOR       180ml. 320 -> 330,  90ml. 180 -> 160
--     ROMANOV              180ml. 320 -> 330
--   OAK SMITH SILVER and BLENDER'S PRIDE were also re-read and matched the JSON - unchanged.
--
-- REMAINING STRUCTURAL QUESTIONS (still open - see REVIEW BLOCK 1 for the exact flagged rows)
-- * "CHI. SCZ. TRIPPLE RICE" is printed twice under CHINESE RICE (Non-Veg) with identical prices
--   (Full 250 / Half 120) both times - likely a duplicate JSON/OCR line, kept as printed rather
--   than silently dropped.
-- * DAL MAKHANI (Rs.130 under RICE, Rs.100 under INDIAN VEG) - see header note 7.
-- =====================================================================
