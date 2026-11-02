-- =====================================================================
-- khaustan_menu_data_Jumboking_Franchise5_400101002_KhaustanRestaurantMenu.sql
--
-- RESTAURANT : JUMBOKING - Franchise 5 of 5, brand_id 000200001 (Jumboking)
--              Shop No. E-28, Om Gokul Nagari CHS, Gokul Nagari-1, Thakur Complex, Kandivali East, Mumbai, Maharashtra 400101
-- IDS        : establishment_id = restaurant_id = source_id = 400101002
-- SOURCE     : Jumboking_Menu_OCR.json (menu is identical across all 5 franchises; only
--              restaurant-level data and the ID namespace differ between the 5 scripts)
-- TARGET     : PostgreSQL, database "KhaustanRestaurantMenu" (one transaction)
-- SCHEMA REF : khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql
-- LOOKUP REF : khaustan_lookup_data_seed_KhaustanRestaurantMenu.sql (READ-ONLY - see below)
--
-- HOW TO RUN  psql -v ON_ERROR_STOP=1 -f <this file>
--             Run it once in a disposable/staging database first. It could not be executed
--             against PostgreSQL where it was produced. The 5 franchise scripts may run in
--             any order relative to each other (brand and canonical_dish rows are shared and
--             created by whichever script runs first; each franchise's own restaurant/menu
--             rows are independent of the others and keyed by its own explicit IDs, never by
--             name+postal_code - see judgement call 1 below).
--
-- LOOKUP TABLES ARE READ-ONLY IN THIS SCRIPT. It never inserts, updates or deletes a
-- service_mode or delivery_provider row - it only reads them by code. The pre-flight check
-- aborts before writing anything if a row it needs is missing.
--
-- ID SCHEME: establishment_id = restaurant_id = source_id = 400101002 (given for this franchise).
-- menu_board, menu_category, menu_item, menu_item_variant, menu_item_price,
-- menu_item_availability and menu_board_item each use their OWN counter, starting at
-- 400101002001 = 400101002*1000+1 and incrementing by 1 in source order within that table.
-- menu_board_item's namespace was not explicitly given for this franchise in the brief and is
-- filled in on the same pattern as every other mandatory table here (and as franchise 1's own
-- explicit instruction gives it) - flagged below. brand_id, canonical_dish(_name), addon_group,
-- addon_option, restaurant_phone, restaurant_hours, menu_extraction_batch and bundle use the
-- schema's ordinary application-generated approach (a helper sequence), since the brief's
-- mandatory namespace list does not cover them.
--
-- ROWS LOADED (this franchise)
--   establishment 1 | restaurant 1 | restaurant_phone 1 | restaurant_hours 7
--   restaurant_service_mode 3 | restaurant_delivery 1 | restaurant_delivery_provider 2
--   source_record 1 | menu_extraction_batch 1 | brand up to 1 (shared, identify-or-create)
--   menu_board 1 | menu_category 12 | menu_board_category 12
--   canonical_dish up to 9 (shared, identify-or-create) | menu_item 30
--   menu_item_source 30 | menu_item_variant 51 | menu_item_price 51
--   menu_item_price_source 51 | menu_item_availability 21
--   bundle 15 | addon_group 1 | addon_option 1 | menu_item_addon_group 2
--   menu_board_item 30
--
-- CONVENTIONS / JUDGEMENT CALLS
--  1. SAME NAME, SAME POSTAL CODE, MULTIPLE RESTAURANTS: checked the schema directly -
--     establishment and restaurant have no UNIQUE constraint on (name, postal_code) or
--     (normalized_name, postal_code) anywhere, only a plain (non-unique) index for query
--     performance (ix_establishment_name_postal). So no ALTER/DROP CONSTRAINT script is
--     needed - the schema already allows this. The only real risk was in the usual
--     identify-or-create SQL pattern (matching an existing establishment/restaurant by
--     name+postal_code): with franchises 2/3 sharing postal_code 400092 and 4/5 sharing
--     400101, that pattern would have wrongly matched one franchise's row to another's. This
--     script instead identifies-or-creates establishment/restaurant by their own explicit,
--     given establishment_id/restaurant_id, never by name or postal_code.
--  2. Brand: one shared `brand` row (brand_id 000200001, "Jumboking", https://www.jumboking.co.in/),
--     identify-or-create by brand_id, since all 5 franchise scripts reference the same brand
--     and any one of them may run first. Not using brand_menu_template/brand_menu_template_item
--     for the shared menu content - the brief's own explicit approach ("create the rest by
--     changing and mapping IDs, replacing restaurant data only") describes duplicating the menu
--     per franchise, which is what this script does; template-based inheritance is a schema
--     feature that would need a separate, explicit decision to adopt.
--  3. "Pure Veg: Yes" is stated at both the JSON's restaurant and franchise level, and no item
--     name anywhere contradicts it (no meat/egg word anywhere in the menu) -> every menu item
--     is food_classification_code = 'veg', restaurant.veg_nonveg_status = 'pure_veg',
--     protein_type_id NULL throughout (does not apply at a pure-veg restaurant).
--  4. Service modes: the brief states Delivery, Takeaway, Dine-in and "On-site services" for
--     every franchise. The first three match existing service_mode codes (delivery, takeaway,
--     dine_in) and are loaded. "On-site services" has no matching code in the lookup table
--     (dine_in, drive_through, takeaway, delivery, bulk_catering, room_service - and it is
--     explicitly listed separately from "Dine-in", so it is unlikely to just mean the same
--     thing) - left unmapped rather than guessed at; see the trailing notes.
--  5. Delivery: the brief states Zomato and Swiggy for every franchise (not from the JSON, but
--     from the brief itself, which the JSON-input prompt allows for restaurant-level facts
--     supplied directly). Both are loaded via restaurant_delivery_provider. No minimum order,
--     delivery charge or radius is stated -> delivery_charge_type_code uses 'fixed' (NOT NULL)
--     with NULL amounts, the same convention used for the two prior restaurants.
--  6. "Meal" and "Combo" are modeled as their own menu_item rows AND given a `bundle` row
--     (bundle_type_code 'meal' / 'combo' respectively - both are the schema's own exact terms,
--     directly matching how the items are printed). No bundle_group/bundle_component rows are
--     created: the JSON never itemizes what a Meal or Combo actually contains, and the prompt's
--     own standing rule is not to invent standalone components the JSON doesn't establish.
--     "Buy One Burger Get The Same Burger" (Fantastic Fridays) is NOT given a bundle row: its
--     second component is "whichever burger you already ordered", not a fixed, nameable item,
--     so it doesn't fit the bundle model and is left as a plain menu_item.
--  7. Canonical dishes: "Meal", "Combo" and "Burger" are each printed under all 7 weekday
--     categories at different prices - per the same standing rule used for every prior
--     restaurant (an identical name recurring across different categories is treated as a
--     possibly-different product each time), all 21 of these menu_item rows are left with
--     canonical_dish_id = NULL, rather than merged into 3 canonical dishes that don't actually
--     hold across the different burgers/prices. The 9 other items (Regular Fries,
--     Peri Peri Loaded Fries, the 4 thickshake flavours, Buy One Burger Get The Same Burger,
--     Combo Starting @, Softy) are unique names and link normally.
--  8. Add-on: "Add On Cheese Rs.20" (printed once, under FRIES) -> one addon_group ("Fries
--     Add-ons", selection_type 'single', not required) with one addon_option ("Cheese",
--     Rs.20), linked to both Regular Fries and Peri Peri Loaded Fries.
--  9. Day-of-week: each weekday category's own heading states the day (e.g. "MON - OG DOUBLE
--     CHEESE BURGER") - raw_category_text keeps that full heading verbatim, and all 3 items in
--     that category (Meal/Combo/Burger) additionally get a menu_item_availability row for that
--     day_of_week (1 = Monday), the same treatment a day-named dish got in an earlier
--     restaurant's menu, just sourced from the category heading instead of the item name.
-- 10. Hours: this franchise's stated hours are "9 am to 11:30 pm" -> every day of the week gets the
--     same restaurant_hours row. "Open 24 hours" is stored as 00:00:00-23:59:59 (a
--     documented convention, since the schema has no dedicated always-open marker at the
--     per-slot level) and restaurant.is_24_hours is also set TRUE, a real column made for
--     exactly this. Coordinates are rounded to the column's 14-decimal-place limit (source data
--     carried one extra digit); the change is on the order of a millimetre.
-- 11. Not loaded (no schema column and/or restaurant-level info only, not from the JSON menu
--     itself): "Price per person: Rs.1-200" (a wide range, and the column that most resembles it,
--     cost_for_two_amount, is a single amount for TWO people, not a per-person range - putting
--     a misleading number in a real column seemed worse than leaving it out); calorie/
--     nutritional-analysis text under nearly every category (no nutrition column anywhere in
--     the schema); the "JUMBOKING / FANTASTIC FRIDAYS / HAPPY BREAK / HAPPY PEOPLE" marketing
--     banner lines; "*Pictures shown for representational purposes only" disclaimer. See the
--     trailing notes for the complete list.
-- =====================================================================

--\connect "KhaustanRestaurantMenu"
\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Helper sequence (non-mandatory standalone IDs only) + PRE-FLIGHT
-- ---------------------------------------------------------------------
DO $seq$
DECLARE
    v_max BIGINT;
BEGIN
    SELECT GREATEST(
        COALESCE((SELECT MAX(restaurant_phone_id) FROM restaurant_phone), 0),
        COALESCE((SELECT MAX(restaurant_hours_id) FROM restaurant_hours), 0),
        COALESCE((SELECT MAX(extraction_batch_id) FROM menu_extraction_batch), 0),
        COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
        COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0),
        COALESCE((SELECT MAX(addon_group_id) FROM addon_group), 0),
        COALESCE((SELECT MAX(addon_option_id) FROM addon_option), 0),
        COALESCE((SELECT MAX(bundle_id) FROM bundle), 0)
    ) INTO v_max;
    EXECUTE format('CREATE SEQUENCE IF NOT EXISTS khaustan_jumboking_helper_seq START WITH %s', v_max + 1);
END
$seq$;

DO $pre$
DECLARE
    v_missing text;
BEGIN
    SELECT string_agg(m.item, ', ' ORDER BY m.item)
      INTO v_missing
      FROM (
            SELECT 'service_mode.' || t.code AS item
              FROM (VALUES ('delivery'), ('takeaway'), ('dine_in')) AS t(code)
             WHERE NOT EXISTS (SELECT 1 FROM service_mode s WHERE s.code = t.code)
            UNION ALL
            SELECT 'delivery_provider.' || t.code
              FROM (VALUES ('ZOMATO'), ('SWIGGY')) AS t(code)
             WHERE NOT EXISTS (SELECT 1 FROM delivery_provider d WHERE d.provider_code = t.code)
           ) AS m;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Jumboking franchise 5 load aborted - lookup rows missing: %. Run the lookup seed script first.', v_missing;
    END IF;

    IF EXISTS (SELECT 1 FROM menu_item WHERE restaurant_id = 400101002)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400101002)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 400101002) THEN
        RAISE EXCEPTION 'Jumboking franchise 5 (restaurant_id 400101002) already has menu data or source_id 400101002 is in use - refusing to load twice.';
    END IF;

    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400101002)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400101002) THEN
        RAISE EXCEPTION 'establishment_id/restaurant_id 400101002 is already in use by a different row - resolve before loading.';
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------
-- 1. Brand (shared across all franchises; identify-or-create by brand_id)
-- ---------------------------------------------------------------------
INSERT INTO brand (brand_id, name, normalized_name, website_url)
SELECT 000200001, 'Jumboking', 'jumboking', 'https://www.jumboking.co.in/'
WHERE NOT EXISTS (SELECT 1 FROM brand WHERE brand_id = 000200001);

-- ---------------------------------------------------------------------
-- 2. Establishment + restaurant. Identified by their own explicit id, never by
--    name/postal_code (judgement call 1) - city/state left to the schema's own defaults
--    ('Mumbai'/'Maharashtra'), which match this address.
-- ---------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, latitude, longitude)
SELECT 400101002, 'JUMBOKING', 'jumboking', 'Shop No. E-28, Om Gokul Nagari CHS, Gokul Nagari-1, Thakur Complex', 'Kandivali East', '400101', 19.21378303534930, 72.86672741139239
WHERE NOT EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400101002);

INSERT INTO restaurant (restaurant_id, establishment_id, brand_id, display_name, normalized_name, veg_nonveg_status, has_bar, bar_license_type, is_24_hours)
SELECT 400101002, 400101002, 000200001, 'JUMBOKING', 'jumboking', 'pure_veg', FALSE, 'none', FALSE
WHERE NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400101002);

-- ---------------------------------------------------------------------
-- 3. Phone, exactly as given (kept as printed, including any leading 0)
-- ---------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES (nextval('khaustan_jumboking_helper_seq'), 400101002, '09930181965', TRUE);

-- ---------------------------------------------------------------------
-- 4. Hours: "9 am to 11:30 pm" applied to every day of the week (no per-day variation is stated for opening
--    hours themselves - only the featured burger rotates by day, handled separately below)
-- ---------------------------------------------------------------------
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at) VALUES
(nextval('khaustan_jumboking_helper_seq'), 400101002, 1, 1, '09:00', '23:30'),
(nextval('khaustan_jumboking_helper_seq'), 400101002, 2, 1, '09:00', '23:30'),
(nextval('khaustan_jumboking_helper_seq'), 400101002, 3, 1, '09:00', '23:30'),
(nextval('khaustan_jumboking_helper_seq'), 400101002, 4, 1, '09:00', '23:30'),
(nextval('khaustan_jumboking_helper_seq'), 400101002, 5, 1, '09:00', '23:30'),
(nextval('khaustan_jumboking_helper_seq'), 400101002, 6, 1, '09:00', '23:30'),
(nextval('khaustan_jumboking_helper_seq'), 400101002, 7, 1, '09:00', '23:30');

-- ---------------------------------------------------------------------
-- 5. Service modes: Delivery, Takeaway, Dine-in. "On-site services" has no matching lookup
--    code and is not loaded (see judgement call 4 and the trailing notes).
-- ---------------------------------------------------------------------
INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id) VALUES
(400101002, (SELECT service_mode_id FROM service_mode WHERE code = 'delivery')),
(400101002, (SELECT service_mode_id FROM service_mode WHERE code = 'takeaway')),
(400101002, (SELECT service_mode_id FROM service_mode WHERE code = 'dine_in'));

-- ---------------------------------------------------------------------
-- 6. Delivery: Zomato and Swiggy (stated in the brief for every franchise). No minimum order,
--    charge or radius is stated.
-- ---------------------------------------------------------------------
INSERT INTO restaurant_delivery (restaurant_id, delivery_available) VALUES (400101002, TRUE);

INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from) VALUES
(nextval('khaustan_jumboking_helper_seq'), 400101002, (SELECT delivery_provider_id FROM delivery_provider WHERE provider_code = 'ZOMATO'), 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')),
(nextval('khaustan_jumboking_helper_seq'), 400101002, (SELECT delivery_provider_id FROM delivery_provider WHERE provider_code = 'SWIGGY'), 'fixed', (clock_timestamp() AT TIME ZONE 'UTC'));

-- ---------------------------------------------------------------------
-- 7. Provenance: source_id = 400101002 (per the mandatory rule); one extraction batch
-- ---------------------------------------------------------------------
INSERT INTO source_record (source_id, source_type_code, source_uri) VALUES
(400101002, 'ai_menu_extraction', 'Jumboking_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, extractor_version, started_at, completed_at, status_code) VALUES
(nextval('khaustan_jumboking_helper_seq'), 400101002, 400101002, 'claude-sonnet-5 (json menu prompt, multi-franchise)', (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

-- ---------------------------------------------------------------------
-- 8. Menu board (single a_la_carte board; the JSON has no explicit board field)
-- ---------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, display_sequence) VALUES
(400101002001, 400101002, 'Jumboking Menu', 'a_la_carte', 1);

-- ---------------------------------------------------------------------
-- 9. menu_category, one per JSON section in source order (flat)
-- ---------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence) VALUES
(400101002001, 400101002, 'MON - OG DOUBLE CHEESE BURGER', 1),
(400101002002, 400101002, 'TUE - MAC & CHEESE BURGER', 2),
(400101002003, 400101002, 'WED - PERI PERI NACHOS BURGER', 3),
(400101002004, 400101002, 'THU - BIG CRUNCH BURGER', 4),
(400101002005, 400101002, 'FRI - CRISPY VEG BURGER', 5),
(400101002006, 400101002, 'SAT - CLASSIC CHEESE BURST BURGER', 6),
(400101002007, 400101002, 'SUN - ZESTY PANEER BURGER', 7),
(400101002008, 400101002, 'THICKSHAKES @ ₹99/-', 8),
(400101002009, 400101002, 'FRIES', 9),
(400101002010, 400101002, 'FANTASTIC FRIDAYS', 10),
(400101002011, 400101002, 'COMBO', 11),
(400101002012, 400101002, 'SOFTY', 12);

-- ---------------------------------------------------------------------
-- 10. menu_board_category: every category is exposed on the single board
-- ---------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
(400101002, 400101002001, 400101002001, 1),
(400101002, 400101002001, 400101002002, 2),
(400101002, 400101002001, 400101002003, 3),
(400101002, 400101002001, 400101002004, 4),
(400101002, 400101002001, 400101002005, 5),
(400101002, 400101002001, 400101002006, 6),
(400101002, 400101002001, 400101002007, 7),
(400101002, 400101002001, 400101002008, 8),
(400101002, 400101002001, 400101002009, 9),
(400101002, 400101002001, 400101002010, 10),
(400101002, 400101002001, 400101002011, 11),
(400101002, 400101002001, 400101002012, 12);

-- ---------------------------------------------------------------------
-- 11. canonical_dish + canonical_dish_name (shared across franchises; identify-or-create by
--     exact normalized name; canonical_dish has no unique constraint, hence NOT EXISTS).
--     Meal/Combo/Burger (all 7 weekday categories) are deliberately NOT given a canonical row
--     here - see header note 7.
-- ---------------------------------------------------------------------
WITH v(cname, nname) AS (VALUES
('Chocolate', 'chocolate'),
('Cold Coffee', 'cold coffee'),
('Oreo', 'oreo'),
('Blueberry Cheesecake', 'blueberry cheesecake'),
('Regular Fries', 'regular fries'),
('Peri Peri Loaded Fries', 'peri peri loaded fries'),
('Buy One Burger Get The Same Burger', 'buy one burger get the same burger'),
('Combo Starting @', 'combo starting @'),
('Softy', 'softy')
)
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
SELECT nextval('khaustan_jumboking_helper_seq'), v.cname, v.nname FROM v
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish c WHERE c.normalized_name = v.nname);

INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_jumboking_helper_seq'), c.canonical_dish_id, 'en', c.canonical_name, c.normalized_name, 'primary'
FROM canonical_dish c
WHERE c.normalized_name IN ('chocolate',
       'cold coffee',
       'oreo',
       'blueberry cheesecake',
       'regular fries',
       'peri peri loaded fries',
       'buy one burger get the same burger',
       'combo starting @',
       'softy')
  AND NOT EXISTS (SELECT 1 FROM canonical_dish_name n WHERE n.canonical_dish_id = c.canonical_dish_id AND n.name_type_code = 'primary');

-- ---------------------------------------------------------------------
-- 12. menu_item (source order)
-- ---------------------------------------------------------------------
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code) VALUES
-- Source: JSON, "MON - OG DOUBLE CHEESE BURGER" section
-- item: "Meal" also appears under FRI - CRISPY VEG BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002001, 400101002, 400101002001, NULL, 'Meal', 'meal', 'MON - OG DOUBLE CHEESE BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under FRI - CRISPY VEG BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002002, 400101002, 400101002001, NULL, 'Combo', 'combo', 'MON - OG DOUBLE CHEESE BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under FRI - CRISPY VEG BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002003, 400101002, 400101002001, NULL, 'Burger', 'burger', 'MON - OG DOUBLE CHEESE BURGER', 'veg', 'unverified'),
-- Source: JSON, "TUE - MAC & CHEESE BURGER" section
-- item: "Meal" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002004, 400101002, 400101002002, NULL, 'Meal', 'meal', 'TUE - MAC & CHEESE BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002005, 400101002, 400101002002, NULL, 'Combo', 'combo', 'TUE - MAC & CHEESE BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002006, 400101002, 400101002002, NULL, 'Burger', 'burger', 'TUE - MAC & CHEESE BURGER', 'veg', 'unverified'),
-- Source: JSON, "WED - PERI PERI NACHOS BURGER" section
-- item: "Meal" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002007, 400101002, 400101002003, NULL, 'Meal', 'meal', 'WED - PERI PERI NACHOS BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002008, 400101002, 400101002003, NULL, 'Combo', 'combo', 'WED - PERI PERI NACHOS BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002009, 400101002, 400101002003, NULL, 'Burger', 'burger', 'WED - PERI PERI NACHOS BURGER', 'veg', 'unverified'),
-- Source: JSON, "THU - BIG CRUNCH BURGER" section
-- item: "Meal" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002010, 400101002, 400101002004, NULL, 'Meal', 'meal', 'THU - BIG CRUNCH BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002011, 400101002, 400101002004, NULL, 'Combo', 'combo', 'THU - BIG CRUNCH BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002012, 400101002, 400101002004, NULL, 'Burger', 'burger', 'THU - BIG CRUNCH BURGER', 'veg', 'unverified'),
-- Source: JSON, "FRI - CRISPY VEG BURGER" section
-- item: "Meal" also appears under MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002013, 400101002, 400101002005, NULL, 'Meal', 'meal', 'FRI - CRISPY VEG BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002014, 400101002, 400101002005, NULL, 'Combo', 'combo', 'FRI - CRISPY VEG BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002015, 400101002, 400101002005, NULL, 'Burger', 'burger', 'FRI - CRISPY VEG BURGER', 'veg', 'unverified'),
-- Source: JSON, "SAT - CLASSIC CHEESE BURST BURGER" section
-- item: "Meal" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002016, 400101002, 400101002006, NULL, 'Meal', 'meal', 'SAT - CLASSIC CHEESE BURST BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002017, 400101002, 400101002006, NULL, 'Combo', 'combo', 'SAT - CLASSIC CHEESE BURST BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SUN - ZESTY PANEER BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002018, 400101002, 400101002006, NULL, 'Burger', 'burger', 'SAT - CLASSIC CHEESE BURST BURGER', 'veg', 'unverified'),
-- Source: JSON, "SUN - ZESTY PANEER BURGER" section
-- item: "Meal" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002019, 400101002, 400101002007, NULL, 'Meal', 'meal', 'SUN - ZESTY PANEER BURGER', 'veg', 'unverified'),
-- item: "Combo" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002020, 400101002, 400101002007, NULL, 'Combo', 'combo', 'SUN - ZESTY PANEER BURGER', 'veg', 'unverified'),
-- item: "Burger" also appears under FRI - CRISPY VEG BURGER / MON - OG DOUBLE CHEESE BURGER / SAT - CLASSIC CHEESE BURST BURGER / THU - BIG CRUNCH BURGER / TUE - MAC & CHEESE BURGER / WED - PERI PERI NACHOS BURGER -> canonical_dish_id left NULL so differently-priced/possibly-different products are not merged
(400101002021, 400101002, 400101002007, NULL, 'Burger', 'burger', 'SUN - ZESTY PANEER BURGER', 'veg', 'unverified'),
-- Source: JSON, "THICKSHAKES @ ₹99/-" section
(400101002022, 400101002, 400101002008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chocolate' ORDER BY canonical_dish_id LIMIT 1), 'Chocolate', 'chocolate', 'THICKSHAKES @ ₹99/-', 'veg', 'unverified'),
(400101002023, 400101002, 400101002008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cold coffee' ORDER BY canonical_dish_id LIMIT 1), 'Cold Coffee', 'cold coffee', 'THICKSHAKES @ ₹99/-', 'veg', 'unverified'),
(400101002024, 400101002, 400101002008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'oreo' ORDER BY canonical_dish_id LIMIT 1), 'Oreo', 'oreo', 'THICKSHAKES @ ₹99/-', 'veg', 'unverified'),
(400101002025, 400101002, 400101002008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'blueberry cheesecake' ORDER BY canonical_dish_id LIMIT 1), 'Blueberry Cheesecake', 'blueberry cheesecake', 'THICKSHAKES @ ₹99/-', 'veg', 'unverified'),
-- Source: JSON, "FRIES" section
(400101002026, 400101002, 400101002009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'regular fries' ORDER BY canonical_dish_id LIMIT 1), 'Regular Fries', 'regular fries', 'FRIES', 'veg', 'unverified'),
(400101002027, 400101002, 400101002009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'peri peri loaded fries' ORDER BY canonical_dish_id LIMIT 1), 'Peri Peri Loaded Fries', 'peri peri loaded fries', 'FRIES', 'veg', 'unverified'),
-- Source: JSON, "FANTASTIC FRIDAYS" section
(400101002028, 400101002, 400101002010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'buy one burger get the same burger' ORDER BY canonical_dish_id LIMIT 1), 'Buy One Burger Get The Same Burger', 'buy one burger get the same burger', 'FANTASTIC FRIDAYS', 'veg', 'unverified'),
-- Source: JSON, "COMBO" section
(400101002029, 400101002, 400101002011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'combo starting @' ORDER BY canonical_dish_id LIMIT 1), 'Combo Starting @', 'combo starting @', 'COMBO', 'veg', 'unverified'),
-- Source: JSON, "SOFTY" section
(400101002030, 400101002, 400101002012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'softy' ORDER BY canonical_dish_id LIMIT 1), 'Softy', 'softy', 'SOFTY', 'veg', 'unverified');

-- ---------------------------------------------------------------------
-- 13. menu_item_source
-- ---------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) VALUES
(400101002001, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002002, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002003, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002004, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002005, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002006, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002007, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002008, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002009, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002010, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002011, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002012, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002013, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002014, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002015, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002016, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002017, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002018, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002019, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002020, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002021, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002022, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002023, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002024, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002025, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002026, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002027, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002028, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002029, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified'),
(400101002030, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98, 'unverified');

-- ---------------------------------------------------------------------
-- 14. menu_item_variant ('Regular' for a single-price item; 'Regular'/'Offer' for the
--     weekday-burger Meal/Combo/Burger lines - default = 'Regular', the non-promotional price)
-- ---------------------------------------------------------------------
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, display_sequence, is_default) VALUES
-- Source: JSON, "MON - OG DOUBLE CHEESE BURGER" section
(400101002001, 400101002001, 'Regular', 'fixed', 1, TRUE),
(400101002002, 400101002001, 'Offer', 'fixed', 2, FALSE),
(400101002003, 400101002002, 'Regular', 'fixed', 1, TRUE),
(400101002004, 400101002002, 'Offer', 'fixed', 2, FALSE),
(400101002005, 400101002003, 'Regular', 'fixed', 1, TRUE),
(400101002006, 400101002003, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "TUE - MAC & CHEESE BURGER" section
(400101002007, 400101002004, 'Regular', 'fixed', 1, TRUE),
(400101002008, 400101002004, 'Offer', 'fixed', 2, FALSE),
(400101002009, 400101002005, 'Regular', 'fixed', 1, TRUE),
(400101002010, 400101002005, 'Offer', 'fixed', 2, FALSE),
(400101002011, 400101002006, 'Regular', 'fixed', 1, TRUE),
(400101002012, 400101002006, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "WED - PERI PERI NACHOS BURGER" section
(400101002013, 400101002007, 'Regular', 'fixed', 1, TRUE),
(400101002014, 400101002007, 'Offer', 'fixed', 2, FALSE),
(400101002015, 400101002008, 'Regular', 'fixed', 1, TRUE),
(400101002016, 400101002008, 'Offer', 'fixed', 2, FALSE),
(400101002017, 400101002009, 'Regular', 'fixed', 1, TRUE),
(400101002018, 400101002009, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "THU - BIG CRUNCH BURGER" section
(400101002019, 400101002010, 'Regular', 'fixed', 1, TRUE),
(400101002020, 400101002010, 'Offer', 'fixed', 2, FALSE),
(400101002021, 400101002011, 'Regular', 'fixed', 1, TRUE),
(400101002022, 400101002011, 'Offer', 'fixed', 2, FALSE),
(400101002023, 400101002012, 'Regular', 'fixed', 1, TRUE),
(400101002024, 400101002012, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "FRI - CRISPY VEG BURGER" section
(400101002025, 400101002013, 'Regular', 'fixed', 1, TRUE),
(400101002026, 400101002013, 'Offer', 'fixed', 2, FALSE),
(400101002027, 400101002014, 'Regular', 'fixed', 1, TRUE),
(400101002028, 400101002014, 'Offer', 'fixed', 2, FALSE),
(400101002029, 400101002015, 'Regular', 'fixed', 1, TRUE),
(400101002030, 400101002015, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "SAT - CLASSIC CHEESE BURST BURGER" section
(400101002031, 400101002016, 'Regular', 'fixed', 1, TRUE),
(400101002032, 400101002016, 'Offer', 'fixed', 2, FALSE),
(400101002033, 400101002017, 'Regular', 'fixed', 1, TRUE),
(400101002034, 400101002017, 'Offer', 'fixed', 2, FALSE),
(400101002035, 400101002018, 'Regular', 'fixed', 1, TRUE),
(400101002036, 400101002018, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "SUN - ZESTY PANEER BURGER" section
(400101002037, 400101002019, 'Regular', 'fixed', 1, TRUE),
(400101002038, 400101002019, 'Offer', 'fixed', 2, FALSE),
(400101002039, 400101002020, 'Regular', 'fixed', 1, TRUE),
(400101002040, 400101002020, 'Offer', 'fixed', 2, FALSE),
(400101002041, 400101002021, 'Regular', 'fixed', 1, TRUE),
(400101002042, 400101002021, 'Offer', 'fixed', 2, FALSE),
-- Source: JSON, "THICKSHAKES @ ₹99/-" section
(400101002043, 400101002022, 'Regular', 'fixed', 1, TRUE),
(400101002044, 400101002023, 'Regular', 'fixed', 1, TRUE),
(400101002045, 400101002024, 'Regular', 'fixed', 1, TRUE),
(400101002046, 400101002025, 'Regular', 'fixed', 1, TRUE),
-- Source: JSON, "FRIES" section
(400101002047, 400101002026, 'Regular', 'fixed', 1, TRUE),
(400101002048, 400101002027, 'Regular', 'fixed', 1, TRUE),
-- Source: JSON, "FANTASTIC FRIDAYS" section
(400101002049, 400101002028, 'Regular', 'fixed', 1, TRUE),
-- Source: JSON, "COMBO" section
(400101002050, 400101002029, 'Regular', 'fixed', 1, TRUE),
-- Source: JSON, "SOFTY" section
(400101002051, 400101002030, 'Regular', 'fixed', 1, TRUE);

-- ---------------------------------------------------------------------
-- 15. menu_item_price (INR; no GST/tax text anywhere -> tax columns NULL; effective_from = the
--     extraction timestamp, since the JSON prints no rate-effective date)
-- ---------------------------------------------------------------------
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, verification_status_code, source_id) VALUES
-- Source: JSON, "MON - OG DOUBLE CHEESE BURGER" section
(400101002001, 400101002001, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002002, 400101002002, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002003, 400101002003, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002004, 400101002004, 109.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002005, 400101002005, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002006, 400101002006, 79.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "TUE - MAC & CHEESE BURGER" section
(400101002007, 400101002007, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002008, 400101002008, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002009, 400101002009, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002010, 400101002010, 109.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002011, 400101002011, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002012, 400101002012, 79.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "WED - PERI PERI NACHOS BURGER" section
(400101002013, 400101002013, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002014, 400101002014, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002015, 400101002015, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002016, 400101002016, 109.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002017, 400101002017, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002018, 400101002018, 79.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "THU - BIG CRUNCH BURGER" section
(400101002019, 400101002019, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002020, 400101002020, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002021, 400101002021, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002022, 400101002022, 109.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002023, 400101002023, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002024, 400101002024, 79.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "FRI - CRISPY VEG BURGER" section
(400101002025, 400101002025, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002026, 400101002026, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002027, 400101002027, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002028, 400101002028, 109.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002029, 400101002029, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002030, 400101002030, 79.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "SAT - CLASSIC CHEESE BURST BURGER" section
(400101002031, 400101002031, 229.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002032, 400101002032, 209.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002033, 400101002033, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002034, 400101002034, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002035, 400101002035, 149.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002036, 400101002036, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "SUN - ZESTY PANEER BURGER" section
(400101002037, 400101002037, 229.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002038, 400101002038, 209.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002039, 400101002039, 179.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002040, 400101002040, 159.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002041, 400101002041, 149.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002042, 400101002042, 129.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "THICKSHAKES @ ₹99/-" section
(400101002043, 400101002043, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002044, 400101002044, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002045, 400101002045, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002046, 400101002046, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "FRIES" section
(400101002047, 400101002047, 70.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
(400101002048, 400101002048, 99.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "FANTASTIC FRIDAYS" section
(400101002049, 400101002049, 50.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "COMBO" section
(400101002050, 400101002050, 79.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002),
-- Source: JSON, "SOFTY" section
(400101002051, 400101002051, 25.00, FALSE, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified', 400101002);

-- ---------------------------------------------------------------------
-- 16. menu_item_price_source
-- ---------------------------------------------------------------------
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence) VALUES
(400101002001, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002002, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002003, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002004, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002005, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002006, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002007, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002008, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002009, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002010, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002011, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002012, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002013, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002014, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002015, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002016, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002017, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002018, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002019, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002020, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002021, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002022, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002023, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002024, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002025, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002026, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002027, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002028, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002029, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002030, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002031, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002032, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002033, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002034, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002035, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002036, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002037, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002038, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002039, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002040, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002041, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002042, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002043, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002044, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002045, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002046, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002047, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002048, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002049, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002050, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98),
(400101002051, 400101002, (SELECT extraction_batch_id FROM menu_extraction_batch WHERE restaurant_id = 400101002 AND source_id = 400101002), 0.98);

-- ---------------------------------------------------------------------
-- 17. menu_item_availability: the 3 items (Meal/Combo/Burger) under each weekday category get
--     a day_of_week row matching that category's own heading (1 = Monday ... 7 = Sunday; no
--     times are printed, so start_time/end_time stay NULL)
-- ---------------------------------------------------------------------
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week) VALUES
-- Source: JSON, "MON - OG DOUBLE CHEESE BURGER" section (Monday)
(400101002001, 400101002001, 1),
(400101002002, 400101002002, 1),
(400101002003, 400101002003, 1),
-- Source: JSON, "TUE - MAC & CHEESE BURGER" section (Tuesday)
(400101002004, 400101002004, 2),
(400101002005, 400101002005, 2),
(400101002006, 400101002006, 2),
-- Source: JSON, "WED - PERI PERI NACHOS BURGER" section (Wednesday)
(400101002007, 400101002007, 3),
(400101002008, 400101002008, 3),
(400101002009, 400101002009, 3),
-- Source: JSON, "THU - BIG CRUNCH BURGER" section (Thursday)
(400101002010, 400101002010, 4),
(400101002011, 400101002011, 4),
(400101002012, 400101002012, 4),
-- Source: JSON, "FRI - CRISPY VEG BURGER" section (Friday)
(400101002013, 400101002013, 5),
(400101002014, 400101002014, 5),
(400101002015, 400101002015, 5),
-- Source: JSON, "SAT - CLASSIC CHEESE BURST BURGER" section (Saturday)
(400101002016, 400101002016, 6),
(400101002017, 400101002017, 6),
(400101002018, 400101002018, 6),
-- Source: JSON, "SUN - ZESTY PANEER BURGER" section (Sunday)
(400101002019, 400101002019, 7),
(400101002020, 400101002020, 7),
(400101002021, 400101002021, 7);

-- ---------------------------------------------------------------------
-- 18. bundle (1:1 with a Meal/Combo menu_item; no bundle_group/bundle_component rows - see
--     header note 6)
-- ---------------------------------------------------------------------
INSERT INTO bundle (bundle_id, menu_item_id, bundle_type_code) VALUES
-- Source: JSON, "MON - OG DOUBLE CHEESE BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002001, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002002, 'combo'),
-- Source: JSON, "TUE - MAC & CHEESE BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002004, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002005, 'combo'),
-- Source: JSON, "WED - PERI PERI NACHOS BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002007, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002008, 'combo'),
-- Source: JSON, "THU - BIG CRUNCH BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002010, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002011, 'combo'),
-- Source: JSON, "FRI - CRISPY VEG BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002013, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002014, 'combo'),
-- Source: JSON, "SAT - CLASSIC CHEESE BURST BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002016, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002017, 'combo'),
-- Source: JSON, "SUN - ZESTY PANEER BURGER" section
(nextval('khaustan_jumboking_helper_seq'), 400101002019, 'meal'),
(nextval('khaustan_jumboking_helper_seq'), 400101002020, 'combo'),
-- Source: JSON, "COMBO" section
(nextval('khaustan_jumboking_helper_seq'), 400101002029, 'combo');

-- ---------------------------------------------------------------------
-- 19. Add-on: "Add On Cheese Rs.20" under FRIES -> one addon_group, one addon_option, linked to
--     both fries items
-- ---------------------------------------------------------------------
INSERT INTO addon_group (addon_group_id, restaurant_id, name, selection_type, is_required) VALUES
(nextval('khaustan_jumboking_helper_seq'), 400101002, 'Fries Add-ons', 'single', FALSE);

INSERT INTO addon_option (addon_option_id, addon_group_id, name, extra_price)
SELECT nextval('khaustan_jumboking_helper_seq'), addon_group_id, 'Cheese', 20.00
FROM addon_group WHERE restaurant_id = 400101002 AND name = 'Fries Add-ons';

INSERT INTO menu_item_addon_group (menu_item_id, addon_group_id) VALUES
(400101002026, (SELECT addon_group_id FROM addon_group WHERE restaurant_id = 400101002 AND name = 'Fries Add-ons')),
(400101002027, (SELECT addon_group_id FROM addon_group WHERE restaurant_id = 400101002 AND name = 'Fries Add-ons'));

-- ---------------------------------------------------------------------
-- 20. menu_board_item; display_sequence = document order
-- ---------------------------------------------------------------------
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence) VALUES
-- Source: JSON, "MON - OG DOUBLE CHEESE BURGER" section
(400101002001, 400101002, 400101002001, 400101002001, 400101002001, 1),
(400101002002, 400101002, 400101002001, 400101002002, 400101002001, 2),
(400101002003, 400101002, 400101002001, 400101002003, 400101002001, 3),
-- Source: JSON, "TUE - MAC & CHEESE BURGER" section
(400101002004, 400101002, 400101002001, 400101002004, 400101002002, 4),
(400101002005, 400101002, 400101002001, 400101002005, 400101002002, 5),
(400101002006, 400101002, 400101002001, 400101002006, 400101002002, 6),
-- Source: JSON, "WED - PERI PERI NACHOS BURGER" section
(400101002007, 400101002, 400101002001, 400101002007, 400101002003, 7),
(400101002008, 400101002, 400101002001, 400101002008, 400101002003, 8),
(400101002009, 400101002, 400101002001, 400101002009, 400101002003, 9),
-- Source: JSON, "THU - BIG CRUNCH BURGER" section
(400101002010, 400101002, 400101002001, 400101002010, 400101002004, 10),
(400101002011, 400101002, 400101002001, 400101002011, 400101002004, 11),
(400101002012, 400101002, 400101002001, 400101002012, 400101002004, 12),
-- Source: JSON, "FRI - CRISPY VEG BURGER" section
(400101002013, 400101002, 400101002001, 400101002013, 400101002005, 13),
(400101002014, 400101002, 400101002001, 400101002014, 400101002005, 14),
(400101002015, 400101002, 400101002001, 400101002015, 400101002005, 15),
-- Source: JSON, "SAT - CLASSIC CHEESE BURST BURGER" section
(400101002016, 400101002, 400101002001, 400101002016, 400101002006, 16),
(400101002017, 400101002, 400101002001, 400101002017, 400101002006, 17),
(400101002018, 400101002, 400101002001, 400101002018, 400101002006, 18),
-- Source: JSON, "SUN - ZESTY PANEER BURGER" section
(400101002019, 400101002, 400101002001, 400101002019, 400101002007, 19),
(400101002020, 400101002, 400101002001, 400101002020, 400101002007, 20),
(400101002021, 400101002, 400101002001, 400101002021, 400101002007, 21),
-- Source: JSON, "THICKSHAKES @ ₹99/-" section
(400101002022, 400101002, 400101002001, 400101002022, 400101002008, 22),
(400101002023, 400101002, 400101002001, 400101002023, 400101002008, 23),
(400101002024, 400101002, 400101002001, 400101002024, 400101002008, 24),
(400101002025, 400101002, 400101002001, 400101002025, 400101002008, 25),
-- Source: JSON, "FRIES" section
(400101002026, 400101002, 400101002001, 400101002026, 400101002009, 26),
(400101002027, 400101002, 400101002001, 400101002027, 400101002009, 27),
-- Source: JSON, "FANTASTIC FRIDAYS" section
(400101002028, 400101002, 400101002001, 400101002028, 400101002010, 28),
-- Source: JSON, "COMBO" section
(400101002029, 400101002, 400101002001, 400101002029, 400101002011, 29),
-- Source: JSON, "SOFTY" section
(400101002030, 400101002, 400101002001, 400101002030, 400101002012, 30);

-- ---------------------------------------------------------------------
-- 21. POST-LOAD CHECK (raises -> whole transaction rolls back)
-- ---------------------------------------------------------------------
DO $post$
DECLARE
    n_cat bigint; n_item bigint; n_var bigint; n_price bigint; n_bc bigint; n_bi bigint;
    n_avail bigint; n_bundle bigint; n_hours bigint; n_svc bigint; n_dp bigint;
BEGIN
    SELECT count(*) INTO n_cat FROM menu_category WHERE restaurant_id = 400101002;
    SELECT count(*) INTO n_item FROM menu_item WHERE restaurant_id = 400101002;
    SELECT count(*) INTO n_var FROM menu_item_variant v JOIN menu_item i ON i.menu_item_id = v.menu_item_id WHERE i.restaurant_id = 400101002;
    SELECT count(*) INTO n_price FROM menu_item_price p JOIN menu_item_variant v ON v.variant_id = p.variant_id JOIN menu_item i ON i.menu_item_id = v.menu_item_id WHERE i.restaurant_id = 400101002;
    SELECT count(*) INTO n_bc FROM menu_board_category WHERE restaurant_id = 400101002;
    SELECT count(*) INTO n_bi FROM menu_board_item WHERE restaurant_id = 400101002;
    SELECT count(*) INTO n_avail FROM menu_item_availability a JOIN menu_item i ON i.menu_item_id = a.menu_item_id WHERE i.restaurant_id = 400101002;
    SELECT count(*) INTO n_bundle FROM bundle b JOIN menu_item i ON i.menu_item_id = b.menu_item_id WHERE i.restaurant_id = 400101002;
    SELECT count(*) INTO n_hours FROM restaurant_hours WHERE restaurant_id = 400101002;
    SELECT count(*) INTO n_svc FROM restaurant_service_mode WHERE restaurant_id = 400101002;
    SELECT count(*) INTO n_dp FROM restaurant_delivery_provider WHERE restaurant_id = 400101002;

    IF n_cat <> 12 OR n_item <> 30 OR n_var <> 51 OR n_price <> 51
       OR n_bc <> 12 OR n_bi <> 30 OR n_avail <> 21 OR n_bundle <> 15
       OR n_hours <> 7 OR n_svc <> 3 OR n_dp <> 2 THEN
        RAISE EXCEPTION 'Jumboking franchise 5 post-load check failed: categories=%, items=%, variants=%, prices=%, board_categories=%, board_items=%, availability=%, bundles=%, hours=%, service_modes=%, delivery_providers=%',
            n_cat, n_item, n_var, n_price, n_bc, n_bi, n_avail, n_bundle, n_hours, n_svc, n_dp;
    END IF;

    IF EXISTS (SELECT 1 FROM menu_item i WHERE i.restaurant_id = 400101002
                AND NOT EXISTS (SELECT 1 FROM menu_item_variant v WHERE v.menu_item_id = i.menu_item_id)) THEN
        RAISE EXCEPTION 'Jumboking franchise 5 post-load check failed: a menu_item has no variant';
    END IF;

    RAISE NOTICE 'Jumboking franchise 5 loaded: % categories, % items, % variants, % prices', n_cat, n_item, n_var, n_price;
END
$post$;

COMMIT;

-- =====================================================================
-- REVIEW BLOCK - restaurant-level notes with no schema home, and structural questions
-- =====================================================================
--
-- CORRECTIONS APPLIED (see header notes 1, 10)
--
-- NOT LOADED (no schema column, or not part of the JSON menu content)
-- * "Price per person": "Rs.1-200" - see header note 11.
-- * Calorie / "Nutritional Analysis Per 100g" text under nearly every category:
--     MON - OG DOUBLE CHEESE BURGER: Cal 257.26 Kcal
--     TUE - MAC & CHEESE BURGER: Cal 257.69 Kcal
--     WED - PERI PERI NACHOS BURGER: Cal 271.19 Kcal
--     THU - BIG CRUNCH BURGER: Cal 230.19 Kcal
--     FRI - CRISPY VEG BURGER: Cal 208.25 Kcal
--     SAT - CLASSIC CHEESE BURST BURGER: Cal 313.01 Kcal
--     SUN - ZESTY PANEER BURGER: Cal 302.28 Kcal
--     THICKSHAKES @ ₹99/-: Chocolate Cal 108.63 Kcal; Cold Coffee Cal 160.77 Kcal; Oreo Cal 160.77 Kcal; Blueberry Cheesecake Cal 104.67 Kcal
--     FRIES: Regular Fries Cal 282.99 Kcal; Peri Peri Loaded Fries Cal 358.78 Kcal
-- * "*Pictures shown for representational purposes only. Actual product may vary." (FRIES).
-- * Marketing banner lines with no per-item/per-category home: JUMBOKING; FANTASTIC FRIDAYS; BUY ONE BURGER GET THE SAME BURGER Rs.50 ONLY; JUMBOKING; HAPPY BREAK; HAPPY PEOPLE
-- * "On-site services" (see header note 4) - no matching service_mode code; add a lookup row
--   in a separate script if this should be tracked distinctly from Dine-in.
--
-- STRUCTURAL NOTES
-- * "Meal"/"Combo"/"Burger" recur across all 7 weekday categories at different prices and are
--   deliberately left without a canonical_dish_id - see header note 7.
-- * "Buy One Burger Get The Same Burger" is not modeled as a bundle - see header note 6.
-- =====================================================================
