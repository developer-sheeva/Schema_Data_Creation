-- ============================================================================
-- HOTEL TAVAKKAL -- MENU INSERT SCRIPT (PostgreSQL)
-- establishment_id = restaurant_id = source_id = 400070013, all supplied directly in the
-- source JSON. Every child table has its own counter starting at 400070013001.
-- 19 categories, 326 menu items, 349 variants.
--
-- LOOKUP CASING: per explicit instruction, every lookup code is UPPERCASE except
-- cuisine tags (cuisine_ + lowercase), matching khaustan_lookup_data_seed_
-- KhaustanRestaurantMenu.sql exactly (protein_type: CHICKEN/MUTTON/SEAFOOD;
-- platform_tag: HALAL/NO_BEEF; delivery_provider: ZOMATO/SWIGGY). This script does
-- not insert into any lookup table -- resolves existing rows only.
-- HALAL and NO BEEF banners on the source menu -> restaurant_tag rows for both (read-only lookup).
-- Zomato and Swiggy named explicitly ('Order us on zomato / SWIGGY') -> restaurant_delivery_provider
-- rows for both (read-only lookup, charge amount unknown -- 'fixed' with no amount).
-- Friday closing 12:30 PM-1:45 PM per the menu's own note -> restaurant_hours has two slots on Friday,
-- one slot every other day.
-- 'Mutton Paya Soup' is printed '(Sunday)' -> menu_item_availability restricts it to Sunday only.
-- '(Full)'/'(Half)' suffixed pairs were merged into one menu_item with two variants throughout; quantity-only
-- suffixes like '(6pcs)'/'(3pcs)'/'(Boneless)' were kept as part of the dish name, not treated as variants.
-- 'Party Order' bulk items kept as their own standalone menu_items (not matched back to a-la-carte dishes,
-- since names differ -- e.g. 'Chicken Biryani (1.kg Rice & 1.kg Chicken)' is a distinct package, not a
-- portion of the regular 'Chicken Biryani').
--
-- 34 items flagged verification_status_code = 'needs_review'.
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

-- ----------------------------------------------------------------------
-- Establishment & restaurant
-- ----------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2,
                            locality, city, state, postal_code, country_code, latitude, longitude, status_code)
SELECT 400070013, 'Hotel Tavakkal', 'hotel tavakkal', 'Tavakkal Hotel, Bail Bazar, Old Kurla', 'Opp. Municipal Hospital',
       'Kurla', 'Mumbai', 'Maharashtra', '400070', 'IN', 19.085549089910963, 72.8807782603169, 'active'
WHERE NOT EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400070013);

INSERT INTO restaurant (restaurant_id, establishment_id, brand_id, display_name, normalized_name,
                         veg_nonveg_status, has_bar, bar_license_type, status_code, verification_status_code)
SELECT 400070013, 400070013, NULL, 'Hotel Tavakkal', 'hotel tavakkal',
       'veg_and_nonveg', FALSE, 'none', 'active', 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400070013);

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT * FROM (VALUES
    (400070013001, 400070013, '8097028059', TRUE),
    (400070013002, 400070013, '8097028057', FALSE)
) AS v WHERE NOT EXISTS (SELECT 1 FROM restaurant_phone WHERE restaurant_id = 400070013);

INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
SELECT * FROM (VALUES
    (400070013001, 400070013, 1, 1, '11:00'::time, '00:00'::time),
    (400070013002, 400070013, 2, 1, '11:00'::time, '00:00'::time),
    (400070013003, 400070013, 3, 1, '11:00'::time, '00:00'::time),
    (400070013004, 400070013, 4, 1, '11:00'::time, '00:00'::time),
    (400070013005, 400070013, 5, 1, '11:00'::time, '12:30'::time),
    (400070013006, 400070013, 5, 2, '13:45'::time, '00:00'::time),
    (400070013007, 400070013, 6, 1, '11:00'::time, '00:00'::time),
    (400070013008, 400070013, 7, 1, '11:00'::time, '00:00'::time)
) AS v WHERE NOT EXISTS (SELECT 1 FROM restaurant_hours WHERE restaurant_id = 400070013);

INSERT INTO source_record (source_id, source_type_code, source_uri)
SELECT 400070013, 'ai_menu_extraction', 'Tavakkal_Hotel_Menu_OCR.json'
WHERE NOT EXISTS (SELECT 1 FROM source_record WHERE source_id = 400070013);

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400070013001, 400070013, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
WHERE NOT EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400070013);

-- Restaurant-level tags (read-only lookup -- resolves existing platform_tag rows only)
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
SELECT v.id, 400070013, pt.tag_id, TRUE FROM (VALUES
    (400070013001, 'HALAL'),
    (400070013002, 'NO_BEEF')
) AS v(id, code) JOIN platform_tag pt ON pt.tag_code = v.code
WHERE NOT EXISTS (SELECT 1 FROM restaurant_tag WHERE restaurant_id = 400070013 AND tag_id = pt.tag_id);
DO $$ BEGIN
    IF (SELECT COUNT(*) FROM restaurant_tag WHERE restaurant_id = 400070013) < 2 THEN
        RAISE WARNING 'Expected 2 restaurant_tag rows for restaurant 400070013 but found fewer -- a platform_tag code was not found in the lookup (codes are case-sensitive).';
    END IF;
END $$;

-- Delivery providers (read-only lookup)
INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from)
SELECT 400070013001, 400070013, delivery_provider_id, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC') FROM delivery_provider WHERE provider_code = 'ZOMATO'
AND NOT EXISTS (SELECT 1 FROM restaurant_delivery_provider WHERE restaurant_id = 400070013 AND delivery_provider_id = (SELECT delivery_provider_id FROM delivery_provider WHERE provider_code = 'ZOMATO'));
INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from)
SELECT 400070013002, 400070013, delivery_provider_id, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC') FROM delivery_provider WHERE provider_code = 'SWIGGY'
AND NOT EXISTS (SELECT 1 FROM restaurant_delivery_provider WHERE restaurant_id = 400070013 AND delivery_provider_id = (SELECT delivery_provider_id FROM delivery_provider WHERE provider_code = 'SWIGGY'));
DO $$ BEGIN
    IF (SELECT COUNT(*) FROM restaurant_delivery_provider WHERE restaurant_id = 400070013) < 2 THEN
        RAISE WARNING 'Expected 2 restaurant_delivery_provider rows for restaurant 400070013 but found fewer -- a delivery_provider code was not found in the lookup (codes are case-sensitive).';
    END IF;
END $$;

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 400070013001, 400070013, 'A La Carte', 'a_la_carte'
WHERE NOT EXISTS (SELECT 1 FROM menu_board WHERE menu_board_id = 400070013001);

-- Menu categories (19, in source order)
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
SELECT * FROM (VALUES
    (400070013001, 400070013, 'Tandoor & Starter', 1),
    (400070013002, 400070013, 'Chinese Starter', 2),
    (400070013003, 400070013, 'Tavakkal Special Boneless', 3),
    (400070013004, 400070013, 'Chicken Main Course', 4),
    (400070013005, 400070013, 'Mutton Main Course', 5),
    (400070013006, 400070013, 'Prawns Main Course', 6),
    (400070013007, 400070013, 'Egg Main Course', 7),
    (400070013008, 400070013, 'Paneer Main Course', 8),
    (400070013009, 400070013, 'Vegetable Main Course', 9),
    (400070013010, 400070013, 'Special Thali', 10),
    (400070013011, 400070013, 'Roti Ki Tokri', 11),
    (400070013012, 400070013, 'Biryani / Rice / Pulao', 12),
    (400070013013, 400070013, 'Chinese Soup', 13),
    (400070013014, 400070013, 'Chinese Gravy', 14),
    (400070013015, 400070013, 'Chinese Rice', 15),
    (400070013016, 400070013, 'Kapsa Rice', 16),
    (400070013017, 400070013, 'Chinese Noodles', 17),
    (400070013018, 400070013, 'Hot & Cold Beverages', 18),
    (400070013019, 400070013, 'Party Order (Bulk)', 19)
) AS v WHERE NOT EXISTS (SELECT 1 FROM menu_category WHERE restaurant_id = 400070013);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT * FROM (VALUES
    (400070013, 400070013001, 400070013001, 1),
    (400070013, 400070013001, 400070013002, 2),
    (400070013, 400070013001, 400070013003, 3),
    (400070013, 400070013001, 400070013004, 4),
    (400070013, 400070013001, 400070013005, 5),
    (400070013, 400070013001, 400070013006, 6),
    (400070013, 400070013001, 400070013007, 7),
    (400070013, 400070013001, 400070013008, 8),
    (400070013, 400070013001, 400070013009, 9),
    (400070013, 400070013001, 400070013010, 10),
    (400070013, 400070013001, 400070013011, 11),
    (400070013, 400070013001, 400070013012, 12),
    (400070013, 400070013001, 400070013013, 13),
    (400070013, 400070013001, 400070013014, 14),
    (400070013, 400070013001, 400070013015, 15),
    (400070013, 400070013001, 400070013016, 16),
    (400070013, 400070013001, 400070013017, 17),
    (400070013, 400070013001, 400070013018, 18),
    (400070013, 400070013001, 400070013019, 19)
) AS v WHERE NOT EXISTS (SELECT 1 FROM menu_board_category WHERE restaurant_id = 400070013);

-- Canonical dishes (322 distinct names -- shared/global table)
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013001, 'Chicken Special Tandoori', 'chicken special tandoori', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken special tandoori');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013001, canonical_dish_id, 'en', 'Chicken Special Tandoori', 'chicken special tandoori', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken special tandoori' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken special tandoori' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013002, 'Chicken Tandoori', 'chicken tandoori', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013002, canonical_dish_id, 'en', 'Chicken Tandoori', 'chicken tandoori', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tandoori' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tandoori' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013003, 'Chicken Schezwan Tandoori', 'chicken schezwan tandoori', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan tandoori');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013003, canonical_dish_id, 'en', 'Chicken Schezwan Tandoori', 'chicken schezwan tandoori', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken schezwan tandoori' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken schezwan tandoori' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013004, 'Chicken Leg Tandoori', 'chicken leg tandoori', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken leg tandoori');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013004, canonical_dish_id, 'en', 'Chicken Leg Tandoori', 'chicken leg tandoori', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken leg tandoori' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken leg tandoori' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013005, 'Chicken Malai Kabab (6pcs)', 'chicken malai kabab (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai kabab (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013005, canonical_dish_id, 'en', 'Chicken Malai Kabab (6pcs)', 'chicken malai kabab (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken malai kabab (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken malai kabab (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013006, 'Chicken Banjara Kabab (6pcs)', 'chicken banjara kabab (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken banjara kabab (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013006, canonical_dish_id, 'en', 'Chicken Banjara Kabab (6pcs)', 'chicken banjara kabab (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken banjara kabab (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken banjara kabab (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013007, 'Chicken Reshmi Kabab (6pcs)', 'chicken reshmi kabab (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken reshmi kabab (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013007, canonical_dish_id, 'en', 'Chicken Reshmi Kabab (6pcs)', 'chicken reshmi kabab (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken reshmi kabab (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken reshmi kabab (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013008, 'Chicken Pahadi Kabab (6pcs)', 'chicken pahadi kabab (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi kabab (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013008, canonical_dish_id, 'en', 'Chicken Pahadi Kabab (6pcs)', 'chicken pahadi kabab (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken pahadi kabab (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken pahadi kabab (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013009, 'Chicken Tikka Dry (6pcs)', 'chicken tikka dry (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka dry (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013009, canonical_dish_id, 'en', 'Chicken Tikka Dry (6pcs)', 'chicken tikka dry (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tikka dry (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tikka dry (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013010, 'Chicken Schezwan Tikka (6pcs)', 'chicken schezwan tikka (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan tikka (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013010, canonical_dish_id, 'en', 'Chicken Schezwan Tikka (6pcs)', 'chicken schezwan tikka (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken schezwan tikka (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken schezwan tikka (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013011, 'Mutton Plain Fry (6pcs)', 'mutton plain fry (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton plain fry (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013011, canonical_dish_id, 'en', 'Mutton Plain Fry (6pcs)', 'mutton plain fry (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton plain fry (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton plain fry (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013012, 'Paneer Tikka Dry (6pcs)', 'paneer tikka dry (6pcs)', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka dry (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013012, canonical_dish_id, 'en', 'Paneer Tikka Dry (6pcs)', 'paneer tikka dry (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tikka dry (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka dry (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013013, 'Masala Papad', 'masala papad', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013013, canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary' FROM canonical_dish
WHERE normalized_name = 'masala papad' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'masala papad' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013014, 'Papad Fry & Roasted', 'papad fry & roasted', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'papad fry & roasted');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013014, canonical_dish_id, 'en', 'Papad Fry & Roasted', 'papad fry & roasted', 'primary' FROM canonical_dish
WHERE normalized_name = 'papad fry & roasted' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'papad fry & roasted' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013015, 'Chicken Crispy', 'chicken crispy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken crispy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013015, canonical_dish_id, 'en', 'Chicken Crispy', 'chicken crispy', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken crispy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken crispy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013016, 'Chicken Roasted Dry', 'chicken roasted dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken roasted dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013016, canonical_dish_id, 'en', 'Chicken Roasted Dry', 'chicken roasted dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken roasted dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken roasted dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013017, 'Chicken Bone Chilly Dry (8 pcs)', 'chicken bone chilly dry (8 pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken bone chilly dry (8 pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013017, canonical_dish_id, 'en', 'Chicken Bone Chilly Dry (8 pcs)', 'chicken bone chilly dry (8 pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken bone chilly dry (8 pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken bone chilly dry (8 pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013018, 'Chicken Lolipop Chatpata (6pcs)', 'chicken lolipop chatpata (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lolipop chatpata (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013018, canonical_dish_id, 'en', 'Chicken Lolipop Chatpata (6pcs)', 'chicken lolipop chatpata (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lolipop chatpata (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lolipop chatpata (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013019, 'Chicken Lolipop Dry', 'chicken lolipop dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lolipop dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013019, canonical_dish_id, 'en', 'Chicken Lolipop Dry', 'chicken lolipop dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lolipop dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lolipop dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013020, 'Chicken 65 Dry', 'chicken 65 dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65 dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013020, canonical_dish_id, 'en', 'Chicken 65 Dry', 'chicken 65 dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken 65 dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken 65 dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013021, 'Chicken Chilly Dry', 'chicken chilly dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013021, canonical_dish_id, 'en', 'Chicken Chilly Dry', 'chicken chilly dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chilly dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chilly dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013022, 'Chicken Manchurian Dry', 'chicken manchurian dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013022, canonical_dish_id, 'en', 'Chicken Manchurian Dry', 'chicken manchurian dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken manchurian dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken manchurian dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013023, 'Chicken Garlic Dry', 'chicken garlic dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken garlic dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013023, canonical_dish_id, 'en', 'Chicken Garlic Dry', 'chicken garlic dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken garlic dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken garlic dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013024, 'Chicken Schezwan Dry', 'chicken schezwan dry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013024, canonical_dish_id, 'en', 'Chicken Schezwan Dry', 'chicken schezwan dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken schezwan dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken schezwan dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013025, 'Mushroom Chilly Dry', 'mushroom chilly dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom chilly dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013025, canonical_dish_id, 'en', 'Mushroom Chilly Dry', 'mushroom chilly dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom chilly dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom chilly dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013026, 'Mushroom Schezwan Dry', 'mushroom schezwan dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom schezwan dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013026, canonical_dish_id, 'en', 'Mushroom Schezwan Dry', 'mushroom schezwan dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom schezwan dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom schezwan dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013027, 'Mushroom Garlic Dry', 'mushroom garlic dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom garlic dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013027, canonical_dish_id, 'en', 'Mushroom Garlic Dry', 'mushroom garlic dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom garlic dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom garlic dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013028, 'Paneer Crispy', 'paneer crispy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer crispy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013028, canonical_dish_id, 'en', 'Paneer Crispy', 'paneer crispy', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer crispy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer crispy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013029, 'Paneer 65 Dry', 'paneer 65 dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65 dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013029, canonical_dish_id, 'en', 'Paneer 65 Dry', 'paneer 65 dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer 65 dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer 65 dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013030, 'Paneer Chilly Dry', 'paneer chilly dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013030, canonical_dish_id, 'en', 'Paneer Chilly Dry', 'paneer chilly dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer chilly dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer chilly dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013031, 'Paneer Manchurian Dry', 'paneer manchurian dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer manchurian dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013031, canonical_dish_id, 'en', 'Paneer Manchurian Dry', 'paneer manchurian dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer manchurian dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer manchurian dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013032, 'Paneer Garlic Dry', 'paneer garlic dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer garlic dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013032, canonical_dish_id, 'en', 'Paneer Garlic Dry', 'paneer garlic dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer garlic dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer garlic dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013033, 'Paneer Schezwan Dry', 'paneer schezwan dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013033, canonical_dish_id, 'en', 'Paneer Schezwan Dry', 'paneer schezwan dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer schezwan dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer schezwan dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013034, 'Veg. Crispy', 'veg. crispy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. crispy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013034, canonical_dish_id, 'en', 'Veg. Crispy', 'veg. crispy', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. crispy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. crispy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013035, 'Veg. 65 Dry', 'veg. 65 dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. 65 dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013035, canonical_dish_id, 'en', 'Veg. 65 Dry', 'veg. 65 dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. 65 dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. 65 dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013036, 'Veg. Chilly Dry', 'veg. chilly dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013036, canonical_dish_id, 'en', 'Veg. Chilly Dry', 'veg. chilly dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. chilly dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. chilly dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013037, 'Veg. Manchurian Dry', 'veg. manchurian dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013037, canonical_dish_id, 'en', 'Veg. Manchurian Dry', 'veg. manchurian dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. manchurian dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. manchurian dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013038, 'Veg. Garlic Dry', 'veg. garlic dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. garlic dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013038, canonical_dish_id, 'en', 'Veg. Garlic Dry', 'veg. garlic dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. garlic dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. garlic dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013039, 'Veg. Schezwan Dry', 'veg. schezwan dry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan dry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013039, canonical_dish_id, 'en', 'Veg. Schezwan Dry', 'veg. schezwan dry', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. schezwan dry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. schezwan dry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013040, 'Prawns Kolwada', 'prawns kolwada', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns kolwada');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013040, canonical_dish_id, 'en', 'Prawns Kolwada', 'prawns kolwada', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns kolwada' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns kolwada' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013041, 'Chicken Aflatoon (Jumbo)', 'chicken aflatoon (jumbo)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken aflatoon (jumbo)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013041, canonical_dish_id, 'en', 'Chicken Aflatoon (Jumbo)', 'chicken aflatoon (jumbo)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken aflatoon (jumbo)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken aflatoon (jumbo)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013042, 'Chicken Maharaja (Jumbo)', 'chicken maharaja (jumbo)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken maharaja (jumbo)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013042, canonical_dish_id, 'en', 'Chicken Maharaja (Jumbo)', 'chicken maharaja (jumbo)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken maharaja (jumbo)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken maharaja (jumbo)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013043, 'Chicken Lahori (Jumbo)', 'chicken lahori (jumbo)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lahori (jumbo)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013043, canonical_dish_id, 'en', 'Chicken Lahori (Jumbo)', 'chicken lahori (jumbo)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lahori (jumbo)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lahori (jumbo)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013044, 'Chicken Special Tavakkal', 'chicken special tavakkal', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken special tavakkal');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013044, canonical_dish_id, 'en', 'Chicken Special Tavakkal', 'chicken special tavakkal', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken special tavakkal' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken special tavakkal' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013045, 'Chicken Peshawari', 'chicken peshawari', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken peshawari');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013045, canonical_dish_id, 'en', 'Chicken Peshawari', 'chicken peshawari', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken peshawari' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken peshawari' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013046, 'Chicken Lara', 'chicken lara', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lara');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013046, canonical_dish_id, 'en', 'Chicken Lara', 'chicken lara', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lara' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lara' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013047, 'Chicken Akbari', 'chicken akbari', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken akbari');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013047, canonical_dish_id, 'en', 'Chicken Akbari', 'chicken akbari', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken akbari' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken akbari' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013048, 'Chicken Boneless Handi', 'chicken boneless handi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken boneless handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013048, canonical_dish_id, 'en', 'Chicken Boneless Handi', 'chicken boneless handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken boneless handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken boneless handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013049, 'Chicken Lajawab', 'chicken lajawab', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lajawab');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013049, canonical_dish_id, 'en', 'Chicken Lajawab', 'chicken lajawab', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lajawab' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lajawab' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013050, 'Chicken Lucknowi', 'chicken lucknowi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lucknowi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013050, canonical_dish_id, 'en', 'Chicken Lucknowi', 'chicken lucknowi', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lucknowi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lucknowi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013051, 'Chicken Haryali', 'chicken haryali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken haryali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013051, canonical_dish_id, 'en', 'Chicken Haryali', 'chicken haryali', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken haryali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken haryali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013052, 'Chicken Mumtaz', 'chicken mumtaz', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken mumtaz');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013052, canonical_dish_id, 'en', 'Chicken Mumtaz', 'chicken mumtaz', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken mumtaz' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken mumtaz' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013053, 'Chicken Zaitoon', 'chicken zaitoon', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken zaitoon');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013053, canonical_dish_id, 'en', 'Chicken Zaitoon', 'chicken zaitoon', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken zaitoon' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken zaitoon' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013054, 'Chicken Zaika', 'chicken zaika', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken zaika');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013054, canonical_dish_id, 'en', 'Chicken Zaika', 'chicken zaika', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken zaika' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken zaika' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013055, 'Chicken Chulbul', 'chicken chulbul', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chulbul');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013055, canonical_dish_id, 'en', 'Chicken Chulbul', 'chicken chulbul', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chulbul' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chulbul' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013056, 'Chicken Methi', 'chicken methi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken methi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013056, canonical_dish_id, 'en', 'Chicken Methi', 'chicken methi', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken methi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken methi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013057, 'Chicken Kothmiri', 'chicken kothmiri', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kothmiri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013057, canonical_dish_id, 'en', 'Chicken Kothmiri', 'chicken kothmiri', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken kothmiri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken kothmiri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013058, 'Chicken Chingari', 'chicken chingari', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chingari');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013058, canonical_dish_id, 'en', 'Chicken Chingari', 'chicken chingari', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chingari' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chingari' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013059, 'Chicken Nawabi', 'chicken nawabi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken nawabi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013059, canonical_dish_id, 'en', 'Chicken Nawabi', 'chicken nawabi', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken nawabi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken nawabi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013060, 'Chicken Hydrabadi', 'chicken hydrabadi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013060, canonical_dish_id, 'en', 'Chicken Hydrabadi', 'chicken hydrabadi', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hydrabadi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hydrabadi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013061, 'Chicken Patiyala', 'chicken patiyala', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken patiyala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013061, canonical_dish_id, 'en', 'Chicken Patiyala', 'chicken patiyala', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken patiyala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken patiyala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013062, 'Chicken Tawa', 'chicken tawa', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tawa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013062, canonical_dish_id, 'en', 'Chicken Tawa', 'chicken tawa', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tawa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tawa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013063, 'Butter Chicken', 'butter chicken', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013063, canonical_dish_id, 'en', 'Butter Chicken', 'butter chicken', 'primary' FROM canonical_dish
WHERE normalized_name = 'butter chicken' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter chicken' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013064, 'Chicken Angara', 'chicken angara', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken angara');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013064, canonical_dish_id, 'en', 'Chicken Angara', 'chicken angara', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken angara' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken angara' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013065, 'Chicken Balti', 'chicken balti', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken balti');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013065, canonical_dish_id, 'en', 'Chicken Balti', 'chicken balti', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken balti' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken balti' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013066, 'Chicken Afgani', 'chicken afgani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afgani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013066, canonical_dish_id, 'en', 'Chicken Afgani', 'chicken afgani', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken afgani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken afgani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013067, 'Chicken Lazeez', 'chicken lazeez', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lazeez');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013067, canonical_dish_id, 'en', 'Chicken Lazeez', 'chicken lazeez', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lazeez' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lazeez' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013068, 'Chicken Tikka Masala (3pcs)', 'chicken tikka masala (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka masala (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013068, canonical_dish_id, 'en', 'Chicken Tikka Masala (3pcs)', 'chicken tikka masala (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tikka masala (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tikka masala (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013069, 'Chicken Tikka Handi (3pcs)', 'chicken tikka handi (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka handi (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013069, canonical_dish_id, 'en', 'Chicken Tikka Handi (3pcs)', 'chicken tikka handi (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tikka handi (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tikka handi (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013070, 'Chicken Chatpata', 'chicken chatpata', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chatpata');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013070, canonical_dish_id, 'en', 'Chicken Chatpata', 'chicken chatpata', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chatpata' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chatpata' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013071, 'Chicken Kheema', 'chicken kheema', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kheema');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013071, canonical_dish_id, 'en', 'Chicken Kheema', 'chicken kheema', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken kheema' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken kheema' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013072, 'Chicken Murg Musallam', 'chicken murg musallam', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken murg musallam');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013072, canonical_dish_id, 'en', 'Chicken Murg Musallam', 'chicken murg musallam', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken murg musallam' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken murg musallam' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013073, 'Chicken Sukka (6pcs)', 'chicken sukka (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sukka (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013073, canonical_dish_id, 'en', 'Chicken Sukka (6pcs)', 'chicken sukka (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken sukka (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken sukka (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013074, 'Chicken Leg Masala', 'chicken leg masala', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken leg masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013074, canonical_dish_id, 'en', 'Chicken Leg Masala', 'chicken leg masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken leg masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken leg masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013075, 'Chicken Handi (Full)(8pcs)', 'chicken handi (full)(8pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi (full)(8pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013075, canonical_dish_id, 'en', 'Chicken Handi (Full)(8pcs)', 'chicken handi (full)(8pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken handi (full)(8pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken handi (full)(8pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013076, 'Chicken Handi (Half)(4pcs)', 'chicken handi (half)(4pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi (half)(4pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013076, canonical_dish_id, 'en', 'Chicken Handi (Half)(4pcs)', 'chicken handi (half)(4pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken handi (half)(4pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken handi (half)(4pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013077, 'Chicken Kadai (3pcs)', 'chicken kadai (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kadai (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013077, canonical_dish_id, 'en', 'Chicken Kadai (3pcs)', 'chicken kadai (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken kadai (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken kadai (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013078, 'Chicken Moghlai (3pcs)', 'chicken moghlai (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken moghlai (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013078, canonical_dish_id, 'en', 'Chicken Moghlai (3pcs)', 'chicken moghlai (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken moghlai (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken moghlai (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013079, 'Chicken Rashida (3pcs)', 'chicken rashida (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken rashida (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013079, canonical_dish_id, 'en', 'Chicken Rashida (3pcs)', 'chicken rashida (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken rashida (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken rashida (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013080, 'Chicken Kolhapuri (3pcs)', 'chicken kolhapuri (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013080, canonical_dish_id, 'en', 'Chicken Kolhapuri (3pcs)', 'chicken kolhapuri (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken kolhapuri (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken kolhapuri (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013081, 'Chicken Hangama (3pcs)', 'chicken hangama (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hangama (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013081, canonical_dish_id, 'en', 'Chicken Hangama (3pcs)', 'chicken hangama (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hangama (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hangama (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013082, 'Chicken Toofani (3pcs)', 'chicken toofani (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken toofani (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013082, canonical_dish_id, 'en', 'Chicken Toofani (3pcs)', 'chicken toofani (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken toofani (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken toofani (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013083, 'Chicken Masala Fry (2pcs)', 'chicken masala fry (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala fry (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013083, canonical_dish_id, 'en', 'Chicken Masala Fry (2pcs)', 'chicken masala fry (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken masala fry (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken masala fry (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013084, 'Chicken Korma (2pcs)', 'chicken korma (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken korma (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013084, canonical_dish_id, 'en', 'Chicken Korma (2pcs)', 'chicken korma (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken korma (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken korma (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013085, 'Mutton Special Tavakkal (Boneless)', 'mutton special tavakkal (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton special tavakkal (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013085, canonical_dish_id, 'en', 'Mutton Special Tavakkal (Boneless)', 'mutton special tavakkal (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton special tavakkal (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton special tavakkal (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013086, 'Mutton Dabba Gosht (Boneless)', 'mutton dabba gosht (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dabba gosht (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013086, canonical_dish_id, 'en', 'Mutton Dabba Gosht (Boneless)', 'mutton dabba gosht (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton dabba gosht (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton dabba gosht (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013087, 'Mutton Chingari (Boneless)', 'mutton chingari (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton chingari (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013087, canonical_dish_id, 'en', 'Mutton Chingari (Boneless)', 'mutton chingari (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton chingari (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton chingari (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013088, 'Mutton Lazeez (Boneless)', 'mutton lazeez (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lazeez (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013088, canonical_dish_id, 'en', 'Mutton Lazeez (Boneless)', 'mutton lazeez (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton lazeez (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton lazeez (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013089, 'Mutton Chatpata (Boneless)', 'mutton chatpata (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton chatpata (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013089, canonical_dish_id, 'en', 'Mutton Chatpata (Boneless)', 'mutton chatpata (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton chatpata (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton chatpata (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013090, 'Mutton Tawa (Boneless)', 'mutton tawa (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton tawa (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013090, canonical_dish_id, 'en', 'Mutton Tawa (Boneless)', 'mutton tawa (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton tawa (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton tawa (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013091, 'Mutton Angara (Boneless)', 'mutton angara (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton angara (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013091, canonical_dish_id, 'en', 'Mutton Angara (Boneless)', 'mutton angara (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton angara (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton angara (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013092, 'Mutton Nawabi (Boneless)', 'mutton nawabi (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton nawabi (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013092, canonical_dish_id, 'en', 'Mutton Nawabi (Boneless)', 'mutton nawabi (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton nawabi (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton nawabi (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013093, 'Mutton Afghani (Boneless)', 'mutton afghani (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton afghani (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013093, canonical_dish_id, 'en', 'Mutton Afghani (Boneless)', 'mutton afghani (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton afghani (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton afghani (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013094, 'Mutton Balti (Boneless)', 'mutton balti (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton balti (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013094, canonical_dish_id, 'en', 'Mutton Balti (Boneless)', 'mutton balti (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton balti (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton balti (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013095, 'Mutton Hydrabadi (Boneless)', 'mutton hydrabadi (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hydrabadi (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013095, canonical_dish_id, 'en', 'Mutton Hydrabadi (Boneless)', 'mutton hydrabadi (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton hydrabadi (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton hydrabadi (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013096, 'Mutton Haryali (Boneless)', 'mutton haryali (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton haryali (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013096, canonical_dish_id, 'en', 'Mutton Haryali (Boneless)', 'mutton haryali (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton haryali (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton haryali (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013097, 'Mutton Lajawab (Boneless)', 'mutton lajawab (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lajawab (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013097, canonical_dish_id, 'en', 'Mutton Lajawab (Boneless)', 'mutton lajawab (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton lajawab (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton lajawab (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013098, 'Mutton Zaika (Boneless)', 'mutton zaika (boneless)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton zaika (boneless)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013098, canonical_dish_id, 'en', 'Mutton Zaika (Boneless)', 'mutton zaika (boneless)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton zaika (boneless)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton zaika (boneless)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013099, 'Mutton Handi (Full) (6pcs)', 'mutton handi (full) (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi (full) (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013099, canonical_dish_id, 'en', 'Mutton Handi (Full) (6pcs)', 'mutton handi (full) (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton handi (full) (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton handi (full) (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013100, 'Mutton Handi (Half) (3pcs)', 'mutton handi (half) (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi (half) (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013100, canonical_dish_id, 'en', 'Mutton Handi (Half) (3pcs)', 'mutton handi (half) (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton handi (half) (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton handi (half) (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013101, 'Mutton Kadai (3pcs)', 'mutton kadai (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kadai (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013101, canonical_dish_id, 'en', 'Mutton Kadai (3pcs)', 'mutton kadai (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton kadai (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton kadai (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013102, 'Mutton Moghlai (3pcs)', 'mutton moghlai (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton moghlai (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013102, canonical_dish_id, 'en', 'Mutton Moghlai (3pcs)', 'mutton moghlai (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton moghlai (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton moghlai (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013103, 'Mutton Rashida (3pcs)', 'mutton rashida (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rashida (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013103, canonical_dish_id, 'en', 'Mutton Rashida (3pcs)', 'mutton rashida (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton rashida (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton rashida (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013104, 'Mutton Do Pyaza (3pcs)', 'mutton do pyaza (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton do pyaza (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013104, canonical_dish_id, 'en', 'Mutton Do Pyaza (3pcs)', 'mutton do pyaza (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton do pyaza (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton do pyaza (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013105, 'Mutton Kolhapuri (3pcs)', 'mutton kolhapuri (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013105, canonical_dish_id, 'en', 'Mutton Kolhapuri (3pcs)', 'mutton kolhapuri (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton kolhapuri (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton kolhapuri (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013106, 'Mutton Toofani (3pcs)', 'mutton toofani (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton toofani (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013106, canonical_dish_id, 'en', 'Mutton Toofani (3pcs)', 'mutton toofani (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton toofani (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton toofani (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013107, 'Mutton Palak (2pcs)', 'mutton palak (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton palak (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013107, canonical_dish_id, 'en', 'Mutton Palak (2pcs)', 'mutton palak (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton palak (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton palak (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013108, 'Mutton Masala Fry (2pcs)', 'mutton masala fry (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala fry (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013108, canonical_dish_id, 'en', 'Mutton Masala Fry (2pcs)', 'mutton masala fry (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton masala fry (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton masala fry (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013109, 'Mutton Korma (2pcs)', 'mutton korma (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton korma (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013109, canonical_dish_id, 'en', 'Mutton Korma (2pcs)', 'mutton korma (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton korma (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton korma (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013110, 'Mutton Dal Ghost (2pcs)', 'mutton dal ghost (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dal ghost (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013110, canonical_dish_id, 'en', 'Mutton Dal Ghost (2pcs)', 'mutton dal ghost (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton dal ghost (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton dal ghost (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013111, 'Mutton Kheema', 'mutton kheema', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013111, canonical_dish_id, 'en', 'Mutton Kheema', 'mutton kheema', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton kheema' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton kheema' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013112, 'Mutton Kheema Fry', 'mutton kheema fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013112, canonical_dish_id, 'en', 'Mutton Kheema Fry', 'mutton kheema fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton kheema fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton kheema fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013113, 'Mutton Kheema Gotala', 'mutton kheema gotala', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema gotala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013113, canonical_dish_id, 'en', 'Mutton Kheema Gotala', 'mutton kheema gotala', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton kheema gotala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton kheema gotala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013114, 'Mutton Brain Masala Fry', 'mutton brain masala fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton brain masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013114, canonical_dish_id, 'en', 'Mutton Brain Masala Fry', 'mutton brain masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton brain masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton brain masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013115, 'Mutton Brain Bhurji', 'mutton brain bhurji', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton brain bhurji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013115, canonical_dish_id, 'en', 'Mutton Brain Bhurji', 'mutton brain bhurji', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton brain bhurji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton brain bhurji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013116, 'Mutton Paya Soup', 'mutton paya soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton paya soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013116, canonical_dish_id, 'en', 'Mutton Paya Soup', 'mutton paya soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton paya soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton paya soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013117, 'Prawns Special Tavakkal', 'prawns special tavakkal', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns special tavakkal');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013117, canonical_dish_id, 'en', 'Prawns Special Tavakkal', 'prawns special tavakkal', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns special tavakkal' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns special tavakkal' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013118, 'Prawns Tawa', 'prawns tawa', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns tawa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013118, canonical_dish_id, 'en', 'Prawns Tawa', 'prawns tawa', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns tawa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns tawa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013119, 'Prawns Angara', 'prawns angara', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns angara');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013119, canonical_dish_id, 'en', 'Prawns Angara', 'prawns angara', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns angara' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns angara' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013120, 'Prawns Chingari', 'prawns chingari', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chingari');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013120, canonical_dish_id, 'en', 'Prawns Chingari', 'prawns chingari', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns chingari' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns chingari' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013121, 'Prawns Handi', 'prawns handi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013121, canonical_dish_id, 'en', 'Prawns Handi', 'prawns handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013122, 'Prawns Masala Fry', 'prawns masala fry', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013122, canonical_dish_id, 'en', 'Prawns Masala Fry', 'prawns masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013123, 'Egg Masala Fry (2 Egg)', 'egg masala fry (2 egg)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala fry (2 egg)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013123, canonical_dish_id, 'en', 'Egg Masala Fry (2 Egg)', 'egg masala fry (2 egg)', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg masala fry (2 egg)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg masala fry (2 egg)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013124, 'Egg Curry (2 Egg)', 'egg curry (2 egg)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg curry (2 egg)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013124, canonical_dish_id, 'en', 'Egg Curry (2 Egg)', 'egg curry (2 egg)', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg curry (2 egg)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg curry (2 egg)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013125, 'Egg Bhurji (2 Egg)', 'egg bhurji (2 egg)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg bhurji (2 egg)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013125, canonical_dish_id, 'en', 'Egg Bhurji (2 Egg)', 'egg bhurji (2 egg)', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg bhurji (2 egg)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg bhurji (2 egg)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013126, 'Egg Omlet (2 Egg)', 'egg omlet (2 egg)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg omlet (2 egg)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013126, canonical_dish_id, 'en', 'Egg Omlet (2 Egg)', 'egg omlet (2 egg)', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg omlet (2 egg)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg omlet (2 egg)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013127, 'Egg Half Fry (2 Egg)', 'egg half fry (2 egg)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg half fry (2 egg)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013127, canonical_dish_id, 'en', 'Egg Half Fry (2 Egg)', 'egg half fry (2 egg)', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg half fry (2 egg)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg half fry (2 egg)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013128, 'Boiled Egg (1pcs)', 'boiled egg (1pcs)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boiled egg (1pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013128, canonical_dish_id, 'en', 'Boiled Egg (1pcs)', 'boiled egg (1pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'boiled egg (1pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'boiled egg (1pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013129, 'Paneer Special Tavakkal', 'paneer special tavakkal', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer special tavakkal');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013129, canonical_dish_id, 'en', 'Paneer Special Tavakkal', 'paneer special tavakkal', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer special tavakkal' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer special tavakkal' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013130, 'Paneer Tawa', 'paneer tawa', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tawa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013130, canonical_dish_id, 'en', 'Paneer Tawa', 'paneer tawa', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tawa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tawa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013131, 'Paneer Chatpata', 'paneer chatpata', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chatpata');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013131, canonical_dish_id, 'en', 'Paneer Chatpata', 'paneer chatpata', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer chatpata' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer chatpata' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013132, 'Paneer Angara', 'paneer angara', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer angara');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013132, canonical_dish_id, 'en', 'Paneer Angara', 'paneer angara', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer angara' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer angara' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013133, 'Paneer Lazeez', 'paneer lazeez', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lazeez');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013133, canonical_dish_id, 'en', 'Paneer Lazeez', 'paneer lazeez', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer lazeez' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer lazeez' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013134, 'Paneer Chingari', 'paneer chingari', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chingari');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013134, canonical_dish_id, 'en', 'Paneer Chingari', 'paneer chingari', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer chingari' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer chingari' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013135, 'Paneer Nawabi', 'paneer nawabi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer nawabi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013135, canonical_dish_id, 'en', 'Paneer Nawabi', 'paneer nawabi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer nawabi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer nawabi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013136, 'Paneer Harbhara', 'paneer harbhara', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer harbhara');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013136, canonical_dish_id, 'en', 'Paneer Harbhara', 'paneer harbhara', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer harbhara' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer harbhara' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013137, 'Paneer Lajawab', 'paneer lajawab', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lajawab');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013137, canonical_dish_id, 'en', 'Paneer Lajawab', 'paneer lajawab', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer lajawab' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer lajawab' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013138, 'Paneer Hydrabadi', 'paneer hydrabadi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hydrabadi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013138, canonical_dish_id, 'en', 'Paneer Hydrabadi', 'paneer hydrabadi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer hydrabadi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer hydrabadi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013139, 'Paneer Methi', 'paneer methi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer methi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013139, canonical_dish_id, 'en', 'Paneer Methi', 'paneer methi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer methi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer methi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013140, 'Paneer Tikka Masala Fry', 'paneer tikka masala fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013140, canonical_dish_id, 'en', 'Paneer Tikka Masala Fry', 'paneer tikka masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tikka masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013141, 'Paneer Kolhapuri', 'paneer kolhapuri', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kolhapuri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013141, canonical_dish_id, 'en', 'Paneer Kolhapuri', 'paneer kolhapuri', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer kolhapuri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer kolhapuri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013142, 'Paneer Kadai', 'paneer kadai', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013142, canonical_dish_id, 'en', 'Paneer Kadai', 'paneer kadai', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer kadai' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer kadai' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013143, 'Paneer Handi', 'paneer handi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013143, canonical_dish_id, 'en', 'Paneer Handi', 'paneer handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013144, 'Paneer Tikka Handi', 'paneer tikka handi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013144, canonical_dish_id, 'en', 'Paneer Tikka Handi', 'paneer tikka handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tikka handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013145, 'Paneer Makhanwala', 'paneer makhanwala', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhanwala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013145, canonical_dish_id, 'en', 'Paneer Makhanwala', 'paneer makhanwala', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer makhanwala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer makhanwala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013146, 'Shahi Paneer', 'shahi paneer', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shahi paneer');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013146, canonical_dish_id, 'en', 'Shahi Paneer', 'shahi paneer', 'primary' FROM canonical_dish
WHERE normalized_name = 'shahi paneer' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'shahi paneer' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013147, 'Paneer Lahori (Jumbo)', 'paneer lahori (jumbo)', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lahori (jumbo)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013147, canonical_dish_id, 'en', 'Paneer Lahori (Jumbo)', 'paneer lahori (jumbo)', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer lahori (jumbo)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer lahori (jumbo)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013148, 'Paneer Maharaja (Jumbo)', 'paneer maharaja (jumbo)', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer maharaja (jumbo)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013148, canonical_dish_id, 'en', 'Paneer Maharaja (Jumbo)', 'paneer maharaja (jumbo)', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer maharaja (jumbo)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer maharaja (jumbo)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013149, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mushroom masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013149, canonical_dish_id, 'en', 'Paneer Mushroom Masala', 'paneer mushroom masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer mushroom masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer mushroom masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013150, 'Paneer Matar', 'paneer matar', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer matar');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013150, canonical_dish_id, 'en', 'Paneer Matar', 'paneer matar', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer matar' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer matar' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013151, 'Paneer Palak', 'paneer palak', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer palak');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013151, canonical_dish_id, 'en', 'Paneer Palak', 'paneer palak', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer palak' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer palak' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013152, 'Paneer Butter Masala', 'paneer butter masala', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer butter masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013152, canonical_dish_id, 'en', 'Paneer Butter Masala', 'paneer butter masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer butter masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer butter masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013153, 'Paneer Masala Fry', 'paneer masala fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013153, canonical_dish_id, 'en', 'Paneer Masala Fry', 'paneer masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013154, 'Paneer Bhurji', 'paneer bhurji', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer bhurji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013154, canonical_dish_id, 'en', 'Paneer Bhurji', 'paneer bhurji', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer bhurji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer bhurji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013155, 'Mushroom Masala Fry', 'mushroom masala fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013155, canonical_dish_id, 'en', 'Mushroom Masala Fry', 'mushroom masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013156, 'Veg. Special Tavakkal', 'veg. special tavakkal', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. special tavakkal');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013156, canonical_dish_id, 'en', 'Veg. Special Tavakkal', 'veg. special tavakkal', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. special tavakkal' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. special tavakkal' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013157, 'Veg. Angara', 'veg. angara', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. angara');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013157, canonical_dish_id, 'en', 'Veg. Angara', 'veg. angara', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. angara' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. angara' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013158, 'Veg. Lazeez', 'veg. lazeez', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. lazeez');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013158, canonical_dish_id, 'en', 'Veg. Lazeez', 'veg. lazeez', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. lazeez' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. lazeez' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013159, 'Veg. Tawa', 'veg. tawa', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. tawa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013159, canonical_dish_id, 'en', 'Veg. Tawa', 'veg. tawa', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. tawa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. tawa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013160, 'Veg. Hydrabadi', 'veg. hydrabadi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hydrabadi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013160, canonical_dish_id, 'en', 'Veg. Hydrabadi', 'veg. hydrabadi', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. hydrabadi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. hydrabadi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013161, 'Veg. Kadai', 'veg. kadai', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kadai');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013161, canonical_dish_id, 'en', 'Veg. Kadai', 'veg. kadai', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. kadai' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. kadai' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013162, 'Veg. Handi', 'veg. handi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013162, canonical_dish_id, 'en', 'Veg. Handi', 'veg. handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013163, 'Veg. Makhanwala', 'veg. makhanwala', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. makhanwala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013163, canonical_dish_id, 'en', 'Veg. Makhanwala', 'veg. makhanwala', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. makhanwala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. makhanwala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013164, 'Veg. Kolhapuri', 'veg. kolhapuri', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kolhapuri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013164, canonical_dish_id, 'en', 'Veg. Kolhapuri', 'veg. kolhapuri', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. kolhapuri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. kolhapuri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013165, 'Kaju Masala', 'kaju masala', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013165, canonical_dish_id, 'en', 'Kaju Masala', 'kaju masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'kaju masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kaju masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013166, 'Bhindi Masala Fry', 'bhindi masala fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhindi masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013166, canonical_dish_id, 'en', 'Bhindi Masala Fry', 'bhindi masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'bhindi masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'bhindi masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013167, 'Mix Vegetable Fry', 'mix vegetable fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix vegetable fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013167, canonical_dish_id, 'en', 'Mix Vegetable Fry', 'mix vegetable fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'mix vegetable fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix vegetable fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013168, 'Aloo Palak Fry', 'aloo palak fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo palak fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013168, canonical_dish_id, 'en', 'Aloo Palak Fry', 'aloo palak fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'aloo palak fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'aloo palak fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013169, 'Aloo Matar Fry', 'aloo matar fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo matar fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013169, canonical_dish_id, 'en', 'Aloo Matar Fry', 'aloo matar fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'aloo matar fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'aloo matar fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013170, 'Masoor Masala / Aloo Masoor', 'masoor masala / aloo masoor', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masoor masala / aloo masoor');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013170, canonical_dish_id, 'en', 'Masoor Masala / Aloo Masoor', 'masoor masala / aloo masoor', 'primary' FROM canonical_dish
WHERE normalized_name = 'masoor masala / aloo masoor' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'masoor masala / aloo masoor' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013171, 'Chana Masala Fry', 'chana masala fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013171, canonical_dish_id, 'en', 'Chana Masala Fry', 'chana masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'chana masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chana masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013172, 'Sev Bhaji', 'sev bhaji', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sev bhaji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013172, canonical_dish_id, 'en', 'Sev Bhaji', 'sev bhaji', 'primary' FROM canonical_dish
WHERE normalized_name = 'sev bhaji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sev bhaji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013173, 'Shahi Dal', 'shahi dal', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shahi dal');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013173, canonical_dish_id, 'en', 'Shahi Dal', 'shahi dal', 'primary' FROM canonical_dish
WHERE normalized_name = 'shahi dal' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'shahi dal' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013174, 'Dal Tadka', 'dal tadka', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013174, canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal tadka' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal tadka' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013175, 'Butter Dal Fry', 'butter dal fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter dal fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013175, canonical_dish_id, 'en', 'Butter Dal Fry', 'butter dal fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'butter dal fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter dal fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013176, 'Dal Fry', 'dal fry', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013176, canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013177, 'Plain Gravy', 'plain gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013177, canonical_dish_id, 'en', 'Plain Gravy', 'plain gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'plain gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'plain gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013178, 'Today Special Bhaji', 'today special bhaji', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'today special bhaji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013178, canonical_dish_id, 'en', 'Today Special Bhaji', 'today special bhaji', 'primary' FROM canonical_dish
WHERE normalized_name = 'today special bhaji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'today special bhaji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013179, 'Chicken Thali', 'chicken thali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013179, canonical_dish_id, 'en', 'Chicken Thali', 'chicken thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013180, 'Mutton Thali', 'mutton thali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013180, canonical_dish_id, 'en', 'Mutton Thali', 'mutton thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013181, 'Veg. Thali', 'veg. thali', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013181, canonical_dish_id, 'en', 'Veg. Thali', 'veg. thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013182, 'Veg. Special Thali', 'veg. special thali', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. special thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013182, canonical_dish_id, 'en', 'Veg. Special Thali', 'veg. special thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. special thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. special thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013183, 'Paneer Tikka Thali', 'paneer tikka thali', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013183, canonical_dish_id, 'en', 'Paneer Tikka Thali', 'paneer tikka thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tikka thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013184, 'Paneer Thali', 'paneer thali', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013184, canonical_dish_id, 'en', 'Paneer Thali', 'paneer thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013185, 'Prawns Thali', 'prawns thali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns thali');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013185, canonical_dish_id, 'en', 'Prawns Thali', 'prawns thali', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns thali' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns thali' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013186, 'Chapati', 'chapati', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chapati');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013186, canonical_dish_id, 'en', 'Chapati', 'chapati', 'primary' FROM canonical_dish
WHERE normalized_name = 'chapati' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chapati' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013187, 'Butter Chapati', 'butter chapati', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chapati');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013187, canonical_dish_id, 'en', 'Butter Chapati', 'butter chapati', 'primary' FROM canonical_dish
WHERE normalized_name = 'butter chapati' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter chapati' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013188, 'Tandoori Roti', 'tandoori roti', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013188, canonical_dish_id, 'en', 'Tandoori Roti', 'tandoori roti', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori roti' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori roti' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013189, 'Tandoori Butter Roti', 'tandoori butter roti', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter roti');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013189, canonical_dish_id, 'en', 'Tandoori Butter Roti', 'tandoori butter roti', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori butter roti' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori butter roti' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013190, 'Tandoori Butter Paratha', 'tandoori butter paratha', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter paratha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013190, canonical_dish_id, 'en', 'Tandoori Butter Paratha', 'tandoori butter paratha', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori butter paratha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori butter paratha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013191, 'Tandoori Butter Naan', 'tandoori butter naan', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter naan');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013191, canonical_dish_id, 'en', 'Tandoori Butter Naan', 'tandoori butter naan', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori butter naan' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori butter naan' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013192, 'Tandoori Butter Kulcha', 'tandoori butter kulcha', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter kulcha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013192, canonical_dish_id, 'en', 'Tandoori Butter Kulcha', 'tandoori butter kulcha', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori butter kulcha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori butter kulcha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013193, 'Tandoori Butter Garlic Naan', 'tandoori butter garlic naan', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter garlic naan');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013193, canonical_dish_id, 'en', 'Tandoori Butter Garlic Naan', 'tandoori butter garlic naan', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori butter garlic naan' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori butter garlic naan' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013194, 'Tandoori Naan', 'tandoori naan', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori naan');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013194, canonical_dish_id, 'en', 'Tandoori Naan', 'tandoori naan', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori naan' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori naan' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013195, 'Pav', 'pav', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013195, canonical_dish_id, 'en', 'Pav', 'pav', 'primary' FROM canonical_dish
WHERE normalized_name = 'pav' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pav' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013196, 'Pav (Garam)', 'pav (garam)', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav (garam)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013196, canonical_dish_id, 'en', 'Pav (Garam)', 'pav (garam)', 'primary' FROM canonical_dish
WHERE normalized_name = 'pav (garam)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'pav (garam)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013197, 'Chicken Tikka Biryani (3pcs)', 'chicken tikka biryani (3pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani (3pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013197, canonical_dish_id, 'en', 'Chicken Tikka Biryani (3pcs)', 'chicken tikka biryani (3pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tikka biryani (3pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tikka biryani (3pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013198, 'Chicken Biryani (2pcs)', 'chicken biryani (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013198, canonical_dish_id, 'en', 'Chicken Biryani (2pcs)', 'chicken biryani (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken biryani (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken biryani (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013199, 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013199, canonical_dish_id, 'en', 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hydrabadi biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hydrabadi biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013200, 'Chicken Leg Tandoori Biryani', 'chicken leg tandoori biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken leg tandoori biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013200, canonical_dish_id, 'en', 'Chicken Leg Tandoori Biryani', 'chicken leg tandoori biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken leg tandoori biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken leg tandoori biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013201, 'Mutton Biryani (2pcs)', 'mutton biryani (2pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013201, canonical_dish_id, 'en', 'Mutton Biryani (2pcs)', 'mutton biryani (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton biryani (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton biryani (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013202, 'Mutton Hydrabadi Biryani', 'mutton hydrabadi biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hydrabadi biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013202, canonical_dish_id, 'en', 'Mutton Hydrabadi Biryani', 'mutton hydrabadi biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton hydrabadi biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton hydrabadi biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013203, 'Prawns Biryani', 'prawns biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013203, canonical_dish_id, 'en', 'Prawns Biryani', 'prawns biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013204, 'Egg Biryani (2pcs)', 'egg biryani (2pcs)', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg biryani (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013204, canonical_dish_id, 'en', 'Egg Biryani (2pcs)', 'egg biryani (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg biryani (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg biryani (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013205, 'Paneer Tikka Biryani (2pcs)', 'paneer tikka biryani (2pcs)', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani (2pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013205, canonical_dish_id, 'en', 'Paneer Tikka Biryani (2pcs)', 'paneer tikka biryani (2pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tikka biryani (2pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka biryani (2pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013206, 'Paneer Biryani', 'paneer biryani', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013206, canonical_dish_id, 'en', 'Paneer Biryani', 'paneer biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013207, 'Veg Hyderabadi Biryani', 'veg hyderabadi biryani', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hyderabadi biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013207, canonical_dish_id, 'en', 'Veg Hyderabadi Biryani', 'veg hyderabadi biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hyderabadi biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hyderabadi biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013208, 'Veg Biryani', 'veg biryani', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013208, canonical_dish_id, 'en', 'Veg Biryani', 'veg biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013209, 'Chicken Pulao', 'chicken pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013209, canonical_dish_id, 'en', 'Chicken Pulao', 'chicken pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013210, 'Mutton Pulao', 'mutton pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013210, canonical_dish_id, 'en', 'Mutton Pulao', 'mutton pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013211, 'Prawns Pulao', 'prawns pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013211, canonical_dish_id, 'en', 'Prawns Pulao', 'prawns pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013212, 'Egg Pulao', 'egg pulao', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013212, canonical_dish_id, 'en', 'Egg Pulao', 'egg pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013213, 'Paneer Pulao', 'paneer pulao', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013213, canonical_dish_id, 'en', 'Paneer Pulao', 'paneer pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013214, 'Veg Pulao', 'veg pulao', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013214, canonical_dish_id, 'en', 'Veg Pulao', 'veg pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013215, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi tadka');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013215, canonical_dish_id, 'en', 'Dal Khichdi Tadka', 'dal khichdi tadka', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal khichdi tadka' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal khichdi tadka' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013216, 'Dal Khichdi Butter', 'dal khichdi butter', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi butter');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013216, canonical_dish_id, 'en', 'Dal Khichdi Butter', 'dal khichdi butter', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal khichdi butter' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal khichdi butter' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013217, 'Dal Khichdi', 'dal khichdi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013217, canonical_dish_id, 'en', 'Dal Khichdi', 'dal khichdi', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal khichdi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal khichdi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013218, 'Jeera Rice', 'jeera rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013218, canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'jeera rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'jeera rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013219, 'White Rice', 'white rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'white rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013219, canonical_dish_id, 'en', 'White Rice', 'white rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'white rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'white rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013220, 'Steam Rice', 'steam rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013220, canonical_dish_id, 'en', 'Steam Rice', 'steam rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'steam rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'steam rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013221, 'Dal Rice', 'dal rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013221, canonical_dish_id, 'en', 'Dal Rice', 'dal rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013222, 'Chicken Tavakkal Special Soup', 'chicken tavakkal special soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tavakkal special soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013222, canonical_dish_id, 'en', 'Chicken Tavakkal Special Soup', 'chicken tavakkal special soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tavakkal special soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tavakkal special soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013223, 'Chicken Manchow Soup', 'chicken manchow soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchow soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013223, canonical_dish_id, 'en', 'Chicken Manchow Soup', 'chicken manchow soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken manchow soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken manchow soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013224, 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot & sour soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013224, canonical_dish_id, 'en', 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hot & sour soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hot & sour soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013225, 'Veg. Manchow Soup', 'veg. manchow soup', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchow soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013225, canonical_dish_id, 'en', 'Veg. Manchow Soup', 'veg. manchow soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. manchow soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. manchow soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013226, 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hot & sour soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013226, canonical_dish_id, 'en', 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. hot & sour soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. hot & sour soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013227, 'Chicken Lolipop Gravy (6pcs)', 'chicken lolipop gravy (6pcs)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lolipop gravy (6pcs)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013227, canonical_dish_id, 'en', 'Chicken Lolipop Gravy (6pcs)', 'chicken lolipop gravy (6pcs)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken lolipop gravy (6pcs)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken lolipop gravy (6pcs)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013228, 'Chicken Chilly Gravy', 'chicken chilly gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013228, canonical_dish_id, 'en', 'Chicken Chilly Gravy', 'chicken chilly gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chilly gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chilly gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013229, 'Chicken Manchurian Gravy', 'chicken manchurian gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013229, canonical_dish_id, 'en', 'Chicken Manchurian Gravy', 'chicken manchurian gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken manchurian gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken manchurian gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013230, 'Chicken 65 Gravy', 'chicken 65 gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65 gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013230, canonical_dish_id, 'en', 'Chicken 65 Gravy', 'chicken 65 gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken 65 gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken 65 gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013231, 'Chicken Schezwan Gravy', 'chicken schezwan gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013231, canonical_dish_id, 'en', 'Chicken Schezwan Gravy', 'chicken schezwan gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken schezwan gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken schezwan gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013232, 'Paneer Chilly Gravy', 'paneer chilly gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013232, canonical_dish_id, 'en', 'Paneer Chilly Gravy', 'paneer chilly gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer chilly gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer chilly gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013233, 'Paneer 65 Gravy', 'paneer 65 gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65 gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013233, canonical_dish_id, 'en', 'Paneer 65 Gravy', 'paneer 65 gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer 65 gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer 65 gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013234, 'Paneer Manchurian Gravy', 'paneer manchurian gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer manchurian gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013234, canonical_dish_id, 'en', 'Paneer Manchurian Gravy', 'paneer manchurian gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer manchurian gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer manchurian gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013235, 'Veg. Chilly Gravy', 'veg. chilly gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013235, canonical_dish_id, 'en', 'Veg. Chilly Gravy', 'veg. chilly gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. chilly gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. chilly gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013236, 'Veg. Manchurian Gravy', 'veg. manchurian gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013236, canonical_dish_id, 'en', 'Veg. Manchurian Gravy', 'veg. manchurian gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. manchurian gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. manchurian gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013237, 'Veg. 65 Gravy', 'veg. 65 gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. 65 gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013237, canonical_dish_id, 'en', 'Veg. 65 Gravy', 'veg. 65 gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg. 65 gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg. 65 gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013238, 'Prawns Chilly Gravy', 'prawns chilly gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013238, canonical_dish_id, 'en', 'Prawns Chilly Gravy', 'prawns chilly gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns chilly gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns chilly gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013239, 'Prawns 65 Gravy', 'prawns 65 gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns 65 gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013239, canonical_dish_id, 'en', 'Prawns 65 Gravy', 'prawns 65 gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns 65 gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns 65 gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013240, 'Mushroom Chilly Gravy', 'mushroom chilly gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom chilly gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013240, canonical_dish_id, 'en', 'Mushroom Chilly Gravy', 'mushroom chilly gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom chilly gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom chilly gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013241, 'Mushroom 65 Gravy', 'mushroom 65 gravy', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom 65 gravy');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013241, canonical_dish_id, 'en', 'Mushroom 65 Gravy', 'mushroom 65 gravy', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom 65 gravy' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom 65 gravy' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013242, 'Chicken Tripple Schezwan Rice', 'chicken tripple schezwan rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tripple schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013242, canonical_dish_id, 'en', 'Chicken Tripple Schezwan Rice', 'chicken tripple schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tripple schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tripple schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013243, 'Chicken Chopper Rice', 'chicken chopper rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chopper rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013243, canonical_dish_id, 'en', 'Chicken Chopper Rice', 'chicken chopper rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chopper rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chopper rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013244, 'Chicken Manchurian Rice', 'chicken manchurian rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013244, canonical_dish_id, 'en', 'Chicken Manchurian Rice', 'chicken manchurian rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken manchurian rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken manchurian rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013245, 'Chicken Chilly Rice', 'chicken chilly rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013245, canonical_dish_id, 'en', 'Chicken Chilly Rice', 'chicken chilly rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chilly rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chilly rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013246, 'Chicken Singapore Rice', 'chicken singapore rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken singapore rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013246, canonical_dish_id, 'en', 'Chicken Singapore Rice', 'chicken singapore rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken singapore rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken singapore rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013247, 'Chicken Hongkong Rice', 'chicken hongkong rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hongkong rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013247, canonical_dish_id, 'en', 'Chicken Hongkong Rice', 'chicken hongkong rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hongkong rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hongkong rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013248, 'Chicken Combo Rice', 'chicken combo rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken combo rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013248, canonical_dish_id, 'en', 'Chicken Combo Rice', 'chicken combo rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken combo rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken combo rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013249, 'Chicken Combo Schezwan Rice', 'chicken combo schezwan rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken combo schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013249, canonical_dish_id, 'en', 'Chicken Combo Schezwan Rice', 'chicken combo schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken combo schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken combo schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013250, 'Chicken Fried Rice', 'chicken fried rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013250, canonical_dish_id, 'en', 'Chicken Fried Rice', 'chicken fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013251, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013251, canonical_dish_id, 'en', 'Chicken Schezwan Rice', 'chicken schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013252, 'Mix Fried Rice', 'mix fried rice', 'non_veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013252, canonical_dish_id, 'en', 'Mix Fried Rice', 'mix fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'mix fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013253, 'Prawns Tripple Schezwan Rice', 'prawns tripple schezwan rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns tripple schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013253, canonical_dish_id, 'en', 'Prawns Tripple Schezwan Rice', 'prawns tripple schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns tripple schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns tripple schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013254, 'Prawns Manchurian Rice', 'prawns manchurian rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurian rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013254, canonical_dish_id, 'en', 'Prawns Manchurian Rice', 'prawns manchurian rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns manchurian rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns manchurian rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013255, 'Prawns Fried Rice', 'prawns fried rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013255, canonical_dish_id, 'en', 'Prawns Fried Rice', 'prawns fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013256, 'Prawns Schezwan Rice', 'prawns schezwan rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013256, canonical_dish_id, 'en', 'Prawns Schezwan Rice', 'prawns schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013257, 'Egg Fried Rice', 'egg fried rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013257, canonical_dish_id, 'en', 'Egg Fried Rice', 'egg fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013258, 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013258, canonical_dish_id, 'en', 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg schezwan fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg schezwan fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013259, 'Egg Tripple Fried Rice', 'egg tripple fried rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg tripple fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013259, canonical_dish_id, 'en', 'Egg Tripple Fried Rice', 'egg tripple fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg tripple fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg tripple fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013260, 'Egg Hongkong Fried Rice', 'egg hongkong fried rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg hongkong fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013260, canonical_dish_id, 'en', 'Egg Hongkong Fried Rice', 'egg hongkong fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg hongkong fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg hongkong fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013261, 'Egg Singapore Fried Rice', 'egg singapore fried rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg singapore fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013261, canonical_dish_id, 'en', 'Egg Singapore Fried Rice', 'egg singapore fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg singapore fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg singapore fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013262, 'Egg Combo Fried Rice', 'egg combo fried rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg combo fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013262, canonical_dish_id, 'en', 'Egg Combo Fried Rice', 'egg combo fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg combo fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg combo fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013263, 'Egg Combo Schezwan Rice', 'egg combo schezwan rice', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg combo schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013263, canonical_dish_id, 'en', 'Egg Combo Schezwan Rice', 'egg combo schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg combo schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg combo schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013264, 'Veg Fried Rice', 'veg fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013264, canonical_dish_id, 'en', 'Veg Fried Rice', 'veg fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013265, 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013265, canonical_dish_id, 'en', 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg schezwan fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg schezwan fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013266, 'Veg Combo Fried Rice', 'veg combo fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg combo fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013266, canonical_dish_id, 'en', 'Veg Combo Fried Rice', 'veg combo fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg combo fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg combo fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013267, 'Veg Combo Schezwan Rice', 'veg combo schezwan rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg combo schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013267, canonical_dish_id, 'en', 'Veg Combo Schezwan Rice', 'veg combo schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg combo schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg combo schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013268, 'Veg Tripple Fried Rice', 'veg tripple fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg tripple fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013268, canonical_dish_id, 'en', 'Veg Tripple Fried Rice', 'veg tripple fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg tripple fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg tripple fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013269, 'Veg Manchurian Rice', 'veg manchurian rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013269, canonical_dish_id, 'en', 'Veg Manchurian Rice', 'veg manchurian rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg manchurian rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg manchurian rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013270, 'Veg Chilly Fried Rice', 'veg chilly fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chilly fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013270, canonical_dish_id, 'en', 'Veg Chilly Fried Rice', 'veg chilly fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg chilly fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg chilly fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013271, 'Veg Singapore Fried Rice', 'veg singapore fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg singapore fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013271, canonical_dish_id, 'en', 'Veg Singapore Fried Rice', 'veg singapore fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg singapore fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg singapore fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013272, 'Veg Hongkong Fried Rice', 'veg hongkong fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hongkong fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013272, canonical_dish_id, 'en', 'Veg Hongkong Fried Rice', 'veg hongkong fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hongkong fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hongkong fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013273, 'Paneer Tripple Fried Rice', 'paneer tripple fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tripple fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013273, canonical_dish_id, 'en', 'Paneer Tripple Fried Rice', 'paneer tripple fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tripple fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tripple fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013274, 'Paneer Manchurian Rice', 'paneer manchurian rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer manchurian rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013274, canonical_dish_id, 'en', 'Paneer Manchurian Rice', 'paneer manchurian rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer manchurian rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer manchurian rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013275, 'Paneer Chilly Rice', 'paneer chilly rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013275, canonical_dish_id, 'en', 'Paneer Chilly Rice', 'paneer chilly rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer chilly rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer chilly rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013276, 'Paneer Schezwan Rice', 'paneer schezwan rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013276, canonical_dish_id, 'en', 'Paneer Schezwan Rice', 'paneer schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013277, 'Paneer Fried Rice', 'paneer fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013277, canonical_dish_id, 'en', 'Paneer Fried Rice', 'paneer fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013278, 'Mushroom Fried Rice', 'mushroom fried rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013278, canonical_dish_id, 'en', 'Mushroom Fried Rice', 'mushroom fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013279, 'Mushroom Schezwan Rice', 'mushroom schezwan rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom schezwan rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013279, canonical_dish_id, 'en', 'Mushroom Schezwan Rice', 'mushroom schezwan rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom schezwan rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom schezwan rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013280, 'Mushroom Tripple Rice', 'mushroom tripple rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tripple rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013280, canonical_dish_id, 'en', 'Mushroom Tripple Rice', 'mushroom tripple rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom tripple rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom tripple rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013281, 'Kapsa Rice', 'kapsa rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kapsa rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013281, canonical_dish_id, 'en', 'Kapsa Rice', 'kapsa rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'kapsa rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kapsa rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013282, 'Chicken Chilly Kapsa Rice', 'chicken chilly kapsa rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly kapsa rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013282, canonical_dish_id, 'en', 'Chicken Chilly Kapsa Rice', 'chicken chilly kapsa rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken chilly kapsa rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken chilly kapsa rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013283, 'Paneer Chilly Kapsa Rice', 'paneer chilly kapsa rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly kapsa rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013283, canonical_dish_id, 'en', 'Paneer Chilly Kapsa Rice', 'paneer chilly kapsa rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer chilly kapsa rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer chilly kapsa rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013284, 'Veg Chilly Kapsa Rice', 'veg chilly kapsa rice', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chilly kapsa rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013284, canonical_dish_id, 'en', 'Veg Chilly Kapsa Rice', 'veg chilly kapsa rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg chilly kapsa rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg chilly kapsa rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013285, 'Chicken Tripple Schezwan Noodles', 'chicken tripple schezwan noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tripple schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013285, canonical_dish_id, 'en', 'Chicken Tripple Schezwan Noodles', 'chicken tripple schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tripple schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tripple schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013286, 'Chicken Manchurian Noodles', 'chicken manchurian noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013286, canonical_dish_id, 'en', 'Chicken Manchurian Noodles', 'chicken manchurian noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken manchurian noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken manchurian noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013287, 'Chicken Singapore Noodles', 'chicken singapore noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken singapore noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013287, canonical_dish_id, 'en', 'Chicken Singapore Noodles', 'chicken singapore noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken singapore noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken singapore noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013288, 'Chicken Hongkong Noodles', 'chicken hongkong noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hongkong noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013288, canonical_dish_id, 'en', 'Chicken Hongkong Noodles', 'chicken hongkong noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hongkong noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hongkong noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013289, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hakka noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013289, canonical_dish_id, 'en', 'Chicken Hakka Noodles', 'chicken hakka noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken hakka noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken hakka noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013290, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013290, canonical_dish_id, 'en', 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013291, 'Mix Hakka Noodles', 'mix hakka noodles', 'non_veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix hakka noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013291, canonical_dish_id, 'en', 'Mix Hakka Noodles', 'mix hakka noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'mix hakka noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix hakka noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013292, 'Mix Schezwan Noodles', 'mix schezwan noodles', 'non_veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013292, canonical_dish_id, 'en', 'Mix Schezwan Noodles', 'mix schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'mix schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013293, 'Prawns Hakka Noodles', 'prawns hakka noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns hakka noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013293, canonical_dish_id, 'en', 'Prawns Hakka Noodles', 'prawns hakka noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns hakka noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns hakka noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013294, 'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013294, canonical_dish_id, 'en', 'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013295, 'Prawns Singapore Noodles', 'prawns singapore noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns singapore noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013295, canonical_dish_id, 'en', 'Prawns Singapore Noodles', 'prawns singapore noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns singapore noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns singapore noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013296, 'Prawns Hongkong Noodles', 'prawns hongkong noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns hongkong noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013296, canonical_dish_id, 'en', 'Prawns Hongkong Noodles', 'prawns hongkong noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns hongkong noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns hongkong noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013297, 'Prawns Tripple Noodles', 'prawns tripple noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns tripple noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013297, canonical_dish_id, 'en', 'Prawns Tripple Noodles', 'prawns tripple noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns tripple noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns tripple noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013298, 'Prawns Manchurian Noodles', 'prawns manchurian noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurian noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013298, canonical_dish_id, 'en', 'Prawns Manchurian Noodles', 'prawns manchurian noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'prawns manchurian noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'prawns manchurian noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013299, 'Egg Hakka Noodles', 'egg hakka noodles', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg hakka noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013299, canonical_dish_id, 'en', 'Egg Hakka Noodles', 'egg hakka noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg hakka noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg hakka noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013300, 'Egg Schezwan Noodles', 'egg schezwan noodles', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013300, canonical_dish_id, 'en', 'Egg Schezwan Noodles', 'egg schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013301, 'Egg Singapore Noodles', 'egg singapore noodles', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg singapore noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013301, canonical_dish_id, 'en', 'Egg Singapore Noodles', 'egg singapore noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg singapore noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg singapore noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013302, 'Egg Hongkong Noodles', 'egg hongkong noodles', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg hongkong noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013302, canonical_dish_id, 'en', 'Egg Hongkong Noodles', 'egg hongkong noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg hongkong noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg hongkong noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013303, 'Egg Tripple Schezwan Noodles', 'egg tripple schezwan noodles', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg tripple schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013303, canonical_dish_id, 'en', 'Egg Tripple Schezwan Noodles', 'egg tripple schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg tripple schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg tripple schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013304, 'Egg Manchurian Noodles', 'egg manchurian noodles', 'egg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg manchurian noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013304, canonical_dish_id, 'en', 'Egg Manchurian Noodles', 'egg manchurian noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'egg manchurian noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'egg manchurian noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013305, 'Veg Hakka Noodles', 'veg hakka noodles', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hakka noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013305, canonical_dish_id, 'en', 'Veg Hakka Noodles', 'veg hakka noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hakka noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hakka noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013306, 'Veg Schezwan Noodles', 'veg schezwan noodles', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013306, canonical_dish_id, 'en', 'Veg Schezwan Noodles', 'veg schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013307, 'Veg Singapore Noodles', 'veg singapore noodles', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg singapore noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013307, canonical_dish_id, 'en', 'Veg Singapore Noodles', 'veg singapore noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg singapore noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg singapore noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013308, 'Veg Hongkong Noodles', 'veg hongkong noodles', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hongkong noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013308, canonical_dish_id, 'en', 'Veg Hongkong Noodles', 'veg hongkong noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hongkong noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hongkong noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013309, 'Veg Tripple Schezwan Noodles', 'veg tripple schezwan noodles', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg tripple schezwan noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013309, canonical_dish_id, 'en', 'Veg Tripple Schezwan Noodles', 'veg tripple schezwan noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg tripple schezwan noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg tripple schezwan noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013310, 'Veg Manchurian Noodles', 'veg manchurian noodles', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian noodles');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013310, canonical_dish_id, 'en', 'Veg Manchurian Noodles', 'veg manchurian noodles', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg manchurian noodles' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg manchurian noodles' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013311, 'Chaas / Dahi / Lassi / Raita', 'chaas / dahi / lassi / raita', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chaas / dahi / lassi / raita');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013311, canonical_dish_id, 'en', 'Chaas / Dahi / Lassi / Raita', 'chaas / dahi / lassi / raita', 'primary' FROM canonical_dish
WHERE normalized_name = 'chaas / dahi / lassi / raita' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chaas / dahi / lassi / raita' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013312, 'Caramel Custard', 'caramel custard', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'caramel custard');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013312, canonical_dish_id, 'en', 'Caramel Custard', 'caramel custard', 'primary' FROM canonical_dish
WHERE normalized_name = 'caramel custard' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'caramel custard' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013313, 'Matka Rabdi', 'matka rabdi', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'matka rabdi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013313, canonical_dish_id, 'en', 'Matka Rabdi', 'matka rabdi', 'primary' FROM canonical_dish
WHERE normalized_name = 'matka rabdi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'matka rabdi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013314, 'Arabian Pudding', 'arabian pudding', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian pudding');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013314, canonical_dish_id, 'en', 'Arabian Pudding', 'arabian pudding', 'primary' FROM canonical_dish
WHERE normalized_name = 'arabian pudding' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'arabian pudding' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013315, 'Gulab Jamun', 'gulab jamun', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gulab jamun');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013315, canonical_dish_id, 'en', 'Gulab Jamun', 'gulab jamun', 'primary' FROM canonical_dish
WHERE normalized_name = 'gulab jamun' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'gulab jamun' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013316, 'Green Salad', 'green salad', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013316, canonical_dish_id, 'en', 'Green Salad', 'green salad', 'primary' FROM canonical_dish
WHERE normalized_name = 'green salad' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'green salad' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013317, 'Chicken Biryani (1.kg Rice & 1.kg Chicken)', 'chicken biryani (1.kg rice & 1.kg chicken)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani (1.kg rice & 1.kg chicken)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013317, canonical_dish_id, 'en', 'Chicken Biryani (1.kg Rice & 1.kg Chicken)', 'chicken biryani (1.kg rice & 1.kg chicken)', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken biryani (1.kg rice & 1.kg chicken)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken biryani (1.kg rice & 1.kg chicken)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013318, 'Mutton Biryani (1.kg Rice & 1.kg Mutton)', 'mutton biryani (1.kg rice & 1.kg mutton)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani (1.kg rice & 1.kg mutton)');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013318, canonical_dish_id, 'en', 'Mutton Biryani (1.kg Rice & 1.kg Mutton)', 'mutton biryani (1.kg rice & 1.kg mutton)', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton biryani (1.kg rice & 1.kg mutton)' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton biryani (1.kg rice & 1.kg mutton)' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013319, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013319, canonical_dish_id, 'en', 'Chicken Tikka Biryani', 'chicken tikka biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken tikka biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken tikka biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013320, 'Veg Biryani & Pulao', 'veg biryani & pulao', 'veg', NULL
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg biryani & pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013320, canonical_dish_id, 'en', 'Veg Biryani & Pulao', 'veg biryani & pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg biryani & pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg biryani & pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013321, 'Mutton Handi', 'mutton handi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013321, canonical_dish_id, 'en', 'Mutton Handi', 'mutton handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'mutton handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mutton handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
SELECT 400070013322, 'Chicken Handi', 'chicken handi', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN')
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400070013322, canonical_dish_id, 'en', 'Chicken Handi', 'chicken handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'chicken handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chicken handi' AND name_type_code = 'primary');

-- Menu items, variants, prices, board links, provenance (326 items / 349 variants)
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013001, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken special tandoori'),
       'Chicken Special Tandoori', 'chicken special tandoori', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013001);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013001, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013001);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013001, 400070013, 400070013001, 400070013001, 400070013001, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013001);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013001, 400070013001, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013001);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013001, 400070013001, 500.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013001);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013002, 400070013001, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013002);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013002, 400070013002, 300.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013002);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013002, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tandoori'),
       'Chicken Tandoori', 'chicken tandoori', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013002);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013002, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013002);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013002, 400070013, 400070013001, 400070013002, 400070013001, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013002);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013003, 400070013002, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013003);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013003, 400070013003, 370.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013003);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013004, 400070013002, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013004);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013004, 400070013004, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013004);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013003, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan tandoori'),
       'Chicken Schezwan Tandoori', 'chicken schezwan tandoori', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013003);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013003, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013003);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013003, 400070013, 400070013001, 400070013003, 400070013001, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013003);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013005, 400070013003, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013005);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013005, 400070013005, 500.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013005);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013006, 400070013003, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013006);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013006, 400070013006, 300.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013006);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013004, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken leg tandoori'),
       'Chicken Leg Tandoori', 'chicken leg tandoori', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013004);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013004, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013004);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013004, 400070013, 400070013001, 400070013004, 400070013001, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013004);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013007, 400070013004, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013007);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013007, 400070013007, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013007);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013005, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken malai kabab (6pcs)'),
       'Chicken Malai Kabab (6pcs)', 'chicken malai kabab (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013005);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013005, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013005);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013005, 400070013, 400070013001, 400070013005, 400070013001, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013005);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013008, 400070013005, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013008);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013008, 400070013008, 310.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013008);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013006, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken banjara kabab (6pcs)'),
       'Chicken Banjara Kabab (6pcs)', 'chicken banjara kabab (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013006);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013006, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013006);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013006, 400070013, 400070013001, 400070013006, 400070013001, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013006);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013009, 400070013006, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013009);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013009, 400070013009, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013009);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013007, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken reshmi kabab (6pcs)'),
       'Chicken Reshmi Kabab (6pcs)', 'chicken reshmi kabab (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013007);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013007, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013007);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013007, 400070013, 400070013001, 400070013007, 400070013001, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013007);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013010, 400070013007, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013010);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013010, 400070013010, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013010);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013008, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken pahadi kabab (6pcs)'),
       'Chicken Pahadi Kabab (6pcs)', 'chicken pahadi kabab (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013008);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013008, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013008);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013008, 400070013, 400070013001, 400070013008, 400070013001, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013008);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013011, 400070013008, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013011);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013011, 400070013011, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013011);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013009, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tikka dry (6pcs)'),
       'Chicken Tikka Dry (6pcs)', 'chicken tikka dry (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013009);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013009, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013009);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013009, 400070013, 400070013001, 400070013009, 400070013001, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013009);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013012, 400070013009, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013012);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013012, 400070013012, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013012);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013010, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan tikka (6pcs)'),
       'Chicken Schezwan Tikka (6pcs)', 'chicken schezwan tikka (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013010);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013010, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013010);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013010, 400070013, 400070013001, 400070013010, 400070013001, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013010);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013013, 400070013010, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013013);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013013, 400070013013, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013013);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013011, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton plain fry (6pcs)'),
       'Mutton Plain Fry (6pcs)', 'mutton plain fry (6pcs)', 'Tandoor & Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013011);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013011, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013011);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013011, 400070013, 400070013001, 400070013011, 400070013001, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013011);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013014, 400070013011, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013014);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013014, 400070013014, 350.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013014);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013012, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka dry (6pcs)'),
       'Paneer Tikka Dry (6pcs)', 'paneer tikka dry (6pcs)', 'Tandoor & Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013012);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013012, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013012);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013012, 400070013, 400070013001, 400070013012, 400070013001, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013012);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013015, 400070013012, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013015);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013015, 400070013015, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013015);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013013, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'masala papad'),
       'Masala Papad', 'masala papad', 'Tandoor & Starter', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013013);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013013, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013013);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013013, 400070013, 400070013001, 400070013013, 400070013001, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013013);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013016, 400070013013, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013016);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013016, 400070013016, 60.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013016);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013014, 400070013, 400070013001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'papad fry & roasted'),
       'Papad Fry & Roasted', 'papad fry & roasted', 'Tandoor & Starter', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013014);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013014, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013014);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013014, 400070013, 400070013001, 400070013014, 400070013001, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013014);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013017, 400070013014, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013017);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013017, 400070013017, 20.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013017);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013015, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken crispy'),
       'Chicken Crispy', 'chicken crispy', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013015);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013015, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013015);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013015, 400070013, 400070013001, 400070013015, 400070013002, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013015);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013018, 400070013015, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013018);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013018, 400070013018, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013018);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013016, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken roasted dry'),
       'Chicken Roasted Dry', 'chicken roasted dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013016);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013016, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013016);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013016, 400070013, 400070013001, 400070013016, 400070013002, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013016);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013019, 400070013016, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013019);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013019, 400070013019, 320.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013019);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013017, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken bone chilly dry (8 pcs)'),
       'Chicken Bone Chilly Dry (8 pcs)', 'chicken bone chilly dry (8 pcs)', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013017);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013017, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013017);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013017, 400070013, 400070013001, 400070013017, 400070013002, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013017);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013020, 400070013017, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013020);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013020, 400070013020, 300.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013020);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013018, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lolipop chatpata (6pcs)'),
       'Chicken Lolipop Chatpata (6pcs)', 'chicken lolipop chatpata (6pcs)', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013018);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013018, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013018);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013018, 400070013, 400070013001, 400070013018, 400070013002, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013018);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013021, 400070013018, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013021);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013021, 400070013021, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013021);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013019, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lolipop dry'),
       'Chicken Lolipop Dry', 'chicken lolipop dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013019);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013019, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013019);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013019, 400070013, 400070013001, 400070013019, 400070013002, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013019);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013022, 400070013019, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013022);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013022, 400070013022, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013022);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013020, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken 65 dry'),
       'Chicken 65 Dry', 'chicken 65 dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013020);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013020, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013020);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013020, 400070013, 400070013001, 400070013020, 400070013002, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013020);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013023, 400070013020, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013023);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013023, 400070013023, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013023);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013021, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chilly dry'),
       'Chicken Chilly Dry', 'chicken chilly dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013021);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013021, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013021);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013021, 400070013, 400070013001, 400070013021, 400070013002, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013021);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013024, 400070013021, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013024);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013024, 400070013024, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013024);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013022, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken manchurian dry'),
       'Chicken Manchurian Dry', 'chicken manchurian dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013022);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013022, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013022);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013022, 400070013, 400070013001, 400070013022, 400070013002, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013022);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013025, 400070013022, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013025);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013025, 400070013025, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013025);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013023, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken garlic dry'),
       'Chicken Garlic Dry', 'chicken garlic dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013023);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013023, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013023);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013023, 400070013, 400070013001, 400070013023, 400070013002, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013023);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013026, 400070013023, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013026);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013026, 400070013026, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013026);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013024, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan dry'),
       'Chicken Schezwan Dry', 'chicken schezwan dry', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013024);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013024, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013024);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013024, 400070013, 400070013001, 400070013024, 400070013002, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013024);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013027, 400070013024, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013027);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013027, 400070013027, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013027);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013025, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom chilly dry'),
       'Mushroom Chilly Dry', 'mushroom chilly dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013025);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013025, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013025);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013025, 400070013, 400070013001, 400070013025, 400070013002, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013025);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013028, 400070013025, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013028);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013028, 400070013028, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013028);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013026, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom schezwan dry'),
       'Mushroom Schezwan Dry', 'mushroom schezwan dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013026);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013026, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013026);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013026, 400070013, 400070013001, 400070013026, 400070013002, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013026);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013029, 400070013026, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013029);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013029, 400070013029, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013029);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013027, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom garlic dry'),
       'Mushroom Garlic Dry', 'mushroom garlic dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013027);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013027, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013027);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013027, 400070013, 400070013001, 400070013027, 400070013002, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013027);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013030, 400070013027, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013030);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013030, 400070013030, 270.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013030);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013028, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer crispy'),
       'Paneer Crispy', 'paneer crispy', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013028);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013028, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013028);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013028, 400070013, 400070013001, 400070013028, 400070013002, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013028);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013031, 400070013028, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013031);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013031, 400070013031, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013031);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013029, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer 65 dry'),
       'Paneer 65 Dry', 'paneer 65 dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013029);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013029, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013029);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013029, 400070013, 400070013001, 400070013029, 400070013002, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013029);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013032, 400070013029, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013032);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013032, 400070013032, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013032);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013030, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chilly dry'),
       'Paneer Chilly Dry', 'paneer chilly dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013030);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013030, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013030);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013030, 400070013, 400070013001, 400070013030, 400070013002, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013030);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013033, 400070013030, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013033);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013033, 400070013033, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013033);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013031, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer manchurian dry'),
       'Paneer Manchurian Dry', 'paneer manchurian dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013031);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013031, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013031);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013031, 400070013, 400070013001, 400070013031, 400070013002, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013031);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013034, 400070013031, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013034);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013034, 400070013034, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013034);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013032, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer garlic dry'),
       'Paneer Garlic Dry', 'paneer garlic dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013032);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013032, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013032);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013032, 400070013, 400070013001, 400070013032, 400070013002, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013032);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013035, 400070013032, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013035);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013035, 400070013035, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013035);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013033, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer schezwan dry'),
       'Paneer Schezwan Dry', 'paneer schezwan dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013033);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013033, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013033);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013033, 400070013, 400070013001, 400070013033, 400070013002, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013033);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013036, 400070013033, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013036);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013036, 400070013036, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013036);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013034, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. crispy'),
       'Veg. Crispy', 'veg. crispy', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013034);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013034, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013034);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013034, 400070013, 400070013001, 400070013034, 400070013002, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013034);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013037, 400070013034, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013037);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013037, 400070013037, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013037);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013035, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. 65 dry'),
       'Veg. 65 Dry', 'veg. 65 dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013035);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013035, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013035);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013035, 400070013, 400070013001, 400070013035, 400070013002, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013035);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013038, 400070013035, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013038);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013038, 400070013038, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013038);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013036, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. chilly dry'),
       'Veg. Chilly Dry', 'veg. chilly dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013036);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013036, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013036);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013036, 400070013, 400070013001, 400070013036, 400070013002, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013036);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013039, 400070013036, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013039);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013039, 400070013039, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013039);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013037, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. manchurian dry'),
       'Veg. Manchurian Dry', 'veg. manchurian dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013037);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013037, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013037);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013037, 400070013, 400070013001, 400070013037, 400070013002, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013037);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013040, 400070013037, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013040);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013040, 400070013040, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013040);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013038, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. garlic dry'),
       'Veg. Garlic Dry', 'veg. garlic dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013038);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013038, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013038);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013038, 400070013, 400070013001, 400070013038, 400070013002, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013038);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013041, 400070013038, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013041);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013041, 400070013041, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013041);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013039, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. schezwan dry'),
       'Veg. Schezwan Dry', 'veg. schezwan dry', 'Chinese Starter', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013039);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013039, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013039);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013039, 400070013, 400070013001, 400070013039, 400070013002, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013039);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013042, 400070013039, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013042);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013042, 400070013042, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013042);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013040, 400070013, 400070013002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns kolwada'),
       'Prawns Kolwada', 'prawns kolwada', 'Chinese Starter', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013040);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013040, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013040);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013040, 400070013, 400070013001, 400070013040, 400070013002, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013040);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013043, 400070013040, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013043);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013043, 400070013043, 350.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013043);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013041, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken aflatoon (jumbo)'),
       'Chicken Aflatoon (Jumbo)', 'chicken aflatoon (jumbo)', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013041);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013041, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013041);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013041, 400070013, 400070013001, 400070013041, 400070013003, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013041);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013044, 400070013041, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013044);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013044, 400070013044, 350.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013044);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013042, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken maharaja (jumbo)'),
       'Chicken Maharaja (Jumbo)', 'chicken maharaja (jumbo)', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013042);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013042, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013042);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013042, 400070013, 400070013001, 400070013042, 400070013003, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013042);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013045, 400070013042, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013045);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013045, 400070013045, 340.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013045);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013043, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lahori (jumbo)'),
       'Chicken Lahori (Jumbo)', 'chicken lahori (jumbo)', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013043);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013043, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013043);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013043, 400070013, 400070013001, 400070013043, 400070013003, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013043);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013046, 400070013043, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013046);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013046, 400070013046, 340.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013046);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013044, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken special tavakkal'),
       'Chicken Special Tavakkal', 'chicken special tavakkal', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013044);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013044, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013044);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013044, 400070013, 400070013001, 400070013044, 400070013003, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013044);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013047, 400070013044, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013047);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013047, 400070013047, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013047);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013045, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken peshawari'),
       'Chicken Peshawari', 'chicken peshawari', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013045);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013045, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013045);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013045, 400070013, 400070013001, 400070013045, 400070013003, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013045);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013048, 400070013045, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013048);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013048, 400070013048, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013048);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013046, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lara'),
       'Chicken Lara', 'chicken lara', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013046);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013046, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013046);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013046, 400070013, 400070013001, 400070013046, 400070013003, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013046);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013049, 400070013046, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013049);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013049, 400070013049, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013049);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013047, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken akbari'),
       'Chicken Akbari', 'chicken akbari', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013047);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013047, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013047);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013047, 400070013, 400070013001, 400070013047, 400070013003, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013047);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013050, 400070013047, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013050);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013050, 400070013050, 270.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013050);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013048, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken boneless handi'),
       'Chicken Boneless Handi', 'chicken boneless handi', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013048);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013048, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013048);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013048, 400070013, 400070013001, 400070013048, 400070013003, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013048);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013051, 400070013048, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013051);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013051, 400070013051, 360.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013051);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013052, 400070013048, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013052);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013052, 400070013052, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013052);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013049, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lajawab'),
       'Chicken Lajawab', 'chicken lajawab', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013049);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013049, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013049);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013049, 400070013, 400070013001, 400070013049, 400070013003, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013049);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013053, 400070013049, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013053);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013053, 400070013053, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013053);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013050, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lucknowi'),
       'Chicken Lucknowi', 'chicken lucknowi', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013050);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013050, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013050);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013050, 400070013, 400070013001, 400070013050, 400070013003, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013050);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013054, 400070013050, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013054);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013054, 400070013054, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013054);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013051, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken haryali'),
       'Chicken Haryali', 'chicken haryali', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013051);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013051, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013051);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013051, 400070013, 400070013001, 400070013051, 400070013003, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013051);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013055, 400070013051, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013055);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013055, 400070013055, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013055);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013052, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken mumtaz'),
       'Chicken Mumtaz', 'chicken mumtaz', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013052);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013052, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013052);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013052, 400070013, 400070013001, 400070013052, 400070013003, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013052);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013056, 400070013052, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013056);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013056, 400070013056, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013056);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013053, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken zaitoon'),
       'Chicken Zaitoon', 'chicken zaitoon', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013053);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013053, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013053);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013053, 400070013, 400070013001, 400070013053, 400070013003, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013053);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013057, 400070013053, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013057);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013057, 400070013057, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013057);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013054, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken zaika'),
       'Chicken Zaika', 'chicken zaika', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013054);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013054, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013054);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013054, 400070013, 400070013001, 400070013054, 400070013003, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013054);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013058, 400070013054, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013058);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013058, 400070013058, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013058);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013055, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chulbul'),
       'Chicken Chulbul', 'chicken chulbul', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013055);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013055, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013055);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013055, 400070013, 400070013001, 400070013055, 400070013003, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013055);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013059, 400070013055, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013059);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013059, 400070013059, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013059);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013056, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken methi'),
       'Chicken Methi', 'chicken methi', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013056);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013056, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013056);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013056, 400070013, 400070013001, 400070013056, 400070013003, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013056);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013060, 400070013056, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013060);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013060, 400070013060, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013060);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013057, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kothmiri'),
       'Chicken Kothmiri', 'chicken kothmiri', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013057);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013057, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013057);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013057, 400070013, 400070013001, 400070013057, 400070013003, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013057);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013061, 400070013057, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013061);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013061, 400070013061, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013061);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013058, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chingari'),
       'Chicken Chingari', 'chicken chingari', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013058);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013058, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013058);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013058, 400070013, 400070013001, 400070013058, 400070013003, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013058);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013062, 400070013058, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013062);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013062, 400070013062, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013062);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013059, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken nawabi'),
       'Chicken Nawabi', 'chicken nawabi', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013059);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013059, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013059);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013059, 400070013, 400070013001, 400070013059, 400070013003, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013059);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013063, 400070013059, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013063);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013063, 400070013063, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013063);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013060, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi'),
       'Chicken Hydrabadi', 'chicken hydrabadi', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013060);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013060, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013060);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013060, 400070013, 400070013001, 400070013060, 400070013003, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013060);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013064, 400070013060, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013064);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013064, 400070013064, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013064);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013061, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken patiyala'),
       'Chicken Patiyala', 'chicken patiyala', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013061);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013061, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013061);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013061, 400070013, 400070013001, 400070013061, 400070013003, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013061);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013065, 400070013061, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013065);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013065, 400070013065, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013065);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013062, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tawa'),
       'Chicken Tawa', 'chicken tawa', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013062);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013062, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013062);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013062, 400070013, 400070013001, 400070013062, 400070013003, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013062);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013066, 400070013062, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013066);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013066, 400070013066, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013066);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013063, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter chicken'),
       'Butter Chicken', 'butter chicken', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013063);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013063, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013063);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013063, 400070013, 400070013001, 400070013063, 400070013003, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013063);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013067, 400070013063, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013067);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013067, 400070013067, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013067);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013068, 400070013063, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013068);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013068, 400070013068, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013068);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013064, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken angara'),
       'Chicken Angara', 'chicken angara', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013064);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013064, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013064);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013064, 400070013, 400070013001, 400070013064, 400070013003, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013064);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013069, 400070013064, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013069);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013069, 400070013069, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013069);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013065, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken balti'),
       'Chicken Balti', 'chicken balti', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013065);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013065, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013065);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013065, 400070013, 400070013001, 400070013065, 400070013003, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013065);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013070, 400070013065, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013070);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013070, 400070013070, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013070);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013066, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken afgani'),
       'Chicken Afgani', 'chicken afgani', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013066);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013066, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013066);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013066, 400070013, 400070013001, 400070013066, 400070013003, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013066);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013071, 400070013066, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013071);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013071, 400070013071, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013071);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013067, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lazeez'),
       'Chicken Lazeez', 'chicken lazeez', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013067);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013067, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013067);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013067, 400070013, 400070013001, 400070013067, 400070013003, 27
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013067);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013072, 400070013067, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013072);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013072, 400070013072, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013072);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013068, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tikka masala (3pcs)'),
       'Chicken Tikka Masala (3pcs)', 'chicken tikka masala (3pcs)', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013068);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013068, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013068);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013068, 400070013, 400070013001, 400070013068, 400070013003, 28
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013068);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013073, 400070013068, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013073);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013073, 400070013073, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013073);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013069, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tikka handi (3pcs)'),
       'Chicken Tikka Handi (3pcs)', 'chicken tikka handi (3pcs)', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013069);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013069, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013069);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013069, 400070013, 400070013001, 400070013069, 400070013003, 29
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013069);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013074, 400070013069, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013074);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013074, 400070013074, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013074);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013070, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chatpata'),
       'Chicken Chatpata', 'chicken chatpata', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013070);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013070, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013070);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013070, 400070013, 400070013001, 400070013070, 400070013003, 30
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013070);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013075, 400070013070, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013075);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013075, 400070013075, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013075);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013071, 400070013, 400070013003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kheema'),
       'Chicken Kheema', 'chicken kheema', 'Tavakkal Special Boneless', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013071);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013071, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013071);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013071, 400070013, 400070013001, 400070013071, 400070013003, 31
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013071);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013076, 400070013071, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013076);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013076, 400070013076, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013076);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013072, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken murg musallam'),
       'Chicken Murg Musallam', 'chicken murg musallam', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013072);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013072, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013072);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013072, 400070013, 400070013001, 400070013072, 400070013004, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013072);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013077, 400070013072, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013077);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013077, 400070013077, 580.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013077);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013078, 400070013072, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013078);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013078, 400070013078, 380.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013078);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013073, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken sukka (6pcs)'),
       'Chicken Sukka (6pcs)', 'chicken sukka (6pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013073);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013073, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013073);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013073, 400070013, 400070013001, 400070013073, 400070013004, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013073);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013079, 400070013073, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013079);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013079, 400070013079, 300.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013079);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013074, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken leg masala'),
       'Chicken Leg Masala', 'chicken leg masala', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013074);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013074, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013074);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013074, 400070013, 400070013001, 400070013074, 400070013004, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013074);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013080, 400070013074, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013080);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013080, 400070013080, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013080);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013075, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken handi (full)(8pcs)'),
       'Chicken Handi (Full)(8pcs)', 'chicken handi (full)(8pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013075);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013075, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013075);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013075, 400070013, 400070013001, 400070013075, 400070013004, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013075);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013081, 400070013075, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013081);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013081, 400070013081, 340.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013081);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013076, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken handi (half)(4pcs)'),
       'Chicken Handi (Half)(4pcs)', 'chicken handi (half)(4pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013076);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013076, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013076);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013076, 400070013, 400070013001, 400070013076, 400070013004, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013076);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013082, 400070013076, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013082);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013082, 400070013082, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013082);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013077, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kadai (3pcs)'),
       'Chicken Kadai (3pcs)', 'chicken kadai (3pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013077);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013077, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013077);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013077, 400070013, 400070013001, 400070013077, 400070013004, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013077);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013083, 400070013077, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013083);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013083, 400070013083, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013083);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013078, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken moghlai (3pcs)'),
       'Chicken Moghlai (3pcs)', 'chicken moghlai (3pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013078);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013078, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013078);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013078, 400070013, 400070013001, 400070013078, 400070013004, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013078);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013084, 400070013078, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013084);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013084, 400070013084, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013084);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013079, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken rashida (3pcs)'),
       'Chicken Rashida (3pcs)', 'chicken rashida (3pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013079);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013079, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013079);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013079, 400070013, 400070013001, 400070013079, 400070013004, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013079);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013085, 400070013079, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013085);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013085, 400070013085, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013085);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013080, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri (3pcs)'),
       'Chicken Kolhapuri (3pcs)', 'chicken kolhapuri (3pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013080);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013080, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013080);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013080, 400070013, 400070013001, 400070013080, 400070013004, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013080);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013086, 400070013080, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013086);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013086, 400070013086, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013086);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013081, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hangama (3pcs)'),
       'Chicken Hangama (3pcs)', 'chicken hangama (3pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013081);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013081, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013081);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013081, 400070013, 400070013001, 400070013081, 400070013004, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013081);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013087, 400070013081, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013087);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013087, 400070013087, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013087);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013082, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken toofani (3pcs)'),
       'Chicken Toofani (3pcs)', 'chicken toofani (3pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013082);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013082, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013082);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013082, 400070013, 400070013001, 400070013082, 400070013004, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013082);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013088, 400070013082, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013088);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013088, 400070013088, 120.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013088);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013083, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken masala fry (2pcs)'),
       'Chicken Masala Fry (2pcs)', 'chicken masala fry (2pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013083);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013083, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013083);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013083, 400070013, 400070013001, 400070013083, 400070013004, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013083);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013089, 400070013083, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013089);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013089, 400070013089, 120.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013089);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013084, 400070013, 400070013004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken korma (2pcs)'),
       'Chicken Korma (2pcs)', 'chicken korma (2pcs)', 'Chicken Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013084);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013084, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013084);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013084, 400070013, 400070013001, 400070013084, 400070013004, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013084);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013090, 400070013084, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013090);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013090, 400070013090, 120.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013090);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013085, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton special tavakkal (boneless)'),
       'Mutton Special Tavakkal (Boneless)', 'mutton special tavakkal (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013085);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013085, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013085);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013085, 400070013, 400070013001, 400070013085, 400070013005, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013085);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013091, 400070013085, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013091);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013091, 400070013091, 330.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013091);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013086, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton dabba gosht (boneless)'),
       'Mutton Dabba Gosht (Boneless)', 'mutton dabba gosht (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013086);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013086, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013086);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013086, 400070013, 400070013001, 400070013086, 400070013005, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013086);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013092, 400070013086, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013092);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013092, 400070013092, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013092);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013087, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton chingari (boneless)'),
       'Mutton Chingari (Boneless)', 'mutton chingari (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013087);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013087, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013087);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013087, 400070013, 400070013001, 400070013087, 400070013005, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013087);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013093, 400070013087, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013093);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013093, 400070013093, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013093);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013088, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton lazeez (boneless)'),
       'Mutton Lazeez (Boneless)', 'mutton lazeez (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013088);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013088, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013088);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013088, 400070013, 400070013001, 400070013088, 400070013005, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013088);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013094, 400070013088, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013094);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013094, 400070013094, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013094);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013089, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton chatpata (boneless)'),
       'Mutton Chatpata (Boneless)', 'mutton chatpata (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013089);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013089, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013089);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013089, 400070013, 400070013001, 400070013089, 400070013005, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013089);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013095, 400070013089, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013095);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013095, 400070013095, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013095);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013090, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton tawa (boneless)'),
       'Mutton Tawa (Boneless)', 'mutton tawa (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013090);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013090, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013090);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013090, 400070013, 400070013001, 400070013090, 400070013005, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013090);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013096, 400070013090, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013096);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013096, 400070013096, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013096);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013091, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton angara (boneless)'),
       'Mutton Angara (Boneless)', 'mutton angara (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013091);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013091, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013091);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013091, 400070013, 400070013001, 400070013091, 400070013005, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013091);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013097, 400070013091, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013097);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013097, 400070013097, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013097);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013092, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton nawabi (boneless)'),
       'Mutton Nawabi (Boneless)', 'mutton nawabi (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013092);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013092, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013092);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013092, 400070013, 400070013001, 400070013092, 400070013005, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013092);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013098, 400070013092, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013098);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013098, 400070013098, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013098);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013093, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton afghani (boneless)'),
       'Mutton Afghani (Boneless)', 'mutton afghani (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013093);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013093, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013093);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013093, 400070013, 400070013001, 400070013093, 400070013005, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013093);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013099, 400070013093, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013099);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013099, 400070013099, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013099);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013094, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton balti (boneless)'),
       'Mutton Balti (Boneless)', 'mutton balti (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013094);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013094, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013094);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013094, 400070013, 400070013001, 400070013094, 400070013005, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013094);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013100, 400070013094, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013100);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013100, 400070013100, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013100);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013095, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton hydrabadi (boneless)'),
       'Mutton Hydrabadi (Boneless)', 'mutton hydrabadi (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013095);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013095, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013095);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013095, 400070013, 400070013001, 400070013095, 400070013005, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013095);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013101, 400070013095, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013101);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013101, 400070013101, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013101);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013096, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton haryali (boneless)'),
       'Mutton Haryali (Boneless)', 'mutton haryali (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013096);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013096, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013096);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013096, 400070013, 400070013001, 400070013096, 400070013005, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013096);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013102, 400070013096, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013102);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013102, 400070013102, 270.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013102);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013097, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton lajawab (boneless)'),
       'Mutton Lajawab (Boneless)', 'mutton lajawab (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013097);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013097, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013097);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013097, 400070013, 400070013001, 400070013097, 400070013005, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013097);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013103, 400070013097, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013103);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013103, 400070013103, 270.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013103);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013098, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton zaika (boneless)'),
       'Mutton Zaika (Boneless)', 'mutton zaika (boneless)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013098);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013098, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013098);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013098, 400070013, 400070013001, 400070013098, 400070013005, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013098);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013104, 400070013098, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013104);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013104, 400070013104, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013104);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013099, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton handi (full) (6pcs)'),
       'Mutton Handi (Full) (6pcs)', 'mutton handi (full) (6pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013099);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013099, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013099);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013099, 400070013, 400070013001, 400070013099, 400070013005, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013099);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013105, 400070013099, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013105);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013105, 400070013105, 480.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013105);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013100, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton handi (half) (3pcs)'),
       'Mutton Handi (Half) (3pcs)', 'mutton handi (half) (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013100);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013100, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013100);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013100, 400070013, 400070013001, 400070013100, 400070013005, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013100);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013106, 400070013100, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013106);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013106, 400070013106, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013106);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013101, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton kadai (3pcs)'),
       'Mutton Kadai (3pcs)', 'mutton kadai (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013101);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013101, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013101);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013101, 400070013, 400070013001, 400070013101, 400070013005, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013101);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013107, 400070013101, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013107);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013107, 400070013107, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013107);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013102, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton moghlai (3pcs)'),
       'Mutton Moghlai (3pcs)', 'mutton moghlai (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013102);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013102, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013102);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013102, 400070013, 400070013001, 400070013102, 400070013005, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013102);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013108, 400070013102, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013108);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013108, 400070013108, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013108);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013103, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton rashida (3pcs)'),
       'Mutton Rashida (3pcs)', 'mutton rashida (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013103);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013103, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013103);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013103, 400070013, 400070013001, 400070013103, 400070013005, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013103);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013109, 400070013103, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013109);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013109, 400070013109, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013109);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013104, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton do pyaza (3pcs)'),
       'Mutton Do Pyaza (3pcs)', 'mutton do pyaza (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013104);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013104, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013104);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013104, 400070013, 400070013001, 400070013104, 400070013005, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013104);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013110, 400070013104, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013110);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013110, 400070013110, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013110);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013105, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri (3pcs)'),
       'Mutton Kolhapuri (3pcs)', 'mutton kolhapuri (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013105);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013105, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013105);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013105, 400070013, 400070013001, 400070013105, 400070013005, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013105);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013111, 400070013105, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013111);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013111, 400070013111, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013111);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013106, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton toofani (3pcs)'),
       'Mutton Toofani (3pcs)', 'mutton toofani (3pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013106);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013106, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013106);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013106, 400070013, 400070013001, 400070013106, 400070013005, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013106);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013112, 400070013106, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013112);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013112, 400070013112, 270.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013112);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013107, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton palak (2pcs)'),
       'Mutton Palak (2pcs)', 'mutton palak (2pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013107);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013107, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013107);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013107, 400070013, 400070013001, 400070013107, 400070013005, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013107);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013113, 400070013107, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013113);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013113, 400070013113, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013113);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013108, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton masala fry (2pcs)'),
       'Mutton Masala Fry (2pcs)', 'mutton masala fry (2pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013108);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013108, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013108);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013108, 400070013, 400070013001, 400070013108, 400070013005, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013108);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013114, 400070013108, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013114);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013114, 400070013114, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013114);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013109, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton korma (2pcs)'),
       'Mutton Korma (2pcs)', 'mutton korma (2pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013109);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013109, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013109);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013109, 400070013, 400070013001, 400070013109, 400070013005, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013109);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013115, 400070013109, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013115);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013115, 400070013115, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013115);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013110, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton dal ghost (2pcs)'),
       'Mutton Dal Ghost (2pcs)', 'mutton dal ghost (2pcs)', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013110);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013110, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013110);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013110, 400070013, 400070013001, 400070013110, 400070013005, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013110);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013116, 400070013110, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013116);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013116, 400070013116, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013116);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013111, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton kheema'),
       'Mutton Kheema', 'mutton kheema', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013111);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013111, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013111);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013111, 400070013, 400070013001, 400070013111, 400070013005, 27
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013111);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013117, 400070013111, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013117);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013117, 400070013117, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013117);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013118, 400070013111, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013118);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013118, 400070013118, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013118);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013112, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton kheema fry'),
       'Mutton Kheema Fry', 'mutton kheema fry', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013112);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013112, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013112);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013112, 400070013, 400070013001, 400070013112, 400070013005, 28
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013112);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013119, 400070013112, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013119);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013119, 400070013119, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013119);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013120, 400070013112, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013120);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013120, 400070013120, 110.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013120);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013113, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton kheema gotala'),
       'Mutton Kheema Gotala', 'mutton kheema gotala', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013113);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013113, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013113);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013113, 400070013, 400070013001, 400070013113, 400070013005, 29
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013113);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013121, 400070013113, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013121);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013121, 400070013121, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013121);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013122, 400070013113, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013122);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013122, 400070013122, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013122);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013114, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton brain masala fry'),
       'Mutton Brain Masala Fry', 'mutton brain masala fry', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013114);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013114, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013114);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013114, 400070013, 400070013001, 400070013114, 400070013005, 30
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013114);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013123, 400070013114, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013123);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013123, 400070013123, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013123);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013115, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton brain bhurji'),
       'Mutton Brain Bhurji', 'mutton brain bhurji', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013115);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013115, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013115);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013115, 400070013, 400070013001, 400070013115, 400070013005, 31
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013115);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013124, 400070013115, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013124);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013124, 400070013124, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013124);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013116, 400070013, 400070013005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton paya soup'),
       'Mutton Paya Soup', 'mutton paya soup', 'Mutton Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013116);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013116, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013116);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013116, 400070013, 400070013001, 400070013116, 400070013005, 32
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013116);
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week)
SELECT 400070013001, 400070013116, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_item_availability WHERE availability_id = 400070013001);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013125, 400070013116, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013125);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013125, 400070013125, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013125);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013117, 400070013, 400070013006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns special tavakkal'),
       'Prawns Special Tavakkal', 'prawns special tavakkal', 'Prawns Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013117);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013117, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013117);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013117, 400070013, 400070013001, 400070013117, 400070013006, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013117);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013126, 400070013117, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013126);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013126, 400070013126, 340.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013126);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013118, 400070013, 400070013006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns tawa'),
       'Prawns Tawa', 'prawns tawa', 'Prawns Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013118);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013118, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013118);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013118, 400070013, 400070013001, 400070013118, 400070013006, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013118);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013127, 400070013118, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013127);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013127, 400070013127, 290.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013127);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013119, 400070013, 400070013006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns angara'),
       'Prawns Angara', 'prawns angara', 'Prawns Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013119);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013119, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013119);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013119, 400070013, 400070013001, 400070013119, 400070013006, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013119);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013128, 400070013119, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013128);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013128, 400070013128, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013128);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013120, 400070013, 400070013006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns chingari'),
       'Prawns Chingari', 'prawns chingari', 'Prawns Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013120);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013120, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013120);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013120, 400070013, 400070013001, 400070013120, 400070013006, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013120);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013129, 400070013120, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013129);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013129, 400070013129, 270.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013129);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013121, 400070013, 400070013006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns handi'),
       'Prawns Handi', 'prawns handi', 'Prawns Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013121);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013121, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013121);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013121, 400070013, 400070013001, 400070013121, 400070013006, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013121);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013130, 400070013121, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013130);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013130, 400070013130, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013130);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013122, 400070013, 400070013006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns masala fry'),
       'Prawns Masala Fry', 'prawns masala fry', 'Prawns Main Course', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013122);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013122, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013122);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013122, 400070013, 400070013001, 400070013122, 400070013006, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013122);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013131, 400070013122, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013131);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013131, 400070013131, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013131);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013123, 400070013, 400070013007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg masala fry (2 egg)'),
       'Egg Masala Fry (2 Egg)', 'egg masala fry (2 egg)', 'Egg Main Course', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013123);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013123, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013123);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013123, 400070013, 400070013001, 400070013123, 400070013007, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013123);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013132, 400070013123, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013132);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013132, 400070013132, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013132);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013124, 400070013, 400070013007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg curry (2 egg)'),
       'Egg Curry (2 Egg)', 'egg curry (2 egg)', 'Egg Main Course', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013124);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013124, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013124);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013124, 400070013, 400070013001, 400070013124, 400070013007, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013124);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013133, 400070013124, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013133);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013133, 400070013133, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013133);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013125, 400070013, 400070013007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg bhurji (2 egg)'),
       'Egg Bhurji (2 Egg)', 'egg bhurji (2 egg)', 'Egg Main Course', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013125);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013125, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013125);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013125, 400070013, 400070013001, 400070013125, 400070013007, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013125);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013134, 400070013125, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013134);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013134, 400070013134, 80.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013134);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013126, 400070013, 400070013007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg omlet (2 egg)'),
       'Egg Omlet (2 Egg)', 'egg omlet (2 egg)', 'Egg Main Course', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013126);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013126, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013126);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013126, 400070013, 400070013001, 400070013126, 400070013007, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013126);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013135, 400070013126, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013135);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013135, 400070013135, 50.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013135);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013127, 400070013, 400070013007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg half fry (2 egg)'),
       'Egg Half Fry (2 Egg)', 'egg half fry (2 egg)', 'Egg Main Course', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013127);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013127, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013127);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013127, 400070013, 400070013001, 400070013127, 400070013007, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013127);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013136, 400070013127, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013136);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013136, 400070013136, 50.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013136);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013128, 400070013, 400070013007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'boiled egg (1pcs)'),
       'Boiled Egg (1pcs)', 'boiled egg (1pcs)', 'Egg Main Course', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013128);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013128, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013128);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013128, 400070013, 400070013001, 400070013128, 400070013007, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013128);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013137, 400070013128, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013137);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013137, 400070013137, 15.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013137);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013129, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer special tavakkal'),
       'Paneer Special Tavakkal', 'paneer special tavakkal', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013129);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013129, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013129);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013129, 400070013, 400070013001, 400070013129, 400070013008, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013129);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013138, 400070013129, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013138);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013138, 400070013138, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013138);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013130, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tawa'),
       'Paneer Tawa', 'paneer tawa', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013130);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013130, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013130);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013130, 400070013, 400070013001, 400070013130, 400070013008, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013130);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013139, 400070013130, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013139);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013139, 400070013139, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013139);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013131, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chatpata'),
       'Paneer Chatpata', 'paneer chatpata', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013131);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013131, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013131);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013131, 400070013, 400070013001, 400070013131, 400070013008, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013131);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013140, 400070013131, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013140);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013140, 400070013140, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013140);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013132, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer angara'),
       'Paneer Angara', 'paneer angara', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013132);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013132, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013132);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013132, 400070013, 400070013001, 400070013132, 400070013008, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013132);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013141, 400070013132, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013141);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013141, 400070013141, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013141);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013133, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer lazeez'),
       'Paneer Lazeez', 'paneer lazeez', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013133);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013133, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013133);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013133, 400070013, 400070013001, 400070013133, 400070013008, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013133);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013142, 400070013133, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013142);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013142, 400070013142, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013142);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013134, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chingari'),
       'Paneer Chingari', 'paneer chingari', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013134);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013134, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013134);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013134, 400070013, 400070013001, 400070013134, 400070013008, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013134);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013143, 400070013134, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013143);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013143, 400070013143, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013143);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013135, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer nawabi'),
       'Paneer Nawabi', 'paneer nawabi', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013135);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013135, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013135);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013135, 400070013, 400070013001, 400070013135, 400070013008, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013135);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013144, 400070013135, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013144);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013144, 400070013144, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013144);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013136, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer harbhara'),
       'Paneer Harbhara', 'paneer harbhara', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013136);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013136, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013136);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013136, 400070013, 400070013001, 400070013136, 400070013008, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013136);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013145, 400070013136, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013145);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013145, 400070013145, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013145);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013137, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer lajawab'),
       'Paneer Lajawab', 'paneer lajawab', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013137);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013137, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013137);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013137, 400070013, 400070013001, 400070013137, 400070013008, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013137);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013146, 400070013137, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013146);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013146, 400070013146, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013146);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013138, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer hydrabadi'),
       'Paneer Hydrabadi', 'paneer hydrabadi', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013138);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013138, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013138);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013138, 400070013, 400070013001, 400070013138, 400070013008, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013138);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013147, 400070013138, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013147);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013147, 400070013147, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013147);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013139, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer methi'),
       'Paneer Methi', 'paneer methi', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013139);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013139, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013139);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013139, 400070013, 400070013001, 400070013139, 400070013008, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013139);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013148, 400070013139, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013148);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013148, 400070013148, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013148);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013140, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka masala fry'),
       'Paneer Tikka Masala Fry', 'paneer tikka masala fry', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013140);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013140, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013140);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013140, 400070013, 400070013001, 400070013140, 400070013008, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013140);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013149, 400070013140, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013149);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013149, 400070013149, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013149);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013141, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kolhapuri'),
       'Paneer Kolhapuri', 'paneer kolhapuri', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013141);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013141, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013141);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013141, 400070013, 400070013001, 400070013141, 400070013008, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013141);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013150, 400070013141, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013150);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013150, 400070013150, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013150);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013142, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kadai'),
       'Paneer Kadai', 'paneer kadai', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013142);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013142, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013142);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013142, 400070013, 400070013001, 400070013142, 400070013008, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013142);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013151, 400070013142, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013151);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013151, 400070013151, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013151);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013143, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer handi'),
       'Paneer Handi', 'paneer handi', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013143);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013143, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013143);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013143, 400070013, 400070013001, 400070013143, 400070013008, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013143);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013152, 400070013143, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013152);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013152, 400070013152, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013152);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013153, 400070013143, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013153);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013153, 400070013153, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013153);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013144, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka handi'),
       'Paneer Tikka Handi', 'paneer tikka handi', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013144);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013144, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013144);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013144, 400070013, 400070013001, 400070013144, 400070013008, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013144);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013154, 400070013144, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013154);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013154, 400070013154, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013154);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013145, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer makhanwala'),
       'Paneer Makhanwala', 'paneer makhanwala', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013145);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013145, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013145);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013145, 400070013, 400070013001, 400070013145, 400070013008, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013145);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013155, 400070013145, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013155);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013155, 400070013155, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013155);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013146, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'shahi paneer'),
       'Shahi Paneer', 'shahi paneer', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013146);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013146, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013146);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013146, 400070013, 400070013001, 400070013146, 400070013008, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013146);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013156, 400070013146, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013156);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013156, 400070013156, 350.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013156);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013147, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer lahori (jumbo)'),
       'Paneer Lahori (Jumbo)', 'paneer lahori (jumbo)', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013147);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013147, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013147);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013147, 400070013, 400070013001, 400070013147, 400070013008, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013147);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013157, 400070013147, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013157);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013157, 400070013157, 350.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013157);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013148, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer maharaja (jumbo)'),
       'Paneer Maharaja (Jumbo)', 'paneer maharaja (jumbo)', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013148);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013148, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013148);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013148, 400070013, 400070013001, 400070013148, 400070013008, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013148);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013158, 400070013148, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013158);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013158, 400070013158, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013158);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013149, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer mushroom masala'),
       'Paneer Mushroom Masala', 'paneer mushroom masala', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013149);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013149, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013149);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013149, 400070013, 400070013001, 400070013149, 400070013008, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013149);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013159, 400070013149, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013159);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013159, 400070013159, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013159);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013150, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer matar'),
       'Paneer Matar', 'paneer matar', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013150);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013150, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013150);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013150, 400070013, 400070013001, 400070013150, 400070013008, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013150);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013160, 400070013150, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013160);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013160, 400070013160, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013160);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013151, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer palak'),
       'Paneer Palak', 'paneer palak', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013151);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013151, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013151);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013151, 400070013, 400070013001, 400070013151, 400070013008, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013151);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013161, 400070013151, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013161);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013161, 400070013161, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013161);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013152, 400070013, 400070013008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer butter masala'),
       'Paneer Butter Masala', 'paneer butter masala', 'Paneer Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013152);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013152, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013152);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013152, 400070013, 400070013001, 400070013152, 400070013008, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013152);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013162, 400070013152, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013162);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013162, 400070013162, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013162);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013153, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer masala fry'),
       'Paneer Masala Fry', 'paneer masala fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013153);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013153, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013153);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013153, 400070013, 400070013001, 400070013153, 400070013009, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013153);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013163, 400070013153, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013163);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013163, 400070013163, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013163);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013154, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer bhurji'),
       'Paneer Bhurji', 'paneer bhurji', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013154);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013154, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013154);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013154, 400070013, 400070013001, 400070013154, 400070013009, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013154);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013164, 400070013154, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013164);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013164, 400070013164, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013164);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013155, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom masala fry'),
       'Mushroom Masala Fry', 'mushroom masala fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013155);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013155, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013155);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013155, 400070013, 400070013001, 400070013155, 400070013009, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013155);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013165, 400070013155, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013165);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013165, 400070013165, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013165);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013156, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. special tavakkal'),
       'Veg. Special Tavakkal', 'veg. special tavakkal', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013156);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013156, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013156);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013156, 400070013, 400070013001, 400070013156, 400070013009, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013156);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013166, 400070013156, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013166);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013166, 400070013166, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013166);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013157, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. angara'),
       'Veg. Angara', 'veg. angara', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013157);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013157, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013157);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013157, 400070013, 400070013001, 400070013157, 400070013009, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013157);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013167, 400070013157, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013167);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013167, 400070013167, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013167);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013158, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. lazeez'),
       'Veg. Lazeez', 'veg. lazeez', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013158);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013158, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013158);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013158, 400070013, 400070013001, 400070013158, 400070013009, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013158);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013168, 400070013158, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013168);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013168, 400070013168, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013168);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013159, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. tawa'),
       'Veg. Tawa', 'veg. tawa', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013159);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013159, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013159);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013159, 400070013, 400070013001, 400070013159, 400070013009, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013159);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013169, 400070013159, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013169);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013169, 400070013169, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013169);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013160, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. hydrabadi'),
       'Veg. Hydrabadi', 'veg. hydrabadi', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013160);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013160, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013160);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013160, 400070013, 400070013001, 400070013160, 400070013009, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013160);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013170, 400070013160, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013170);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013170, 400070013170, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013170);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013161, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. kadai'),
       'Veg. Kadai', 'veg. kadai', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013161);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013161, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013161);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013161, 400070013, 400070013001, 400070013161, 400070013009, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013161);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013171, 400070013161, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013171);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013171, 400070013171, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013171);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013162, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. handi'),
       'Veg. Handi', 'veg. handi', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013162);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013162, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013162);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013162, 400070013, 400070013001, 400070013162, 400070013009, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013162);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013172, 400070013162, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013172);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013172, 400070013172, 290.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013172);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013173, 400070013162, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013173);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013173, 400070013173, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013173);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013163, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. makhanwala'),
       'Veg. Makhanwala', 'veg. makhanwala', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013163);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013163, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013163);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013163, 400070013, 400070013001, 400070013163, 400070013009, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013163);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013174, 400070013163, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013174);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013174, 400070013174, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013174);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013164, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. kolhapuri'),
       'Veg. Kolhapuri', 'veg. kolhapuri', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013164);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013164, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013164);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013164, 400070013, 400070013001, 400070013164, 400070013009, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013164);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013175, 400070013164, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013175);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013175, 400070013175, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013175);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013165, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kaju masala'),
       'Kaju Masala', 'kaju masala', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013165);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013165, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013165);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013165, 400070013, 400070013001, 400070013165, 400070013009, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013165);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013176, 400070013165, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013176);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013176, 400070013176, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013176);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013166, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'bhindi masala fry'),
       'Bhindi Masala Fry', 'bhindi masala fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013166);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013166, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013166);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013166, 400070013, 400070013001, 400070013166, 400070013009, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013166);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013177, 400070013166, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013177);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013177, 400070013177, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013177);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013167, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix vegetable fry'),
       'Mix Vegetable Fry', 'mix vegetable fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013167);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013167, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013167);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013167, 400070013, 400070013001, 400070013167, 400070013009, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013167);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013178, 400070013167, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013178);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013178, 400070013178, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013178);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013168, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo palak fry'),
       'Aloo Palak Fry', 'aloo palak fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013168);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013168, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013168);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013168, 400070013, 400070013001, 400070013168, 400070013009, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013168);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013179, 400070013168, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013179);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013179, 400070013179, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013179);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013169, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo matar fry'),
       'Aloo Matar Fry', 'aloo matar fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013169);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013169, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013169);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013169, 400070013, 400070013001, 400070013169, 400070013009, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013169);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013180, 400070013169, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013180);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013180, 400070013180, 120.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013180);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013170, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'masoor masala / aloo masoor'),
       'Masoor Masala / Aloo Masoor', 'masoor masala / aloo masoor', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013170);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013170, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013170);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013170, 400070013, 400070013001, 400070013170, 400070013009, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013170);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013181, 400070013170, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013181);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013181, 400070013181, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013181);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013171, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chana masala fry'),
       'Chana Masala Fry', 'chana masala fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013171);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013171, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013171);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013171, 400070013, 400070013001, 400070013171, 400070013009, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013171);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013182, 400070013171, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013182);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013182, 400070013182, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013182);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013172, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sev bhaji'),
       'Sev Bhaji', 'sev bhaji', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013172);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013172, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013172);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013172, 400070013, 400070013001, 400070013172, 400070013009, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013172);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013183, 400070013172, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013183);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013183, 400070013183, 110.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013183);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013173, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'shahi dal'),
       'Shahi Dal', 'shahi dal', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013173);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013173, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013173);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013173, 400070013, 400070013001, 400070013173, 400070013009, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013173);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013184, 400070013173, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013184);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013184, 400070013184, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013184);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013174, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal tadka'),
       'Dal Tadka', 'dal tadka', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013174);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013174, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013174);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013174, 400070013, 400070013001, 400070013174, 400070013009, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013174);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013185, 400070013174, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013185);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013185, 400070013185, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013185);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013175, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter dal fry'),
       'Butter Dal Fry', 'butter dal fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013175);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013175, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013175);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013175, 400070013, 400070013001, 400070013175, 400070013009, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013175);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013186, 400070013175, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013186);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013186, 400070013186, 90.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013186);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013176, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal fry'),
       'Dal Fry', 'dal fry', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013176);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013176, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013176);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013176, 400070013, 400070013001, 400070013176, 400070013009, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013176);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013187, 400070013176, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013187);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013187, 400070013187, 80.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013187);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013177, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'plain gravy'),
       'Plain Gravy', 'plain gravy', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013177);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013177, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013177);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013177, 400070013, 400070013001, 400070013177, 400070013009, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013177);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013188, 400070013177, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013188);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013188, 400070013188, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013188);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013178, 400070013, 400070013009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'today special bhaji'),
       'Today Special Bhaji', 'today special bhaji', 'Vegetable Main Course', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013178);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013178, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013178);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013178, 400070013, 400070013001, 400070013178, 400070013009, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013178);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013189, 400070013178, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013189);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013189, 400070013189, 100.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013189);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013179, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken thali'),
       'Chicken Thali', 'chicken thali', 'Special Thali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013179);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013179, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013179);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013179, 400070013, 400070013001, 400070013179, 400070013010, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013179);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013190, 400070013179, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013190);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013190, 400070013190, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013190);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013191, 400070013179, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013191);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013191, 400070013191, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013191);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013180, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton thali'),
       'Mutton Thali', 'mutton thali', 'Special Thali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013180);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013180, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013180);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013180, 400070013, 400070013001, 400070013180, 400070013010, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013180);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013192, 400070013180, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013192);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013192, 400070013192, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013192);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013193, 400070013180, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013193);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013193, 400070013193, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013193);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013181, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. thali'),
       'Veg. Thali', 'veg. thali', 'Special Thali', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013181);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013181, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013181);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013181, 400070013, 400070013001, 400070013181, 400070013010, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013181);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013194, 400070013181, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013194);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013194, 400070013194, 120.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013194);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013195, 400070013181, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013195);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013195, 400070013195, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013195);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013182, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. special thali'),
       'Veg. Special Thali', 'veg. special thali', 'Special Thali', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013182);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013182, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013182);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013182, 400070013, 400070013001, 400070013182, 400070013010, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013182);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013196, 400070013182, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013196);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013196, 400070013196, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013196);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013197, 400070013182, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013197);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013197, 400070013197, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013197);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013183, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka thali'),
       'Paneer Tikka Thali', 'paneer tikka thali', 'Special Thali', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013183);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013183, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013183);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013183, 400070013, 400070013001, 400070013183, 400070013010, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013183);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013198, 400070013183, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013198);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013198, 400070013198, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013198);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013199, 400070013183, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013199);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013199, 400070013199, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013199);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013184, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer thali'),
       'Paneer Thali', 'paneer thali', 'Special Thali', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013184);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013184, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013184);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013184, 400070013, 400070013001, 400070013184, 400070013010, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013184);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013200, 400070013184, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013200);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013200, 400070013200, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013200);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013201, 400070013184, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013201);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013201, 400070013201, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013201);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013185, 400070013, 400070013010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns thali'),
       'Prawns Thali', 'prawns thali', 'Special Thali', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013185);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013185, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013185);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013185, 400070013, 400070013001, 400070013185, 400070013010, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013185);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013202, 400070013185, 'Table', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013202);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013202, 400070013202, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013202);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013203, 400070013185, 'Parcel', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013203);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013203, 400070013203, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013203);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013186, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chapati'),
       'Chapati', 'chapati', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013186);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013186, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013186);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013186, 400070013, 400070013001, 400070013186, 400070013011, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013186);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013204, 400070013186, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013204);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013204, 400070013204, 10.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013204);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013187, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter chapati'),
       'Butter Chapati', 'butter chapati', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013187);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013187, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013187);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013187, 400070013, 400070013001, 400070013187, 400070013011, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013187);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013205, 400070013187, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013205);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013205, 400070013205, 15.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013205);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013188, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori roti'),
       'Tandoori Roti', 'tandoori roti', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013188);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013188, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013188);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013188, 400070013, 400070013001, 400070013188, 400070013011, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013188);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013206, 400070013188, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013206);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013206, 400070013206, 12.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013206);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013189, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori butter roti'),
       'Tandoori Butter Roti', 'tandoori butter roti', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013189);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013189, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013189);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013189, 400070013, 400070013001, 400070013189, 400070013011, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013189);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013207, 400070013189, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013207);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013207, 400070013207, 18.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013207);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013190, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori butter paratha'),
       'Tandoori Butter Paratha', 'tandoori butter paratha', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013190);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013190, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013190);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013190, 400070013, 400070013001, 400070013190, 400070013011, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013190);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013208, 400070013190, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013208);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013208, 400070013208, 45.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013208);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013191, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori butter naan'),
       'Tandoori Butter Naan', 'tandoori butter naan', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013191);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013191, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013191);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013191, 400070013, 400070013001, 400070013191, 400070013011, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013191);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013209, 400070013191, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013209);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013209, 400070013209, 40.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013209);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013192, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori butter kulcha'),
       'Tandoori Butter Kulcha', 'tandoori butter kulcha', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013192);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013192, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013192);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013192, 400070013, 400070013001, 400070013192, 400070013011, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013192);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013210, 400070013192, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013210);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013210, 400070013210, 50.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013210);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013193, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori butter garlic naan'),
       'Tandoori Butter Garlic Naan', 'tandoori butter garlic naan', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013193);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013193, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013193);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013193, 400070013, 400070013001, 400070013193, 400070013011, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013193);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013211, 400070013193, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013211);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013211, 400070013211, 70.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013211);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013194, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori naan'),
       'Tandoori Naan', 'tandoori naan', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013194);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013194, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013194);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013194, 400070013, 400070013001, 400070013194, 400070013011, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013194);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013212, 400070013194, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013212);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013212, 400070013212, 35.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013212);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013195, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pav'),
       'Pav', 'pav', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013195);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013195, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013195);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013195, 400070013, 400070013001, 400070013195, 400070013011, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013195);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013213, 400070013195, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013213);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013213, 400070013213, 5.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013213);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013196, 400070013, 400070013011, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'pav (garam)'),
       'Pav (Garam)', 'pav (garam)', 'Roti Ki Tokri', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013196);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013196, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013196);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013196, 400070013, 400070013001, 400070013196, 400070013011, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013196);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013214, 400070013196, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013214);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013214, 400070013214, 10.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013214);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013197, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani (3pcs)'),
       'Chicken Tikka Biryani (3pcs)', 'chicken tikka biryani (3pcs)', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013197);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013197, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013197);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013197, 400070013, 400070013001, 400070013197, 400070013012, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013197);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013215, 400070013197, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013215);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013215, 400070013215, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013215);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013198, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken biryani (2pcs)'),
       'Chicken Biryani (2pcs)', 'chicken biryani (2pcs)', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013198);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013198, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013198);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013198, 400070013, 400070013001, 400070013198, 400070013012, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013198);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013216, 400070013198, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013216);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013216, 400070013216, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013216);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013199, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi biryani'),
       'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013199);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013199, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013199);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013199, 400070013, 400070013001, 400070013199, 400070013012, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013199);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013217, 400070013199, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013217);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013217, 400070013217, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013217);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013200, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken leg tandoori biryani'),
       'Chicken Leg Tandoori Biryani', 'chicken leg tandoori biryani', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013200);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013200, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013200);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013200, 400070013, 400070013001, 400070013200, 400070013012, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013200);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013218, 400070013200, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013218);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013218, 400070013218, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013218);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013201, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton biryani (2pcs)'),
       'Mutton Biryani (2pcs)', 'mutton biryani (2pcs)', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013201);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013201, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013201);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013201, 400070013, 400070013001, 400070013201, 400070013012, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013201);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013219, 400070013201, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013219);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013219, 400070013219, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013219);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013202, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton hydrabadi biryani'),
       'Mutton Hydrabadi Biryani', 'mutton hydrabadi biryani', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013202);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013202, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013202);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013202, 400070013, 400070013001, 400070013202, 400070013012, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013202);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013220, 400070013202, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013220);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013220, 400070013220, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013220);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013203, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns biryani'),
       'Prawns Biryani', 'prawns biryani', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013203);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013203, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013203);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013203, 400070013, 400070013001, 400070013203, 400070013012, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013203);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013221, 400070013203, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013221);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013221, 400070013221, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013221);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013204, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg biryani (2pcs)'),
       'Egg Biryani (2pcs)', 'egg biryani (2pcs)', 'Biryani / Rice / Pulao', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013204);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013204, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013204);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013204, 400070013, 400070013001, 400070013204, 400070013012, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013204);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013222, 400070013204, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013222);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013222, 400070013222, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013222);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013205, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani (2pcs)'),
       'Paneer Tikka Biryani (2pcs)', 'paneer tikka biryani (2pcs)', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013205);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013205, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013205);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013205, 400070013, 400070013001, 400070013205, 400070013012, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013205);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013223, 400070013205, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013223);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013223, 400070013223, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013223);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013206, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer biryani'),
       'Paneer Biryani', 'paneer biryani', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013206);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013206, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013206);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013206, 400070013, 400070013001, 400070013206, 400070013012, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013206);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013224, 400070013206, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013224);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013224, 400070013224, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013224);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013207, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hyderabadi biryani'),
       'Veg Hyderabadi Biryani', 'veg hyderabadi biryani', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013207);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013207, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013207);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013207, 400070013, 400070013001, 400070013207, 400070013012, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013207);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013225, 400070013207, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013225);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013225, 400070013225, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013225);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013208, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg biryani'),
       'Veg Biryani', 'veg biryani', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013208);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013208, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013208);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013208, 400070013, 400070013001, 400070013208, 400070013012, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013208);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013226, 400070013208, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013226);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013226, 400070013226, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013226);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013209, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken pulao'),
       'Chicken Pulao', 'chicken pulao', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013209);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013209, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013209);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013209, 400070013, 400070013001, 400070013209, 400070013012, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013209);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013227, 400070013209, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013227);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013227, 400070013227, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013227);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013210, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton pulao'),
       'Mutton Pulao', 'mutton pulao', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013210);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013210, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013210);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013210, 400070013, 400070013001, 400070013210, 400070013012, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013210);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013228, 400070013210, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013228);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013228, 400070013228, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013228);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013211, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns pulao'),
       'Prawns Pulao', 'prawns pulao', 'Biryani / Rice / Pulao', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013211);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013211, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013211);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013211, 400070013, 400070013001, 400070013211, 400070013012, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013211);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013229, 400070013211, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013229);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013229, 400070013229, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013229);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013212, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg pulao'),
       'Egg Pulao', 'egg pulao', 'Biryani / Rice / Pulao', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013212);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013212, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013212);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013212, 400070013, 400070013001, 400070013212, 400070013012, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013212);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013230, 400070013212, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013230);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013230, 400070013230, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013230);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013213, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer pulao'),
       'Paneer Pulao', 'paneer pulao', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013213);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013213, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013213);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013213, 400070013, 400070013001, 400070013213, 400070013012, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013213);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013231, 400070013213, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013231);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013231, 400070013231, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013231);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013214, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg pulao'),
       'Veg Pulao', 'veg pulao', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013214);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013214, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013214);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013214, 400070013, 400070013001, 400070013214, 400070013012, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013214);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013232, 400070013214, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013232);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013232, 400070013232, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013232);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013215, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal khichdi tadka'),
       'Dal Khichdi Tadka', 'dal khichdi tadka', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013215);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013215, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013215);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013215, 400070013, 400070013001, 400070013215, 400070013012, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013215);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013233, 400070013215, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013233);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013233, 400070013233, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013233);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013216, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal khichdi butter'),
       'Dal Khichdi Butter', 'dal khichdi butter', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013216);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013216, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013216);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013216, 400070013, 400070013001, 400070013216, 400070013012, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013216);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013234, 400070013216, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013234);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013234, 400070013234, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013234);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013217, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal khichdi'),
       'Dal Khichdi', 'dal khichdi', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013217);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013217, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013217);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013217, 400070013, 400070013001, 400070013217, 400070013012, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013217);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013235, 400070013217, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013235);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013235, 400070013235, 120.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013235);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013218, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'jeera rice'),
       'Jeera Rice', 'jeera rice', 'Biryani / Rice / Pulao', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013218);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013218, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013218);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013218, 400070013, 400070013001, 400070013218, 400070013012, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013218);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013236, 400070013218, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013236);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013236, 400070013236, 110.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013236);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013237, 400070013218, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013237);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013237, 400070013237, 80.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013237);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013219, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'white rice'),
       'White Rice', 'white rice', 'Biryani / Rice / Pulao', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013219);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013219, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013219);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013219, 400070013, 400070013001, 400070013219, 400070013012, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013219);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013238, 400070013219, 'Half', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013238);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013238, 400070013238, 45.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013238);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013220, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'steam rice'),
       'Steam Rice', 'steam rice', 'Biryani / Rice / Pulao', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013220);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013220, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013220);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013220, 400070013, 400070013001, 400070013220, 400070013012, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013220);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013239, 400070013220, 'Half', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013239);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013239, 400070013239, 50.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013239);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013221, 400070013, 400070013012, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal rice'),
       'Dal Rice', 'dal rice', 'Biryani / Rice / Pulao', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013221);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013221, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013221);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013221, 400070013, 400070013001, 400070013221, 400070013012, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013221);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013240, 400070013221, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013240);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013240, 400070013240, 110.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013240);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013222, 400070013, 400070013013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tavakkal special soup'),
       'Chicken Tavakkal Special Soup', 'chicken tavakkal special soup', 'Chinese Soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013222);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013222, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013222);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013222, 400070013, 400070013001, 400070013222, 400070013013, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013222);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013241, 400070013222, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013241);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013241, 400070013241, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013241);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013223, 400070013, 400070013013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken manchow soup'),
       'Chicken Manchow Soup', 'chicken manchow soup', 'Chinese Soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013223);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013223, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013223);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013223, 400070013, 400070013001, 400070013223, 400070013013, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013223);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013242, 400070013223, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013242);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013242, 400070013242, 110.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013242);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013224, 400070013, 400070013013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hot & sour soup'),
       'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'Chinese Soup', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013224);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013224, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013224);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013224, 400070013, 400070013001, 400070013224, 400070013013, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013224);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013243, 400070013224, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013243);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013243, 400070013243, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013243);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013225, 400070013, 400070013013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. manchow soup'),
       'Veg. Manchow Soup', 'veg. manchow soup', 'Chinese Soup', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013225);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013225, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013225);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013225, 400070013, 400070013001, 400070013225, 400070013013, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013225);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013244, 400070013225, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013244);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013244, 400070013244, 110.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013244);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013226, 400070013, 400070013013, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. hot & sour soup'),
       'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'Chinese Soup', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013226);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013226, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013226);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013226, 400070013, 400070013001, 400070013226, 400070013013, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013226);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013245, 400070013226, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013245);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013245, 400070013245, 130.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013245);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013227, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken lolipop gravy (6pcs)'),
       'Chicken Lolipop Gravy (6pcs)', 'chicken lolipop gravy (6pcs)', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013227);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013227, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013227);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013227, 400070013, 400070013001, 400070013227, 400070013014, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013227);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013246, 400070013227, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013246);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013246, 400070013246, 280.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013246);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013228, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chilly gravy'),
       'Chicken Chilly Gravy', 'chicken chilly gravy', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013228);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013228, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013228);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013228, 400070013, 400070013001, 400070013228, 400070013014, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013228);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013247, 400070013228, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013247);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013247, 400070013247, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013247);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013229, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken manchurian gravy'),
       'Chicken Manchurian Gravy', 'chicken manchurian gravy', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013229);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013229, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013229);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013229, 400070013, 400070013001, 400070013229, 400070013014, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013229);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013248, 400070013229, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013248);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013248, 400070013248, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013248);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013230, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken 65 gravy'),
       'Chicken 65 Gravy', 'chicken 65 gravy', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013230);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013230, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013230);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013230, 400070013, 400070013001, 400070013230, 400070013014, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013230);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013249, 400070013230, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013249);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013249, 400070013249, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013249);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013231, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan gravy'),
       'Chicken Schezwan Gravy', 'chicken schezwan gravy', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013231);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013231, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013231);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013231, 400070013, 400070013001, 400070013231, 400070013014, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013231);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013250, 400070013231, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013250);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013250, 400070013250, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013250);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013232, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chilly gravy'),
       'Paneer Chilly Gravy', 'paneer chilly gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013232);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013232, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013232);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013232, 400070013, 400070013001, 400070013232, 400070013014, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013232);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013251, 400070013232, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013251);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013251, 400070013251, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013251);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013233, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer 65 gravy'),
       'Paneer 65 Gravy', 'paneer 65 gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013233);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013233, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013233);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013233, 400070013, 400070013001, 400070013233, 400070013014, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013233);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013252, 400070013233, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013252);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013252, 400070013252, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013252);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013234, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer manchurian gravy'),
       'Paneer Manchurian Gravy', 'paneer manchurian gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013234);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013234, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013234);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013234, 400070013, 400070013001, 400070013234, 400070013014, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013234);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013253, 400070013234, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013253);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013253, 400070013253, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013253);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013235, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. chilly gravy'),
       'Veg. Chilly Gravy', 'veg. chilly gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013235);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013235, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013235);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013235, 400070013, 400070013001, 400070013235, 400070013014, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013235);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013254, 400070013235, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013254);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013254, 400070013254, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013254);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013236, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. manchurian gravy'),
       'Veg. Manchurian Gravy', 'veg. manchurian gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013236);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013236, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013236);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013236, 400070013, 400070013001, 400070013236, 400070013014, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013236);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013255, 400070013236, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013255);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013255, 400070013255, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013255);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013237, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg. 65 gravy'),
       'Veg. 65 Gravy', 'veg. 65 gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013237);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013237, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013237);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013237, 400070013, 400070013001, 400070013237, 400070013014, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013237);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013256, 400070013237, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013256);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013256, 400070013256, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013256);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013238, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns chilly gravy'),
       'Prawns Chilly Gravy', 'prawns chilly gravy', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013238);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013238, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013238);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013238, 400070013, 400070013001, 400070013238, 400070013014, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013238);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013257, 400070013238, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013257);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013257, 400070013257, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013257);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013239, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns 65 gravy'),
       'Prawns 65 Gravy', 'prawns 65 gravy', 'Chinese Gravy', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013239);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013239, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013239);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013239, 400070013, 400070013001, 400070013239, 400070013014, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013239);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013258, 400070013239, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013258);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013258, 400070013258, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013258);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013240, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom chilly gravy'),
       'Mushroom Chilly Gravy', 'mushroom chilly gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013240);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013240, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013240);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013240, 400070013, 400070013001, 400070013240, 400070013014, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013240);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013259, 400070013240, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013259);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013259, 400070013259, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013259);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013241, 400070013, 400070013014, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom 65 gravy'),
       'Mushroom 65 Gravy', 'mushroom 65 gravy', 'Chinese Gravy', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013241);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013241, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013241);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013241, 400070013, 400070013001, 400070013241, 400070013014, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013241);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013260, 400070013241, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013260);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013260, 400070013260, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013260);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013242, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tripple schezwan rice'),
       'Chicken Tripple Schezwan Rice', 'chicken tripple schezwan rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013242);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013242, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013242);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013242, 400070013, 400070013001, 400070013242, 400070013015, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013242);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013261, 400070013242, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013261);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013261, 400070013261, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013261);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013243, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chopper rice'),
       'Chicken Chopper Rice', 'chicken chopper rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013243);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013243, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013243);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013243, 400070013, 400070013001, 400070013243, 400070013015, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013243);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013262, 400070013243, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013262);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013262, 400070013262, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013262);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013244, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken manchurian rice'),
       'Chicken Manchurian Rice', 'chicken manchurian rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013244);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013244, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013244);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013244, 400070013, 400070013001, 400070013244, 400070013015, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013244);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013263, 400070013244, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013263);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013263, 400070013263, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013263);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013245, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chilly rice'),
       'Chicken Chilly Rice', 'chicken chilly rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013245);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013245, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013245);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013245, 400070013, 400070013001, 400070013245, 400070013015, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013245);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013264, 400070013245, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013264);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013264, 400070013264, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013264);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013246, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken singapore rice'),
       'Chicken Singapore Rice', 'chicken singapore rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013246);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013246, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013246);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013246, 400070013, 400070013001, 400070013246, 400070013015, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013246);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013265, 400070013246, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013265);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013265, 400070013265, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013265);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013247, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hongkong rice'),
       'Chicken Hongkong Rice', 'chicken hongkong rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013247);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013247, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013247);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013247, 400070013, 400070013001, 400070013247, 400070013015, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013247);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013266, 400070013247, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013266);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013266, 400070013266, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013266);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013248, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken combo rice'),
       'Chicken Combo Rice', 'chicken combo rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013248);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013248, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013248);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013248, 400070013, 400070013001, 400070013248, 400070013015, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013248);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013267, 400070013248, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013267);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013267, 400070013267, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013267);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013249, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken combo schezwan rice'),
       'Chicken Combo Schezwan Rice', 'chicken combo schezwan rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013249);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013249, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013249);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013249, 400070013, 400070013001, 400070013249, 400070013015, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013249);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013268, 400070013249, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013268);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013268, 400070013268, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013268);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013250, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken fried rice'),
       'Chicken Fried Rice', 'chicken fried rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013250);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013250, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013250);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013250, 400070013, 400070013001, 400070013250, 400070013015, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013250);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013269, 400070013250, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013269);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013269, 400070013269, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013269);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013251, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan rice'),
       'Chicken Schezwan Rice', 'chicken schezwan rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013251);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013251, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013251);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013251, 400070013, 400070013001, 400070013251, 400070013015, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013251);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013270, 400070013251, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013270);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013270, 400070013270, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013270);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013252, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix fried rice'),
       'Mix Fried Rice', 'mix fried rice', 'Chinese Rice', 'non_veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013252);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013252, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013252);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013252, 400070013, 400070013001, 400070013252, 400070013015, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013252);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013271, 400070013252, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013271);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013271, 400070013271, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013271);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013253, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns tripple schezwan rice'),
       'Prawns Tripple Schezwan Rice', 'prawns tripple schezwan rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013253);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013253, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013253);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013253, 400070013, 400070013001, 400070013253, 400070013015, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013253);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013272, 400070013253, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013272);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013272, 400070013272, 330.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013272);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013254, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns manchurian rice'),
       'Prawns Manchurian Rice', 'prawns manchurian rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013254);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013254, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013254);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013254, 400070013, 400070013001, 400070013254, 400070013015, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013254);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013273, 400070013254, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013273);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013273, 400070013273, 310.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013273);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013255, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns fried rice'),
       'Prawns Fried Rice', 'prawns fried rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013255);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013255, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013255);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013255, 400070013, 400070013001, 400070013255, 400070013015, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013255);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013274, 400070013255, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013274);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013274, 400070013274, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013274);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013256, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns schezwan rice'),
       'Prawns Schezwan Rice', 'prawns schezwan rice', 'Chinese Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013256);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013256, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013256);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013256, 400070013, 400070013001, 400070013256, 400070013015, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013256);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013275, 400070013256, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013275);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013275, 400070013275, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013275);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013257, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg fried rice'),
       'Egg Fried Rice', 'egg fried rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013257);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013257, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013257);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013257, 400070013, 400070013001, 400070013257, 400070013015, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013257);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013276, 400070013257, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013276);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013276, 400070013276, 140.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013276);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013258, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg schezwan fried rice'),
       'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013258);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013258, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013258);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013258, 400070013, 400070013001, 400070013258, 400070013015, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013258);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013277, 400070013258, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013277);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013277, 400070013277, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013277);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013259, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg tripple fried rice'),
       'Egg Tripple Fried Rice', 'egg tripple fried rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013259);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013259, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013259);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013259, 400070013, 400070013001, 400070013259, 400070013015, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013259);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013278, 400070013259, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013278);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013278, 400070013278, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013278);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013260, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg hongkong fried rice'),
       'Egg Hongkong Fried Rice', 'egg hongkong fried rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013260);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013260, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013260);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013260, 400070013, 400070013001, 400070013260, 400070013015, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013260);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013279, 400070013260, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013279);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013279, 400070013279, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013279);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013261, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg singapore fried rice'),
       'Egg Singapore Fried Rice', 'egg singapore fried rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013261);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013261, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013261);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013261, 400070013, 400070013001, 400070013261, 400070013015, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013261);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013280, 400070013261, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013280);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013280, 400070013280, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013280);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013262, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg combo fried rice'),
       'Egg Combo Fried Rice', 'egg combo fried rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013262);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013262, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013262);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013262, 400070013, 400070013001, 400070013262, 400070013015, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013262);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013281, 400070013262, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013281);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013281, 400070013281, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013281);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013263, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg combo schezwan rice'),
       'Egg Combo Schezwan Rice', 'egg combo schezwan rice', 'Chinese Rice', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013263);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013263, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013263);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013263, 400070013, 400070013001, 400070013263, 400070013015, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013263);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013282, 400070013263, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013282);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013282, 400070013282, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013282);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013264, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg fried rice'),
       'Veg Fried Rice', 'veg fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013264);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013264, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013264);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013264, 400070013, 400070013001, 400070013264, 400070013015, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013264);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013283, 400070013264, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013283);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013283, 400070013283, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013283);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013265, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg schezwan fried rice'),
       'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013265);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013265, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013265);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013265, 400070013, 400070013001, 400070013265, 400070013015, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013265);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013284, 400070013265, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013284);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013284, 400070013284, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013284);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013266, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg combo fried rice'),
       'Veg Combo Fried Rice', 'veg combo fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013266);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013266, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013266);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013266, 400070013, 400070013001, 400070013266, 400070013015, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013266);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013285, 400070013266, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013285);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013285, 400070013285, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013285);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013267, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg combo schezwan rice'),
       'Veg Combo Schezwan Rice', 'veg combo schezwan rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013267);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013267, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013267);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013267, 400070013, 400070013001, 400070013267, 400070013015, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013267);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013286, 400070013267, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013286);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013286, 400070013286, 220.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013286);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013268, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg tripple fried rice'),
       'Veg Tripple Fried Rice', 'veg tripple fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013268);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013268, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013268);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013268, 400070013, 400070013001, 400070013268, 400070013015, 27
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013268);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013287, 400070013268, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013287);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013287, 400070013287, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013287);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013269, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg manchurian rice'),
       'Veg Manchurian Rice', 'veg manchurian rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013269);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013269, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013269);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013269, 400070013, 400070013001, 400070013269, 400070013015, 28
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013269);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013288, 400070013269, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013288);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013288, 400070013288, 210.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013288);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013270, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg chilly fried rice'),
       'Veg Chilly Fried Rice', 'veg chilly fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013270);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013270, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013270);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013270, 400070013, 400070013001, 400070013270, 400070013015, 29
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013270);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013289, 400070013270, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013289);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013289, 400070013289, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013289);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013271, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg singapore fried rice'),
       'Veg Singapore Fried Rice', 'veg singapore fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013271);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013271, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013271);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013271, 400070013, 400070013001, 400070013271, 400070013015, 30
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013271);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013290, 400070013271, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013290);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013290, 400070013290, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013290);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013272, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hongkong fried rice'),
       'Veg Hongkong Fried Rice', 'veg hongkong fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013272);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013272, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013272);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013272, 400070013, 400070013001, 400070013272, 400070013015, 31
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013272);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013291, 400070013272, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013291);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013291, 400070013291, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013291);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013273, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tripple fried rice'),
       'Paneer Tripple Fried Rice', 'paneer tripple fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013273);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013273, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013273);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013273, 400070013, 400070013001, 400070013273, 400070013015, 32
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013273);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013292, 400070013273, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013292);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013292, 400070013292, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013292);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013274, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer manchurian rice'),
       'Paneer Manchurian Rice', 'paneer manchurian rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013274);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013274, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013274);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013274, 400070013, 400070013001, 400070013274, 400070013015, 33
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013274);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013293, 400070013274, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013293);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013293, 400070013293, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013293);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013275, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chilly rice'),
       'Paneer Chilly Rice', 'paneer chilly rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013275);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013275, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013275);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013275, 400070013, 400070013001, 400070013275, 400070013015, 34
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013275);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013294, 400070013275, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013294);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013294, 400070013294, 190.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013294);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013276, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer schezwan rice'),
       'Paneer Schezwan Rice', 'paneer schezwan rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013276);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013276, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013276);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013276, 400070013, 400070013001, 400070013276, 400070013015, 35
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013276);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013295, 400070013276, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013295);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013295, 400070013295, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013295);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013277, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer fried rice'),
       'Paneer Fried Rice', 'paneer fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013277);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013277, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013277);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013277, 400070013, 400070013001, 400070013277, 400070013015, 36
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013277);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013296, 400070013277, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013296);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013296, 400070013296, 180.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013296);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013278, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom fried rice'),
       'Mushroom Fried Rice', 'mushroom fried rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013278);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013278, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013278);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013278, 400070013, 400070013001, 400070013278, 400070013015, 37
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013278);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013297, 400070013278, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013297);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013297, 400070013297, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013297);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013279, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom schezwan rice'),
       'Mushroom Schezwan Rice', 'mushroom schezwan rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013279);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013279, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013279);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013279, 400070013, 400070013001, 400070013279, 400070013015, 38
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013279);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013298, 400070013279, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013298);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013298, 400070013298, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013298);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013280, 400070013, 400070013015, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom tripple rice'),
       'Mushroom Tripple Rice', 'mushroom tripple rice', 'Chinese Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013280);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013280, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013280);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013280, 400070013, 400070013001, 400070013280, 400070013015, 39
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013280);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013299, 400070013280, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013299);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013299, 400070013299, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013299);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013281, 400070013, 400070013016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kapsa rice'),
       'Kapsa Rice', 'kapsa rice', 'Kapsa Rice', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013281);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013281, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013281);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013281, 400070013, 400070013001, 400070013281, 400070013016, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013281);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013300, 400070013281, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013300);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013300, 400070013300, 1000.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013300);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013301, 400070013281, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013301);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013301, 400070013301, 650.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013301);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013282, 400070013, 400070013016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken chilly kapsa rice'),
       'Chicken Chilly Kapsa Rice', 'chicken chilly kapsa rice', 'Kapsa Rice', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013282);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013282, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013282);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013282, 400070013, 400070013001, 400070013282, 400070013016, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013282);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013302, 400070013282, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013302);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013302, 400070013302, 900.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013302);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013303, 400070013282, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013303);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013303, 400070013303, 550.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013303);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013283, 400070013, 400070013016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer chilly kapsa rice'),
       'Paneer Chilly Kapsa Rice', 'paneer chilly kapsa rice', 'Kapsa Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013283);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013283, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013283);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013283, 400070013, 400070013001, 400070013283, 400070013016, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013283);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013304, 400070013283, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013304);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013304, 400070013304, 1000.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013304);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013305, 400070013283, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013305);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013305, 400070013305, 650.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013305);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013284, 400070013, 400070013016, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg chilly kapsa rice'),
       'Veg Chilly Kapsa Rice', 'veg chilly kapsa rice', 'Kapsa Rice', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013284);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013284, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013284);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013284, 400070013, 400070013001, 400070013284, 400070013016, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013284);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013306, 400070013284, 'Full', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013306);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013306, 400070013306, 800.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013306);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013307, 400070013284, 'Half', 'fixed', FALSE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013307);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013307, 400070013307, 500.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013307);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013285, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tripple schezwan noodles'),
       'Chicken Tripple Schezwan Noodles', 'chicken tripple schezwan noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013285);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013285, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013285);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013285, 400070013, 400070013001, 400070013285, 400070013017, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013285);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013308, 400070013285, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013308);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013308, 400070013308, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013308);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013286, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken manchurian noodles'),
       'Chicken Manchurian Noodles', 'chicken manchurian noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013286);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013286, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013286);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013286, 400070013, 400070013001, 400070013286, 400070013017, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013286);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013309, 400070013286, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013309);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013309, 400070013309, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013309);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013287, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken singapore noodles'),
       'Chicken Singapore Noodles', 'chicken singapore noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013287);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013287, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013287);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013287, 400070013, 400070013001, 400070013287, 400070013017, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013287);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013310, 400070013287, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013310);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013310, 400070013310, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013310);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013288, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hongkong noodles'),
       'Chicken Hongkong Noodles', 'chicken hongkong noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013288);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013288, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013288);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013288, 400070013, 400070013001, 400070013288, 400070013017, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013288);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013311, 400070013288, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013311);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013311, 400070013311, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013311);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013289, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken hakka noodles'),
       'Chicken Hakka Noodles', 'chicken hakka noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013289);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013289, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013289);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013289, 400070013, 400070013001, 400070013289, 400070013017, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013289);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013312, 400070013289, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013312);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013312, 400070013312, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013312);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013290, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken schezwan noodles'),
       'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013290);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013290, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013290);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013290, 400070013, 400070013001, 400070013290, 400070013017, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013290);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013313, 400070013290, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013313);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013313, 400070013313, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013313);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013291, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix hakka noodles'),
       'Mix Hakka Noodles', 'mix hakka noodles', 'Chinese Noodles', 'non_veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013291);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013291, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013291);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013291, 400070013, 400070013001, 400070013291, 400070013017, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013291);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013314, 400070013291, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013314);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013314, 400070013314, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013314);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013292, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix schezwan noodles'),
       'Mix Schezwan Noodles', 'mix schezwan noodles', 'Chinese Noodles', 'non_veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013292);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013292, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013292);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013292, 400070013, 400070013001, 400070013292, 400070013017, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013292);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013315, 400070013292, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013315);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013315, 400070013315, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013315);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013293, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns hakka noodles'),
       'Prawns Hakka Noodles', 'prawns hakka noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013293);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013293, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013293);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013293, 400070013, 400070013001, 400070013293, 400070013017, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013293);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013316, 400070013293, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013316);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013316, 400070013316, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013316);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013294, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns schezwan noodles'),
       'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013294);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013294, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013294);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013294, 400070013, 400070013001, 400070013294, 400070013017, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013294);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013317, 400070013294, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013317);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013317, 400070013317, 250.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013317);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013295, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns singapore noodles'),
       'Prawns Singapore Noodles', 'prawns singapore noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013295);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013295, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013295);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013295, 400070013, 400070013001, 400070013295, 400070013017, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013295);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013318, 400070013295, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013318);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013318, 400070013318, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013318);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013296, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns hongkong noodles'),
       'Prawns Hongkong Noodles', 'prawns hongkong noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013296);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013296, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013296);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013296, 400070013, 400070013001, 400070013296, 400070013017, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013296);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013319, 400070013296, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013319);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013319, 400070013319, 260.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013319);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013297, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns tripple noodles'),
       'Prawns Tripple Noodles', 'prawns tripple noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013297);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013297, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013297);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013297, 400070013, 400070013001, 400070013297, 400070013017, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013297);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013320, 400070013297, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013320);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013320, 400070013320, 350.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013320);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013298, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'prawns manchurian noodles'),
       'Prawns Manchurian Noodles', 'prawns manchurian noodles', 'Chinese Noodles', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'SEAFOOD'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013298);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013298, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013298);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013298, 400070013, 400070013001, 400070013298, 400070013017, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013298);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013321, 400070013298, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013321);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013321, 400070013321, 340.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013321);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013299, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg hakka noodles'),
       'Egg Hakka Noodles', 'egg hakka noodles', 'Chinese Noodles', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013299);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013299, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013299);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013299, 400070013, 400070013001, 400070013299, 400070013017, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013299);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013322, 400070013299, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013322);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013322, 400070013322, 150.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013322);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013300, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg schezwan noodles'),
       'Egg Schezwan Noodles', 'egg schezwan noodles', 'Chinese Noodles', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013300);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013300, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013300);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013300, 400070013, 400070013001, 400070013300, 400070013017, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013300);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013323, 400070013300, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013323);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013323, 400070013323, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013323);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013301, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg singapore noodles'),
       'Egg Singapore Noodles', 'egg singapore noodles', 'Chinese Noodles', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013301);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013301, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013301);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013301, 400070013, 400070013001, 400070013301, 400070013017, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013301);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013324, 400070013301, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013324);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013324, 400070013324, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013324);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013302, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg hongkong noodles'),
       'Egg Hongkong Noodles', 'egg hongkong noodles', 'Chinese Noodles', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013302);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013302, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013302);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013302, 400070013, 400070013001, 400070013302, 400070013017, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013302);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013325, 400070013302, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013325);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013325, 400070013325, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013325);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013303, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg tripple schezwan noodles'),
       'Egg Tripple Schezwan Noodles', 'egg tripple schezwan noodles', 'Chinese Noodles', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013303);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013303, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013303);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013303, 400070013, 400070013001, 400070013303, 400070013017, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013303);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013326, 400070013303, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013326);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013326, 400070013326, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013326);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013304, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'egg manchurian noodles'),
       'Egg Manchurian Noodles', 'egg manchurian noodles', 'Chinese Noodles', 'egg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013304);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013304, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013304);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013304, 400070013, 400070013001, 400070013304, 400070013017, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013304);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013327, 400070013304, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013327);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013327, 400070013327, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013327);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013305, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hakka noodles'),
       'Veg Hakka Noodles', 'veg hakka noodles', 'Chinese Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013305);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013305, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013305);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013305, 400070013, 400070013001, 400070013305, 400070013017, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013305);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013328, 400070013305, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013328);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013328, 400070013328, 160.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013328);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013306, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg schezwan noodles'),
       'Veg Schezwan Noodles', 'veg schezwan noodles', 'Chinese Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013306);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013306, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013306);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013306, 400070013, 400070013001, 400070013306, 400070013017, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013306);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013329, 400070013306, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013329);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013329, 400070013329, 170.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013329);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013307, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg singapore noodles'),
       'Veg Singapore Noodles', 'veg singapore noodles', 'Chinese Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013307);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013307, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013307);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013307, 400070013, 400070013001, 400070013307, 400070013017, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013307);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013330, 400070013307, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013330);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013330, 400070013330, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013330);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013308, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hongkong noodles'),
       'Veg Hongkong Noodles', 'veg hongkong noodles', 'Chinese Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013308);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013308, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013308);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013308, 400070013, 400070013001, 400070013308, 400070013017, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013308);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013331, 400070013308, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013331);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013331, 400070013331, 200.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013331);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013309, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg tripple schezwan noodles'),
       'Veg Tripple Schezwan Noodles', 'veg tripple schezwan noodles', 'Chinese Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013309);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013309, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013309);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013309, 400070013, 400070013001, 400070013309, 400070013017, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013309);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013332, 400070013309, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013332);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013332, 400070013332, 240.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013332);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013310, 400070013, 400070013017, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg manchurian noodles'),
       'Veg Manchurian Noodles', 'veg manchurian noodles', 'Chinese Noodles', 'veg', NULL, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013310);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013310, 400070013, 400070013001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013310);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013310, 400070013, 400070013001, 400070013310, 400070013017, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013310);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013333, 400070013310, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013333);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013333, 400070013333, 230.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013333);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013311, 400070013, 400070013018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chaas / dahi / lassi / raita'),
       'Chaas / Dahi / Lassi / Raita', 'chaas / dahi / lassi / raita', 'Hot & Cold Beverages', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013311);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013311, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013311);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013311, 400070013, 400070013001, 400070013311, 400070013018, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013311);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013334, 400070013311, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013334);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013334, 400070013334, 45.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013334);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013312, 400070013, 400070013018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'caramel custard'),
       'Caramel Custard', 'caramel custard', 'Hot & Cold Beverages', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013312);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013312, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013312);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013312, 400070013, 400070013001, 400070013312, 400070013018, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013312);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013335, 400070013312, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013335);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013335, 400070013335, 70.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013335);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013313, 400070013, 400070013018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'matka rabdi'),
       'Matka Rabdi', 'matka rabdi', 'Hot & Cold Beverages', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013313);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013313, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013313);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013313, 400070013, 400070013001, 400070013313, 400070013018, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013313);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013336, 400070013313, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013336);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013336, 400070013336, 90.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013336);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013314, 400070013, 400070013018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'arabian pudding'),
       'Arabian Pudding', 'arabian pudding', 'Hot & Cold Beverages', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013314);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013314, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013314);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013314, 400070013, 400070013001, 400070013314, 400070013018, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013314);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013337, 400070013314, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013337);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013337, 400070013337, 40.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013337);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013315, 400070013, 400070013018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'gulab jamun'),
       'Gulab Jamun', 'gulab jamun', 'Hot & Cold Beverages', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013315);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013315, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013315);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013315, 400070013, 400070013001, 400070013315, 400070013018, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013315);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013338, 400070013315, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013338);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013338, 400070013338, 50.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013338);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013316, 400070013, 400070013018, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'green salad'),
       'Green Salad', 'green salad', 'Hot & Cold Beverages', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013316);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013316, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013316);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013316, 400070013, 400070013001, 400070013316, 400070013018, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013316);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013339, 400070013316, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013339);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013339, 400070013339, 50.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013339);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013317, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken biryani (1.kg rice & 1.kg chicken)'),
       'Chicken Biryani (1.kg Rice & 1.kg Chicken)', 'chicken biryani (1.kg rice & 1.kg chicken)', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013317);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013317, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013317);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013317, 400070013, 400070013001, 400070013317, 400070013019, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013317);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013340, 400070013317, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013340);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013340, 400070013340, 1000.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013340);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013318, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton biryani (1.kg rice & 1.kg mutton)'),
       'Mutton Biryani (1.kg Rice & 1.kg Mutton)', 'mutton biryani (1.kg rice & 1.kg mutton)', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013318);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013318, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013318);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013318, 400070013, 400070013001, 400070013318, 400070013019, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013318);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013341, 400070013318, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013341);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013341, 400070013341, 1500.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013341);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013319, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani'),
       'Chicken Tikka Biryani', 'chicken tikka biryani', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013319);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013319, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013319);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013319, 400070013, 400070013001, 400070013319, 400070013019, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013319);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013342, 400070013319, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013342);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013342, 400070013342, 1800.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013342);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013320, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg biryani & pulao'),
       'Veg Biryani & Pulao', 'veg biryani & pulao', 'Party Order (Bulk)', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013320);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013320, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013320);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013320, 400070013, 400070013001, 400070013320, 400070013019, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013320);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013343, 400070013320, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013343);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013343, 400070013343, 800.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013343);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013321, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton handi'),
       'Mutton Handi', 'mutton handi', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013321);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013321, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013321);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013321, 400070013, 400070013001, 400070013321, 400070013019, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013321);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013344, 400070013321, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013344);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013344, 400070013344, 1400.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013344);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013322, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken handi'),
       'Chicken Handi', 'chicken handi', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013322);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013322, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013322);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013322, 400070013, 400070013001, 400070013322, 400070013019, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013322);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013345, 400070013322, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013345);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013345, 400070013345, 800.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013345);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013323, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mutton kheema'),
       'Mutton Kheema', 'mutton kheema', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'MUTTON'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013323);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013323, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013323);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013323, 400070013, 400070013001, 400070013323, 400070013019, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013323);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013346, 400070013323, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013346);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013346, 400070013346, 1400.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013346);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013324, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chicken kheema'),
       'Chicken Kheema', 'chicken kheema', 'Party Order (Bulk)', 'non_veg', (SELECT protein_type_id FROM protein_type WHERE code = 'CHICKEN'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013324);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013324, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013324);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013324, 400070013, 400070013001, 400070013324, 400070013019, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013324);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013347, 400070013324, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013347);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013347, 400070013347, 1000.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013347);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013325, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'jeera rice'),
       'Jeera Rice', 'jeera rice', 'Party Order (Bulk)', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013325);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013325, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013325);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013325, 400070013, 400070013001, 400070013325, 400070013019, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013325);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013348, 400070013325, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013348);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013348, 400070013348, 400.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013348);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, protein_type_id, verification_status_code)
SELECT 400070013326, 400070013, 400070013019, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'steam rice'),
       'Steam Rice', 'steam rice', 'Party Order (Bulk)', 'veg', NULL, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400070013326);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400070013326, 400070013, 400070013001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400070013326);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400070013326, 400070013, 400070013001, 400070013326, 400070013019, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400070013326);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400070013349, 400070013326, 'Regular', 'per_kg', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400070013349);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400070013349, 400070013349, 300.00, 400070013, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400070013349);

COMMIT;

SELECT
    (SELECT COUNT(*) FROM menu_category WHERE restaurant_id = 400070013) AS categories,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400070013) AS items,
    (SELECT COUNT(*) FROM menu_item_variant miv JOIN menu_item mi ON mi.menu_item_id=miv.menu_item_id WHERE mi.restaurant_id=400070013) AS variants,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id=400070013 AND verification_status_code='needs_review') AS flagged_for_review,
    (SELECT COUNT(*) FROM menu_item_availability mia JOIN menu_item mi ON mi.menu_item_id=mia.menu_item_id WHERE mi.restaurant_id=400070013) AS availability_rows;