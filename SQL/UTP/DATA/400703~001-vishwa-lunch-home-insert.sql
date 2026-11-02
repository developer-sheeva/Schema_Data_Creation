-- ============================================================================
-- VISHWA LUNCH HOME -- MENU INSERT SCRIPT (PostgreSQL)
-- Generated from 400703_Vishwa_Launch_Home_Json.json against the attached
-- khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql schema.
-- 10 categories, 115 menu items, one variant each (no portion splits
-- on this menu), single board (no dine-in/takeaway distinction, no bar section).
--
-- ID convention (per explicit instruction -- note establishment_id and restaurant_id
-- are DIFFERENT values here, unlike every prior restaurant, where the attached
-- schema-resolved prompt requires them to be identical 9-digit values):
--   establishment_id = 400703 (6 digits -- the physical premises)
--   restaurant_id = source_id = 400703001 (9 digits -- this listing at that premises)
--   menu_board_id = 400703001001 (single board, only one channel on this menu)
-- Every other child table (menu_category, menu_item, menu_item_variant,
-- menu_item_price, menu_board_item) has its own independent counter starting at
-- 400703001001 (= restaurant_id + '001'), incrementing by 1 per row within that table.
-- No menu_item_availability rows are needed (no day/time-restricted items on this
-- menu), so that counter goes unused.
--
-- LOOKUP TABLES: none needed at all for this restaurant -- Pure Veg (no protein_type
-- lookups), no dietary/cuisine claim banner (no platform_tag), no named delivery
-- partner anywhere in the source (no delivery_provider). Nothing to flag as missing,
-- because nothing was looked up.
--
-- bar_license_type = 'none' and has_bar = FALSE, per explicit instruction.
--
-- Modeling notes:
-- * 'Tomato Omelette' -- almost certainly an eggless besan preparation given this is
--   a Pure Veg restaurant; classified 'veg', flagged needs_review for the name.
-- * 'Ice Cream' has no price on the source page; the page's other_text separately
--   contains '(As Per Package Rate)' -- modeled as is_market_price = TRUE,
--   price_amount NULL, rather than guessing a number.
--
-- 3 items flagged verification_status_code = 'needs_review'.
--
-- UNMAPPED (no schema home, not attached to any row):
-- * Page other_text states '1 KG ORDER AVAILABLE FOR PANEER BIRYANI, PANEER PULAO,'
--   (list cut off in the source) and, separately, 'Veg. 1kg Biryani Rs.950'. These
--   two fragments were not clearly connected in the source JSON -- the priced item
--   (Veg Biryani) isn't even the same dish named in the eligibility list (Paneer
--   Biryani/Pulao) -- so no 1kg variant was added anywhere rather than guessing.
-- ============================================================================

--\connect "KhaustanRestaurantMenu"

BEGIN;

-- ----------------------------------------------------------------------
-- Establishment & restaurant
-- ----------------------------------------------------------------------
INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2,
                            locality, city, state, postal_code, country_code, latitude, longitude, status_code)
SELECT 400703001, 'Vishwa Lunch Home', 'vishwa lunch home', 'SS-4/286, Near MESB', 'Sector 2, Vashi',
       'Vashi', 'Navi Mumbai', 'Maharashtra', '400703', 'IN', 19.07214860986321, 72.99665445092735, 'active'  
WHERE NOT EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400703);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name,
                         veg_nonveg_status, has_bar, bar_license_type, status_code, verification_status_code)
SELECT 400703001, 400703001, 'Vishwa Lunch Home', 'vishwa lunch home',
       'pure_veg', FALSE, 'none', 'active', 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400703001);

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT * FROM (VALUES
    (400703001001, 400703001, '9892045901', TRUE),
    (400703001002, 400703001, '9987537388', FALSE),
    (400703001003, 400703001, '9076045901', FALSE)
) AS v WHERE NOT EXISTS (SELECT 1 FROM restaurant_phone WHERE restaurant_id = 400703001);

-- Open 06:30 to 22:45 daily
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
SELECT * FROM (VALUES
    (400703001001, 400703001, 1, 1, '06:30'::time, '22:45'::time),
    (400703001002, 400703001, 2, 1, '06:30'::time, '22:45'::time),
    (400703001003, 400703001, 3, 1, '06:30'::time, '22:45'::time),
    (400703001004, 400703001, 4, 1, '06:30'::time, '22:45'::time),
    (400703001005, 400703001, 5, 1, '06:30'::time, '22:45'::time),
    (400703001006, 400703001, 6, 1, '06:30'::time, '22:45'::time),
    (400703001007, 400703001, 7, 1, '06:30'::time, '22:45'::time)
) AS v WHERE NOT EXISTS (SELECT 1 FROM restaurant_hours WHERE restaurant_id = 400703001);

INSERT INTO source_record (source_id, source_type_code, source_uri)
SELECT 400703001, 'ai_menu_extraction', '400703_Vishwa_Launch_Home_Json.json'
WHERE NOT EXISTS (SELECT 1 FROM source_record WHERE source_id = 400703001);

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400703001001, 400703001, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
WHERE NOT EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400703001);

-- ----------------------------------------------------------------------
-- Menu board (single board -- no dine-in/takeaway split, no bar section)
-- ----------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 400703001001, 400703001, 'A La Carte', 'a_la_carte'
WHERE NOT EXISTS (SELECT 1 FROM menu_board WHERE menu_board_id = 400703001001);

-- ----------------------------------------------------------------------
-- Menu categories (10, in source order)
-- ----------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
SELECT * FROM (VALUES
    (400703001001, 400703001, 'SOUTH INDIAN DISH', 1),
    (400703001002, 400703001, 'CHINESE SOUP', 2),
    (400703001003, 400703001, 'RICE', 3),
    (400703001004, 400703001, 'BIRYANI & PULAO', 4),
    (400703001005, 400703001, 'SNACKS', 5),
    (400703001006, 400703001, 'CHINESE RICE', 6),
    (400703001007, 400703001, 'TANDOORI', 7),
    (400703001008, 400703001, 'PUNJABI CURRY MASALA', 8),
    (400703001009, 400703001, 'LUNCH & DINNER', 9),
    (400703001010, 400703001, 'BEVERAGES', 10)
) AS v WHERE NOT EXISTS (SELECT 1 FROM menu_category WHERE restaurant_id = 400703001);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT * FROM (VALUES
    (400703001, 400703001001, 400703001001, 1),
    (400703001, 400703001001, 400703001002, 2),
    (400703001, 400703001001, 400703001003, 3),
    (400703001, 400703001001, 400703001004, 4),
    (400703001, 400703001001, 400703001005, 5),
    (400703001, 400703001001, 400703001006, 6),
    (400703001, 400703001001, 400703001007, 7),
    (400703001, 400703001001, 400703001008, 8),
    (400703001, 400703001001, 400703001009, 9),
    (400703001, 400703001001, 400703001010, 10)
) AS v WHERE NOT EXISTS (SELECT 1 FROM menu_board_category WHERE restaurant_id = 400703001);

-- ----------------------------------------------------------------------
-- Canonical dishes (115 distinct names -- shared/global table)
-- ----------------------------------------------------------------------
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001001, 'Idli Sambar', 'idli sambar', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli sambar');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001001, canonical_dish_id, 'en', 'Idli Sambar', 'idli sambar', 'primary' FROM canonical_dish
WHERE normalized_name = 'idli sambar' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'idli sambar' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001002, 'Vada Sambar', 'vada sambar', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vada sambar');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001002, canonical_dish_id, 'en', 'Vada Sambar', 'vada sambar', 'primary' FROM canonical_dish
WHERE normalized_name = 'vada sambar' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vada sambar' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001003, 'Masala Dosa', 'masala dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001003, canonical_dish_id, 'en', 'Masala Dosa', 'masala dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'masala dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'masala dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001004, 'Mysore Masala Dosa', 'mysore masala dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore masala dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001004, canonical_dish_id, 'en', 'Mysore Masala Dosa', 'mysore masala dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'mysore masala dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mysore masala dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001005, 'Mysore Sada Dosa', 'mysore sada dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore sada dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001005, canonical_dish_id, 'en', 'Mysore Sada Dosa', 'mysore sada dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'mysore sada dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mysore sada dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001006, 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rava masala dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001006, canonical_dish_id, 'en', 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'onion rava masala dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'onion rava masala dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001007, 'Onion Rava Sada Dosa', 'onion rava sada dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rava sada dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001007, canonical_dish_id, 'en', 'Onion Rava Sada Dosa', 'onion rava sada dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'onion rava sada dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'onion rava sada dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001008, 'Cheese Masala Dosa', 'cheese masala dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001008, canonical_dish_id, 'en', 'Cheese Masala Dosa', 'cheese masala dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'cheese masala dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'cheese masala dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001009, 'Cheese Mysore Dosa', 'cheese mysore dosa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese mysore dosa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001009, canonical_dish_id, 'en', 'Cheese Mysore Dosa', 'cheese mysore dosa', 'primary' FROM canonical_dish
WHERE normalized_name = 'cheese mysore dosa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'cheese mysore dosa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001010, 'Sadda Uttapa', 'sadda uttapa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sadda uttapa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001010, canonical_dish_id, 'en', 'Sadda Uttapa', 'sadda uttapa', 'primary' FROM canonical_dish
WHERE normalized_name = 'sadda uttapa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sadda uttapa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001011, 'Tomato Onion Uttapa', 'tomato onion uttapa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato onion uttapa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001011, canonical_dish_id, 'en', 'Tomato Onion Uttapa', 'tomato onion uttapa', 'primary' FROM canonical_dish
WHERE normalized_name = 'tomato onion uttapa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tomato onion uttapa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001012, 'Tomato Omelette', 'tomato omelette', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato omelette');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001012, canonical_dish_id, 'en', 'Tomato Omelette', 'tomato omelette', 'primary' FROM canonical_dish
WHERE normalized_name = 'tomato omelette' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tomato omelette' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001013, 'Veg Noodles Soup', 'veg noodles soup', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg noodles soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001013, canonical_dish_id, 'en', 'Veg Noodles Soup', 'veg noodles soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg noodles soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg noodles soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001014, 'Veg Manchow Soup', 'veg manchow soup', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchow soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001014, canonical_dish_id, 'en', 'Veg Manchow Soup', 'veg manchow soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg manchow soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg manchow soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001015, 'Veg Hot & Sour Soup', 'veg hot & sour soup', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hot & sour soup');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001015, canonical_dish_id, 'en', 'Veg Hot & Sour Soup', 'veg hot & sour soup', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hot & sour soup' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hot & sour soup' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001016, 'Jeera Rice', 'jeera rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001016, canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'jeera rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'jeera rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001017, 'Lemon Rice', 'lemon rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001017, canonical_dish_id, 'en', 'Lemon Rice', 'lemon rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'lemon rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'lemon rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001018, 'Steam Rice', 'steam rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001018, canonical_dish_id, 'en', 'Steam Rice', 'steam rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'steam rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'steam rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001019, 'Hyderabadi Biryani', 'hyderabadi biryani', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hyderabadi biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001019, canonical_dish_id, 'en', 'Hyderabadi Biryani', 'hyderabadi biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'hyderabadi biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'hyderabadi biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001020, 'Veg Biryani', 'veg biryani', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001020, canonical_dish_id, 'en', 'Veg Biryani', 'veg biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001021, 'Mushroom Biryani', 'mushroom biryani', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001021, canonical_dish_id, 'en', 'Mushroom Biryani', 'mushroom biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001022, 'Paneer Biryani', 'paneer biryani', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001022, canonical_dish_id, 'en', 'Paneer Biryani', 'paneer biryani', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer biryani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer biryani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001023, 'Paneer Pulao', 'paneer pulao', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001023, canonical_dish_id, 'en', 'Paneer Pulao', 'paneer pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001024, 'Veg Pulao', 'veg pulao', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001024, canonical_dish_id, 'en', 'Veg Pulao', 'veg pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001025, 'Kashmiri Pulao', 'kashmiri pulao', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kashmiri pulao');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001025, canonical_dish_id, 'en', 'Kashmiri Pulao', 'kashmiri pulao', 'primary' FROM canonical_dish
WHERE normalized_name = 'kashmiri pulao' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kashmiri pulao' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001026, 'Vada Pav', 'vada pav', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vada pav');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001026, canonical_dish_id, 'en', 'Vada Pav', 'vada pav', 'primary' FROM canonical_dish
WHERE normalized_name = 'vada pav' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'vada pav' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001027, 'Samosa Pav', 'samosa pav', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'samosa pav');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001027, canonical_dish_id, 'en', 'Samosa Pav', 'samosa pav', 'primary' FROM canonical_dish
WHERE normalized_name = 'samosa pav' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'samosa pav' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001028, 'Misal Pav', 'misal pav', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'misal pav');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001028, canonical_dish_id, 'en', 'Misal Pav', 'misal pav', 'primary' FROM canonical_dish
WHERE normalized_name = 'misal pav' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'misal pav' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001029, 'Usal Pav', 'usal pav', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'usal pav');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001029, canonical_dish_id, 'en', 'Usal Pav', 'usal pav', 'primary' FROM canonical_dish
WHERE normalized_name = 'usal pav' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'usal pav' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001030, 'Upma', 'upma', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'upma');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001030, canonical_dish_id, 'en', 'Upma', 'upma', 'primary' FROM canonical_dish
WHERE normalized_name = 'upma' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'upma' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001031, 'Poha', 'poha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'poha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001031, canonical_dish_id, 'en', 'Poha', 'poha', 'primary' FROM canonical_dish
WHERE normalized_name = 'poha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'poha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001032, 'Puri Baji', 'puri baji', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puri baji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001032, canonical_dish_id, 'en', 'Puri Baji', 'puri baji', 'primary' FROM canonical_dish
WHERE normalized_name = 'puri baji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'puri baji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001033, 'Chole Bhature', 'chole bhature', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chole bhature');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001033, canonical_dish_id, 'en', 'Chole Bhature', 'chole bhature', 'primary' FROM canonical_dish
WHERE normalized_name = 'chole bhature' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chole bhature' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001034, 'Extra Bhature', 'extra bhature', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra bhature');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001034, canonical_dish_id, 'en', 'Extra Bhature', 'extra bhature', 'primary' FROM canonical_dish
WHERE normalized_name = 'extra bhature' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'extra bhature' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001035, 'Veg Fried Rice', 'veg fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001035, canonical_dish_id, 'en', 'Veg Fried Rice', 'veg fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001036, 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001036, canonical_dish_id, 'en', 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg schezwan fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg schezwan fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001037, 'Veg Manchurian Fried Rice', 'veg manchurian fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001037, canonical_dish_id, 'en', 'Veg Manchurian Fried Rice', 'veg manchurian fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg manchurian fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg manchurian fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001038, 'Veg Triple Rice', 'veg triple rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg triple rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001038, canonical_dish_id, 'en', 'Veg Triple Rice', 'veg triple rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg triple rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg triple rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001039, 'Veg Hong Kong Fried Rice', 'veg hong kong fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hong kong fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001039, canonical_dish_id, 'en', 'Veg Hong Kong Fried Rice', 'veg hong kong fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hong kong fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hong kong fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001040, 'Veg Singapore Fried Rice', 'veg singapore fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg singapore fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001040, canonical_dish_id, 'en', 'Veg Singapore Fried Rice', 'veg singapore fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg singapore fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg singapore fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001041, 'Paneer Fried Rice', 'paneer fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001041, canonical_dish_id, 'en', 'Paneer Fried Rice', 'paneer fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001042, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001042, canonical_dish_id, 'en', 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer schezwan fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer schezwan fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001043, 'Mushroom Fried Rice', 'mushroom fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001043, canonical_dish_id, 'en', 'Mushroom Fried Rice', 'mushroom fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001044, 'Paneer Triple Schezwan Fried Rice', 'paneer triple schezwan fried rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer triple schezwan fried rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001044, canonical_dish_id, 'en', 'Paneer Triple Schezwan Fried Rice', 'paneer triple schezwan fried rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer triple schezwan fried rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer triple schezwan fried rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001045, 'Tandoori Roti', 'tandoori roti', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001045, canonical_dish_id, 'en', 'Tandoori Roti', 'tandoori roti', 'primary' FROM canonical_dish
WHERE normalized_name = 'tandoori roti' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tandoori roti' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001046, 'Bakri', 'bakri', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bakri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001046, canonical_dish_id, 'en', 'Bakri', 'bakri', 'primary' FROM canonical_dish
WHERE normalized_name = 'bakri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'bakri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001047, 'Chappati', 'chappati', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chappati');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001047, canonical_dish_id, 'en', 'Chappati', 'chappati', 'primary' FROM canonical_dish
WHERE normalized_name = 'chappati' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chappati' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001048, 'Aloo Paratha', 'aloo paratha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo paratha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001048, canonical_dish_id, 'en', 'Aloo Paratha', 'aloo paratha', 'primary' FROM canonical_dish
WHERE normalized_name = 'aloo paratha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'aloo paratha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001049, 'Gobi Paratha', 'gobi paratha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gobi paratha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001049, canonical_dish_id, 'en', 'Gobi Paratha', 'gobi paratha', 'primary' FROM canonical_dish
WHERE normalized_name = 'gobi paratha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'gobi paratha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001050, 'Paneer Paratha', 'paneer paratha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer paratha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001050, canonical_dish_id, 'en', 'Paneer Paratha', 'paneer paratha', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer paratha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer paratha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001051, 'Methi Paratha', 'methi paratha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi paratha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001051, canonical_dish_id, 'en', 'Methi Paratha', 'methi paratha', 'primary' FROM canonical_dish
WHERE normalized_name = 'methi paratha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'methi paratha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001052, 'Butter Tandoori Roti', 'butter tandoori roti', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter tandoori roti');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001052, canonical_dish_id, 'en', 'Butter Tandoori Roti', 'butter tandoori roti', 'primary' FROM canonical_dish
WHERE normalized_name = 'butter tandoori roti' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter tandoori roti' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001053, 'Butter Naan', 'butter naan', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001053, canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary' FROM canonical_dish
WHERE normalized_name = 'butter naan' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter naan' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001054, 'Naan', 'naan', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'naan');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001054, canonical_dish_id, 'en', 'Naan', 'naan', 'primary' FROM canonical_dish
WHERE normalized_name = 'naan' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'naan' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001055, 'Kulcha', 'kulcha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001055, canonical_dish_id, 'en', 'Kulcha', 'kulcha', 'primary' FROM canonical_dish
WHERE normalized_name = 'kulcha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kulcha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001056, 'Butter Kulcha', 'butter kulcha', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter kulcha');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001056, canonical_dish_id, 'en', 'Butter Kulcha', 'butter kulcha', 'primary' FROM canonical_dish
WHERE normalized_name = 'butter kulcha' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'butter kulcha' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001057, 'Navratna Korma', 'navratna korma', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'navratna korma');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001057, canonical_dish_id, 'en', 'Navratna Korma', 'navratna korma', 'primary' FROM canonical_dish
WHERE normalized_name = 'navratna korma' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'navratna korma' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001058, 'Mushroom Masala', 'mushroom masala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001058, canonical_dish_id, 'en', 'Mushroom Masala', 'mushroom masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001059, 'Mushroom Matar', 'mushroom matar', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom matar');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001059, canonical_dish_id, 'en', 'Mushroom Matar', 'mushroom matar', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom matar' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom matar' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001060, 'Mushroom Kadai', 'mushroom kadai', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom kadai');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001060, canonical_dish_id, 'en', 'Mushroom Kadai', 'mushroom kadai', 'primary' FROM canonical_dish
WHERE normalized_name = 'mushroom kadai' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mushroom kadai' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001061, 'Veg Kadai', 'veg kadai', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kadai');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001061, canonical_dish_id, 'en', 'Veg Kadai', 'veg kadai', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg kadai' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg kadai' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001062, 'Veg Hyderabadi', 'veg hyderabadi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hyderabadi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001062, canonical_dish_id, 'en', 'Veg Hyderabadi', 'veg hyderabadi', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg hyderabadi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg hyderabadi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001063, 'Paneer Kolhapuri', 'paneer kolhapuri', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kolhapuri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001063, canonical_dish_id, 'en', 'Paneer Kolhapuri', 'paneer kolhapuri', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer kolhapuri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer kolhapuri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001064, 'Paneer Hyderabadi', 'paneer hyderabadi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hyderabadi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001064, canonical_dish_id, 'en', 'Paneer Hyderabadi', 'paneer hyderabadi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer hyderabadi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer hyderabadi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001065, 'Dal Fry', 'dal fry', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001065, canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001066, 'Dal Tadka', 'dal tadka', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001066, canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal tadka' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal tadka' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001067, 'Methi Makhana', 'methi makhana', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi makhana');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001067, canonical_dish_id, 'en', 'Methi Makhana', 'methi makhana', 'primary' FROM canonical_dish
WHERE normalized_name = 'methi makhana' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'methi makhana' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001068, 'Daal Kolhapuri', 'daal kolhapuri', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'daal kolhapuri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001068, canonical_dish_id, 'en', 'Daal Kolhapuri', 'daal kolhapuri', 'primary' FROM canonical_dish
WHERE normalized_name = 'daal kolhapuri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'daal kolhapuri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001069, 'Daal Makhanivala', 'daal makhanivala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'daal makhanivala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001069, canonical_dish_id, 'en', 'Daal Makhanivala', 'daal makhanivala', 'primary' FROM canonical_dish
WHERE normalized_name = 'daal makhanivala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'daal makhanivala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001070, 'Veg Korma', 'veg korma', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg korma');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001070, canonical_dish_id, 'en', 'Veg Korma', 'veg korma', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg korma' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg korma' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001071, 'Paneer Masala', 'paneer masala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001071, canonical_dish_id, 'en', 'Paneer Masala', 'paneer masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001072, 'Paneer Flower', 'paneer flower', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer flower');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001072, canonical_dish_id, 'en', 'Paneer Flower', 'paneer flower', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer flower' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer flower' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001073, 'Palak Paneer', 'palak paneer', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak paneer');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001073, canonical_dish_id, 'en', 'Palak Paneer', 'palak paneer', 'primary' FROM canonical_dish
WHERE normalized_name = 'palak paneer' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'palak paneer' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001074, 'Paneer Burji', 'paneer burji', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer burji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001074, canonical_dish_id, 'en', 'Paneer Burji', 'paneer burji', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer burji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer burji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001075, 'Paneer Makhanwala', 'paneer makhanwala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhanwala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001075, canonical_dish_id, 'en', 'Paneer Makhanwala', 'paneer makhanwala', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer makhanwala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer makhanwala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001076, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001076, canonical_dish_id, 'en', 'Paneer Tikka Masala', 'paneer tikka masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tikka masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tikka masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001077, 'Veg Jaipuri', 'veg jaipuri', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg jaipuri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001077, canonical_dish_id, 'en', 'Veg Jaipuri', 'veg jaipuri', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg jaipuri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg jaipuri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001078, 'Sev Bhaji', 'sev bhaji', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sev bhaji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001078, canonical_dish_id, 'en', 'Sev Bhaji', 'sev bhaji', 'primary' FROM canonical_dish
WHERE normalized_name = 'sev bhaji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sev bhaji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001079, 'Veg Kofta', 'veg kofta', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kofta');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001079, canonical_dish_id, 'en', 'Veg Kofta', 'veg kofta', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg kofta' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg kofta' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001080, 'Kaju Curry', 'kaju curry', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju curry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001080, canonical_dish_id, 'en', 'Kaju Curry', 'kaju curry', 'primary' FROM canonical_dish
WHERE normalized_name = 'kaju curry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'kaju curry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001081, 'Methi Malai Paneer', 'methi malai paneer', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi malai paneer');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001081, canonical_dish_id, 'en', 'Methi Malai Paneer', 'methi malai paneer', 'primary' FROM canonical_dish
WHERE normalized_name = 'methi malai paneer' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'methi malai paneer' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001082, 'Palak Lasuni', 'palak lasuni', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak lasuni');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001082, canonical_dish_id, 'en', 'Palak Lasuni', 'palak lasuni', 'primary' FROM canonical_dish
WHERE normalized_name = 'palak lasuni' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'palak lasuni' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001083, 'Paneer Makhani', 'paneer makhani', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhani');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001083, canonical_dish_id, 'en', 'Paneer Makhani', 'paneer makhani', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer makhani' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer makhani' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001084, 'Paneer Kadai', 'paneer kadai', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001084, canonical_dish_id, 'en', 'Paneer Kadai', 'paneer kadai', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer kadai' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer kadai' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001085, 'Paneer Kofta', 'paneer kofta', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kofta');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001085, canonical_dish_id, 'en', 'Paneer Kofta', 'paneer kofta', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer kofta' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer kofta' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001086, 'Paneer Korma', 'paneer korma', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer korma');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001086, canonical_dish_id, 'en', 'Paneer Korma', 'paneer korma', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer korma' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer korma' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001087, 'Paneer Tomato', 'paneer tomato', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tomato');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001087, canonical_dish_id, 'en', 'Paneer Tomato', 'paneer tomato', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer tomato' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer tomato' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001088, 'Sahi Paneer', 'sahi paneer', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sahi paneer');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001088, canonical_dish_id, 'en', 'Sahi Paneer', 'sahi paneer', 'primary' FROM canonical_dish
WHERE normalized_name = 'sahi paneer' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sahi paneer' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001089, 'Paneer Handi', 'paneer handi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer handi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001089, canonical_dish_id, 'en', 'Paneer Handi', 'paneer handi', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer handi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer handi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001090, 'Paneer Pasanda', 'paneer pasanda', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pasanda');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001090, canonical_dish_id, 'en', 'Paneer Pasanda', 'paneer pasanda', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer pasanda' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer pasanda' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001091, 'Paneer Channa', 'paneer channa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer channa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001091, canonical_dish_id, 'en', 'Paneer Channa', 'paneer channa', 'primary' FROM canonical_dish
WHERE normalized_name = 'paneer channa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'paneer channa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001092, 'Tomato Masala', 'tomato masala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001092, canonical_dish_id, 'en', 'Tomato Masala', 'tomato masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'tomato masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tomato masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001093, 'Malai Kofa', 'malai kofa', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai kofa');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001093, canonical_dish_id, 'en', 'Malai Kofa', 'malai kofa', 'primary' FROM canonical_dish
WHERE normalized_name = 'malai kofa' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'malai kofa' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001094, 'Channa Masala', 'channa masala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'channa masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001094, canonical_dish_id, 'en', 'Channa Masala', 'channa masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'channa masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'channa masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001095, 'Aloo Gobhi', 'aloo gobhi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo gobhi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001095, canonical_dish_id, 'en', 'Aloo Gobhi', 'aloo gobhi', 'primary' FROM canonical_dish
WHERE normalized_name = 'aloo gobhi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'aloo gobhi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001096, 'Aloo Matar', 'aloo matar', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo matar');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001096, canonical_dish_id, 'en', 'Aloo Matar', 'aloo matar', 'primary' FROM canonical_dish
WHERE normalized_name = 'aloo matar' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'aloo matar' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001097, 'Veg Kolhapuri', 'veg kolhapuri', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kolhapuri');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001097, canonical_dish_id, 'en', 'Veg Kolhapuri', 'veg kolhapuri', 'primary' FROM canonical_dish
WHERE normalized_name = 'veg kolhapuri' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'veg kolhapuri' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001098, 'Mix Veg', 'mix veg', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix veg');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001098, canonical_dish_id, 'en', 'Mix Veg', 'mix veg', 'primary' FROM canonical_dish
WHERE normalized_name = 'mix veg' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'mix veg' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001099, 'Green Peas Masala', 'green peas masala', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas masala');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001099, canonical_dish_id, 'en', 'Green Peas Masala', 'green peas masala', 'primary' FROM canonical_dish
WHERE normalized_name = 'green peas masala' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'green peas masala' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001100, 'Bhindi Masala Fry', 'bhindi masala fry', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhindi masala fry');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001100, canonical_dish_id, 'en', 'Bhindi Masala Fry', 'bhindi masala fry', 'primary' FROM canonical_dish
WHERE normalized_name = 'bhindi masala fry' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'bhindi masala fry' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001101, 'Aloo Methi', 'aloo methi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo methi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001101, canonical_dish_id, 'en', 'Aloo Methi', 'aloo methi', 'primary' FROM canonical_dish
WHERE normalized_name = 'aloo methi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'aloo methi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001102, 'Methi Palak', 'methi palak', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi palak');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001102, canonical_dish_id, 'en', 'Methi Palak', 'methi palak', 'primary' FROM canonical_dish
WHERE normalized_name = 'methi palak' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'methi palak' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001103, 'Dum Aloo Punjabi', 'dum aloo punjabi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dum aloo punjabi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001103, canonical_dish_id, 'en', 'Dum Aloo Punjabi', 'dum aloo punjabi', 'primary' FROM canonical_dish
WHERE normalized_name = 'dum aloo punjabi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dum aloo punjabi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001104, 'Thali Lunch / Dinner', 'thali lunch / dinner', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thali lunch / dinner');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001104, canonical_dish_id, 'en', 'Thali Lunch / Dinner', 'thali lunch / dinner', 'primary' FROM canonical_dish
WHERE normalized_name = 'thali lunch / dinner' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'thali lunch / dinner' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001105, 'Special Lunch', 'special lunch', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special lunch');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001105, canonical_dish_id, 'en', 'Special Lunch', 'special lunch', 'primary' FROM canonical_dish
WHERE normalized_name = 'special lunch' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'special lunch' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001106, 'Dal Rice', 'dal rice', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal rice');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001106, canonical_dish_id, 'en', 'Dal Rice', 'dal rice', 'primary' FROM canonical_dish
WHERE normalized_name = 'dal rice' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'dal rice' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001107, 'Sukha Baji', 'sukha baji', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sukha baji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001107, canonical_dish_id, 'en', 'Sukha Baji', 'sukha baji', 'primary' FROM canonical_dish
WHERE normalized_name = 'sukha baji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sukha baji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001108, 'Chappati Baji', 'chappati baji', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chappati baji');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001108, canonical_dish_id, 'en', 'Chappati Baji', 'chappati baji', 'primary' FROM canonical_dish
WHERE normalized_name = 'chappati baji' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chappati baji' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001109, 'Tea', 'tea', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tea');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001109, canonical_dish_id, 'en', 'Tea', 'tea', 'primary' FROM canonical_dish
WHERE normalized_name = 'tea' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'tea' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001110, 'Special Tea', 'special tea', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special tea');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001110, canonical_dish_id, 'en', 'Special Tea', 'special tea', 'primary' FROM canonical_dish
WHERE normalized_name = 'special tea' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'special tea' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001111, 'Coffee', 'coffee', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'coffee');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001111, canonical_dish_id, 'en', 'Coffee', 'coffee', 'primary' FROM canonical_dish
WHERE normalized_name = 'coffee' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'coffee' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001112, 'Lassi', 'lassi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lassi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001112, canonical_dish_id, 'en', 'Lassi', 'lassi', 'primary' FROM canonical_dish
WHERE normalized_name = 'lassi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'lassi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001113, 'Chaas', 'chaas', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chaas');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001113, canonical_dish_id, 'en', 'Chaas', 'chaas', 'primary' FROM canonical_dish
WHERE normalized_name = 'chaas' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'chaas' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001114, 'Sonkadi', 'sonkadi', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sonkadi');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001114, canonical_dish_id, 'en', 'Sonkadi', 'sonkadi', 'primary' FROM canonical_dish
WHERE normalized_name = 'sonkadi' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'sonkadi' AND name_type_code = 'primary');
INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code)
SELECT 400703001115, 'Ice Cream', 'ice cream', 'veg'
WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ice cream');
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT 400703001115, canonical_dish_id, 'en', 'Ice Cream', 'ice cream', 'primary' FROM canonical_dish
WHERE normalized_name = 'ice cream' AND NOT EXISTS (SELECT 1 FROM canonical_dish_name WHERE normalized_name = 'ice cream' AND name_type_code = 'primary');

-- ----------------------------------------------------------------------
-- Menu items, variants, prices, board links, provenance (115 items)
-- ----------------------------------------------------------------------
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001001, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'idli sambar'),
       'Idli Sambar', 'idli sambar', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001001);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001001, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001001);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001001, 400703001, 400703001001, 400703001001, 400703001001, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001001);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001001, 400703001001, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001001);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001001, 400703001001, 60.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001001);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001002, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vada sambar'),
       'Vada Sambar', 'vada sambar', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001002);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001002, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001002);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001002, 400703001, 400703001001, 400703001002, 400703001001, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001002);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001002, 400703001002, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001002);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001002, 400703001002, 60.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001002);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001003, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'masala dosa'),
       'Masala Dosa', 'masala dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001003);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001003, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001003);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001003, 400703001, 400703001001, 400703001003, 400703001001, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001003);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001003, 400703001003, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001003);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001003, 400703001003, 70.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001003);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001004, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mysore masala dosa'),
       'Mysore Masala Dosa', 'mysore masala dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001004);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001004, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001004);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001004, 400703001, 400703001001, 400703001004, 400703001001, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001004);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001004, 400703001004, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001004);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001004, 400703001004, 80.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001004);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001005, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mysore sada dosa'),
       'Mysore Sada Dosa', 'mysore sada dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001005);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001005, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001005);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001005, 400703001, 400703001001, 400703001005, 400703001001, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001005);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001005, 400703001005, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001005);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001005, 400703001005, 70.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001005);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001006, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'onion rava masala dosa'),
       'Onion Rava Masala Dosa', 'onion rava masala dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001006);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001006, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001006);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001006, 400703001, 400703001001, 400703001006, 400703001001, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001006);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001006, 400703001006, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001006);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001006, 400703001006, 80.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001006);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001007, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'onion rava sada dosa'),
       'Onion Rava Sada Dosa', 'onion rava sada dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001007);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001007, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001007);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001007, 400703001, 400703001001, 400703001007, 400703001001, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001007);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001007, 400703001007, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001007);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001007, 400703001007, 70.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001007);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001008, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheese masala dosa'),
       'Cheese Masala Dosa', 'cheese masala dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001008);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001008, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001008);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001008, 400703001, 400703001001, 400703001008, 400703001001, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001008);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001008, 400703001008, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001008);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001008, 400703001008, 90.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001008);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001009, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'cheese mysore dosa'),
       'Cheese Mysore Dosa', 'cheese mysore dosa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001009);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001009, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001009);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001009, 400703001, 400703001001, 400703001009, 400703001001, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001009);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001009, 400703001009, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001009);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001009, 400703001009, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001009);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001010, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sadda uttapa'),
       'Sadda Uttapa', 'sadda uttapa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001010);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001010, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001010);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001010, 400703001, 400703001001, 400703001010, 400703001001, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001010);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001010, 400703001010, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001010);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001010, 400703001010, 60.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001010);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001011, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tomato onion uttapa'),
       'Tomato Onion Uttapa', 'tomato onion uttapa', 'SOUTH INDIAN DISH', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001011);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001011, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001011);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001011, 400703001, 400703001001, 400703001011, 400703001001, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001011);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001011, 400703001011, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001011);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001011, 400703001011, 80.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001011);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001012, 400703001, 400703001001, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tomato omelette'),
       'Tomato Omelette', 'tomato omelette', 'SOUTH INDIAN DISH', 'veg', 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001012);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001012, 400703001, 400703001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001012);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001012, 400703001, 400703001001, 400703001012, 400703001001, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001012);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001012, 400703001012, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001012);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001012, 400703001012, 80.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001012);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001013, 400703001, 400703001002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg noodles soup'),
       'Veg Noodles Soup', 'veg noodles soup', 'CHINESE SOUP', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001013);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001013, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001013);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001013, 400703001, 400703001001, 400703001013, 400703001002, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001013);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001013, 400703001013, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001013);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001013, 400703001013, 120.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001013);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001014, 400703001, 400703001002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg manchow soup'),
       'Veg Manchow Soup', 'veg manchow soup', 'CHINESE SOUP', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001014);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001014, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001014);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001014, 400703001, 400703001001, 400703001014, 400703001002, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001014);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001014, 400703001014, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001014);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001014, 400703001014, 120.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001014);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001015, 400703001, 400703001002, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hot & sour soup'),
       'Veg Hot & Sour Soup', 'veg hot & sour soup', 'CHINESE SOUP', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001015);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001015, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001015);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001015, 400703001, 400703001001, 400703001015, 400703001002, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001015);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001015, 400703001015, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001015);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001015, 400703001015, 120.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001015);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001016, 400703001, 400703001003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'jeera rice'),
       'Jeera Rice', 'jeera rice', 'RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001016);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001016, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001016);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001016, 400703001, 400703001001, 400703001016, 400703001003, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001016);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001016, 400703001016, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001016);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001016, 400703001016, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001016);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001017, 400703001, 400703001003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lemon rice'),
       'Lemon Rice', 'lemon rice', 'RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001017);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001017, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001017);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001017, 400703001, 400703001001, 400703001017, 400703001003, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001017);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001017, 400703001017, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001017);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001017, 400703001017, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001017);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001018, 400703001, 400703001003, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'steam rice'),
       'Steam Rice', 'steam rice', 'RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001018);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001018, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001018);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001018, 400703001, 400703001001, 400703001018, 400703001003, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001018);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001018, 400703001018, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001018);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001018, 400703001018, 90.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001018);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001019, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'hyderabadi biryani'),
       'Hyderabadi Biryani', 'hyderabadi biryani', 'BIRYANI & PULAO', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001019);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001019, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001019);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001019, 400703001, 400703001001, 400703001019, 400703001004, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001019);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001019, 400703001019, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001019);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001019, 400703001019, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001019);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001020, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg biryani'),
       'Veg Biryani', 'veg biryani', 'BIRYANI & PULAO', 'veg', 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001020);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001020, 400703001, 400703001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001020);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001020, 400703001, 400703001001, 400703001020, 400703001004, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001020);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001020, 400703001020, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001020);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001020, 400703001020, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001020);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001021, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom biryani'),
       'Mushroom Biryani', 'mushroom biryani', 'BIRYANI & PULAO', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001021);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001021, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001021);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001021, 400703001, 400703001001, 400703001021, 400703001004, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001021);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001021, 400703001021, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001021);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001021, 400703001021, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001021);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001022, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer biryani'),
       'Paneer Biryani', 'paneer biryani', 'BIRYANI & PULAO', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001022);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001022, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001022);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001022, 400703001, 400703001001, 400703001022, 400703001004, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001022);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001022, 400703001022, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001022);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001022, 400703001022, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001022);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001023, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer pulao'),
       'Paneer Pulao', 'paneer pulao', 'BIRYANI & PULAO', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001023);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001023, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001023);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001023, 400703001, 400703001001, 400703001023, 400703001004, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001023);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001023, 400703001023, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001023);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001023, 400703001023, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001023);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001024, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg pulao'),
       'Veg Pulao', 'veg pulao', 'BIRYANI & PULAO', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001024);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001024, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001024);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001024, 400703001, 400703001001, 400703001024, 400703001004, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001024);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001024, 400703001024, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001024);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001024, 400703001024, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001024);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001025, 400703001, 400703001004, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kashmiri pulao'),
       'Kashmiri Pulao', 'kashmiri pulao', 'BIRYANI & PULAO', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001025);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001025, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001025);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001025, 400703001, 400703001001, 400703001025, 400703001004, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001025);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001025, 400703001025, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001025);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001025, 400703001025, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001025);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001026, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'vada pav'),
       'Vada Pav', 'vada pav', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001026);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001026, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001026);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001026, 400703001, 400703001001, 400703001026, 400703001005, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001026);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001026, 400703001026, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001026);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001026, 400703001026, 25.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001026);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001027, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'samosa pav'),
       'Samosa Pav', 'samosa pav', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001027);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001027, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001027);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001027, 400703001, 400703001001, 400703001027, 400703001005, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001027);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001027, 400703001027, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001027);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001027, 400703001027, 25.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001027);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001028, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'misal pav'),
       'Misal Pav', 'misal pav', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001028);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001028, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001028);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001028, 400703001, 400703001001, 400703001028, 400703001005, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001028);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001028, 400703001028, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001028);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001028, 400703001028, 60.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001028);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001029, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'usal pav'),
       'Usal Pav', 'usal pav', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001029);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001029, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001029);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001029, 400703001, 400703001001, 400703001029, 400703001005, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001029);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001029, 400703001029, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001029);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001029, 400703001029, 55.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001029);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001030, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'upma'),
       'Upma', 'upma', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001030);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001030, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001030);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001030, 400703001, 400703001001, 400703001030, 400703001005, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001030);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001030, 400703001030, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001030);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001030, 400703001030, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001030);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001031, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'poha'),
       'Poha', 'poha', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001031);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001031, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001031);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001031, 400703001, 400703001001, 400703001031, 400703001005, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001031);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001031, 400703001031, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001031);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001031, 400703001031, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001031);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001032, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'puri baji'),
       'Puri Baji', 'puri baji', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001032);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001032, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001032);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001032, 400703001, 400703001001, 400703001032, 400703001005, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001032);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001032, 400703001032, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001032);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001032, 400703001032, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001032);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001033, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chole bhature'),
       'Chole Bhature', 'chole bhature', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001033);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001033, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001033);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001033, 400703001, 400703001001, 400703001033, 400703001005, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001033);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001033, 400703001033, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001033);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001033, 400703001033, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001033);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001034, 400703001, 400703001005, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'extra bhature'),
       'Extra Bhature', 'extra bhature', 'SNACKS', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001034);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001034, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001034);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001034, 400703001, 400703001001, 400703001034, 400703001005, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001034);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001034, 400703001034, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001034);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001034, 400703001034, 30.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001034);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001035, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg fried rice'),
       'Veg Fried Rice', 'veg fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001035);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001035, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001035);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001035, 400703001, 400703001001, 400703001035, 400703001006, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001035);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001035, 400703001035, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001035);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001035, 400703001035, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001035);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001036, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg schezwan fried rice'),
       'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001036);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001036, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001036);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001036, 400703001, 400703001001, 400703001036, 400703001006, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001036);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001036, 400703001036, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001036);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001036, 400703001036, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001036);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001037, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg manchurian fried rice'),
       'Veg Manchurian Fried Rice', 'veg manchurian fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001037);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001037, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001037);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001037, 400703001, 400703001001, 400703001037, 400703001006, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001037);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001037, 400703001037, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001037);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001037, 400703001037, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001037);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001038, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg triple rice'),
       'Veg Triple Rice', 'veg triple rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001038);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001038, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001038);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001038, 400703001, 400703001001, 400703001038, 400703001006, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001038);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001038, 400703001038, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001038);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001038, 400703001038, 220.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001038);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001039, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hong kong fried rice'),
       'Veg Hong Kong Fried Rice', 'veg hong kong fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001039);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001039, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001039);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001039, 400703001, 400703001001, 400703001039, 400703001006, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001039);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001039, 400703001039, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001039);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001039, 400703001039, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001039);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001040, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg singapore fried rice'),
       'Veg Singapore Fried Rice', 'veg singapore fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001040);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001040, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001040);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001040, 400703001, 400703001001, 400703001040, 400703001006, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001040);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001040, 400703001040, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001040);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001040, 400703001040, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001040);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001041, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer fried rice'),
       'Paneer Fried Rice', 'paneer fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001041);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001041, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001041);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001041, 400703001, 400703001001, 400703001041, 400703001006, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001041);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001041, 400703001041, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001041);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001041, 400703001041, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001041);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001042, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer schezwan fried rice'),
       'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001042);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001042, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001042);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001042, 400703001, 400703001001, 400703001042, 400703001006, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001042);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001042, 400703001042, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001042);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001042, 400703001042, 220.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001042);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001043, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom fried rice'),
       'Mushroom Fried Rice', 'mushroom fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001043);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001043, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001043);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001043, 400703001, 400703001001, 400703001043, 400703001006, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001043);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001043, 400703001043, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001043);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001043, 400703001043, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001043);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001044, 400703001, 400703001006, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer triple schezwan fried rice'),
       'Paneer Triple Schezwan Fried Rice', 'paneer triple schezwan fried rice', 'CHINESE RICE', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001044);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001044, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001044);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001044, 400703001, 400703001001, 400703001044, 400703001006, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001044);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001044, 400703001044, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001044);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001044, 400703001044, 250.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001044);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001045, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tandoori roti'),
       'Tandoori Roti', 'tandoori roti', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001045);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001045, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001045);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001045, 400703001, 400703001001, 400703001045, 400703001007, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001045);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001045, 400703001045, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001045);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001045, 400703001045, 25.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001045);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001046, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'bakri'),
       'Bakri', 'bakri', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001046);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001046, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001046);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001046, 400703001, 400703001001, 400703001046, 400703001007, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001046);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001046, 400703001046, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001046);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001046, 400703001046, 25.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001046);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001047, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chappati'),
       'Chappati', 'chappati', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001047);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001047, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001047);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001047, 400703001, 400703001001, 400703001047, 400703001007, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001047);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001047, 400703001047, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001047);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001047, 400703001047, 15.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001047);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001048, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo paratha'),
       'Aloo Paratha', 'aloo paratha', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001048);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001048, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001048);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001048, 400703001, 400703001001, 400703001048, 400703001007, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001048);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001048, 400703001048, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001048);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001048, 400703001048, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001048);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001049, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'gobi paratha'),
       'Gobi Paratha', 'gobi paratha', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001049);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001049, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001049);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001049, 400703001, 400703001001, 400703001049, 400703001007, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001049);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001049, 400703001049, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001049);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001049, 400703001049, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001049);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001050, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer paratha'),
       'Paneer Paratha', 'paneer paratha', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001050);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001050, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001050);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001050, 400703001, 400703001001, 400703001050, 400703001007, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001050);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001050, 400703001050, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001050);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001050, 400703001050, 120.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001050);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001051, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'methi paratha'),
       'Methi Paratha', 'methi paratha', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001051);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001051, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001051);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001051, 400703001, 400703001001, 400703001051, 400703001007, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001051);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001051, 400703001051, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001051);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001051, 400703001051, 100.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001051);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001052, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter tandoori roti'),
       'Butter Tandoori Roti', 'butter tandoori roti', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001052);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001052, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001052);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001052, 400703001, 400703001001, 400703001052, 400703001007, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001052);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001052, 400703001052, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001052);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001052, 400703001052, 30.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001052);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001053, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter naan'),
       'Butter Naan', 'butter naan', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001053);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001053, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001053);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001053, 400703001, 400703001001, 400703001053, 400703001007, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001053);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001053, 400703001053, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001053);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001053, 400703001053, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001053);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001054, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'naan'),
       'Naan', 'naan', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001054);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001054, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001054);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001054, 400703001, 400703001001, 400703001054, 400703001007, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001054);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001054, 400703001054, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001054);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001054, 400703001054, 35.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001054);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001055, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kulcha'),
       'Kulcha', 'kulcha', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001055);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001055, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001055);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001055, 400703001, 400703001001, 400703001055, 400703001007, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001055);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001055, 400703001055, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001055);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001055, 400703001055, 35.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001055);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001056, 400703001, 400703001007, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'butter kulcha'),
       'Butter Kulcha', 'butter kulcha', 'TANDOORI', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001056);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001056, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001056);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001056, 400703001, 400703001001, 400703001056, 400703001007, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001056);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001056, 400703001056, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001056);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001056, 400703001056, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001056);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001057, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'navratna korma'),
       'Navratna Korma', 'navratna korma', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001057);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001057, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001057);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001057, 400703001, 400703001001, 400703001057, 400703001008, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001057);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001057, 400703001057, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001057);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001057, 400703001057, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001057);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001058, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom masala'),
       'Mushroom Masala', 'mushroom masala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001058);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001058, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001058);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001058, 400703001, 400703001001, 400703001058, 400703001008, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001058);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001058, 400703001058, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001058);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001058, 400703001058, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001058);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001059, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom matar'),
       'Mushroom Matar', 'mushroom matar', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001059);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001059, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001059);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001059, 400703001, 400703001001, 400703001059, 400703001008, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001059);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001059, 400703001059, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001059);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001059, 400703001059, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001059);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001060, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mushroom kadai'),
       'Mushroom Kadai', 'mushroom kadai', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001060);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001060, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001060);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001060, 400703001, 400703001001, 400703001060, 400703001008, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001060);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001060, 400703001060, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001060);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001060, 400703001060, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001060);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001061, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg kadai'),
       'Veg Kadai', 'veg kadai', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001061);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001061, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001061);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001061, 400703001, 400703001001, 400703001061, 400703001008, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001061);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001061, 400703001061, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001061);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001061, 400703001061, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001061);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001062, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg hyderabadi'),
       'Veg Hyderabadi', 'veg hyderabadi', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001062);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001062, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001062);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001062, 400703001, 400703001001, 400703001062, 400703001008, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001062);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001062, 400703001062, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001062);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001062, 400703001062, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001062);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001063, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kolhapuri'),
       'Paneer Kolhapuri', 'paneer kolhapuri', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001063);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001063, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001063);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001063, 400703001, 400703001001, 400703001063, 400703001008, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001063);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001063, 400703001063, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001063);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001063, 400703001063, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001063);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001064, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer hyderabadi'),
       'Paneer Hyderabadi', 'paneer hyderabadi', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001064);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001064, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001064);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001064, 400703001, 400703001001, 400703001064, 400703001008, 8
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001064);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001064, 400703001064, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001064);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001064, 400703001064, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001064);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001065, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal fry'),
       'Dal Fry', 'dal fry', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001065);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001065, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001065);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001065, 400703001, 400703001001, 400703001065, 400703001008, 9
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001065);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001065, 400703001065, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001065);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001065, 400703001065, 130.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001065);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001066, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal tadka'),
       'Dal Tadka', 'dal tadka', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001066);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001066, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001066);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001066, 400703001, 400703001001, 400703001066, 400703001008, 10
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001066);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001066, 400703001066, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001066);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001066, 400703001066, 140.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001066);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001067, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'methi makhana'),
       'Methi Makhana', 'methi makhana', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001067);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001067, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001067);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001067, 400703001, 400703001001, 400703001067, 400703001008, 11
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001067);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001067, 400703001067, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001067);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001067, 400703001067, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001067);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001068, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'daal kolhapuri'),
       'Daal Kolhapuri', 'daal kolhapuri', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001068);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001068, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001068);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001068, 400703001, 400703001001, 400703001068, 400703001008, 12
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001068);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001068, 400703001068, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001068);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001068, 400703001068, 140.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001068);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001069, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'daal makhanivala'),
       'Daal Makhanivala', 'daal makhanivala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001069);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001069, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001069);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001069, 400703001, 400703001001, 400703001069, 400703001008, 13
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001069);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001069, 400703001069, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001069);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001069, 400703001069, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001069);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001070, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg korma'),
       'Veg Korma', 'veg korma', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001070);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001070, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001070);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001070, 400703001, 400703001001, 400703001070, 400703001008, 14
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001070);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001070, 400703001070, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001070);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001070, 400703001070, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001070);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001071, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer masala'),
       'Paneer Masala', 'paneer masala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001071);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001071, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001071);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001071, 400703001, 400703001001, 400703001071, 400703001008, 15
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001071);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001071, 400703001071, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001071);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001071, 400703001071, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001071);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001072, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer flower'),
       'Paneer Flower', 'paneer flower', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001072);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001072, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001072);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001072, 400703001, 400703001001, 400703001072, 400703001008, 16
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001072);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001072, 400703001072, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001072);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001072, 400703001072, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001072);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001073, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'palak paneer'),
       'Palak Paneer', 'palak paneer', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001073);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001073, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001073);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001073, 400703001, 400703001001, 400703001073, 400703001008, 17
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001073);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001073, 400703001073, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001073);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001073, 400703001073, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001073);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001074, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer burji'),
       'Paneer Burji', 'paneer burji', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001074);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001074, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001074);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001074, 400703001, 400703001001, 400703001074, 400703001008, 18
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001074);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001074, 400703001074, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001074);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001074, 400703001074, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001074);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001075, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer makhanwala'),
       'Paneer Makhanwala', 'paneer makhanwala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001075);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001075, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001075);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001075, 400703001, 400703001001, 400703001075, 400703001008, 19
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001075);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001075, 400703001075, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001075);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001075, 400703001075, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001075);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001076, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tikka masala'),
       'Paneer Tikka Masala', 'paneer tikka masala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001076);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001076, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001076);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001076, 400703001, 400703001001, 400703001076, 400703001008, 20
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001076);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001076, 400703001076, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001076);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001076, 400703001076, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001076);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001077, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg jaipuri'),
       'Veg Jaipuri', 'veg jaipuri', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001077);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001077, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001077);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001077, 400703001, 400703001001, 400703001077, 400703001008, 21
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001077);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001077, 400703001077, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001077);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001077, 400703001077, 170.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001077);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001078, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sev bhaji'),
       'Sev Bhaji', 'sev bhaji', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001078);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001078, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001078);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001078, 400703001, 400703001001, 400703001078, 400703001008, 22
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001078);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001078, 400703001078, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001078);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001078, 400703001078, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001078);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001079, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg kofta'),
       'Veg Kofta', 'veg kofta', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001079);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001079, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001079);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001079, 400703001, 400703001001, 400703001079, 400703001008, 23
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001079);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001079, 400703001079, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001079);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001079, 400703001079, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001079);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001080, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'kaju curry'),
       'Kaju Curry', 'kaju curry', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001080);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001080, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001080);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001080, 400703001, 400703001001, 400703001080, 400703001008, 24
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001080);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001080, 400703001080, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001080);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001080, 400703001080, 200.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001080);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001081, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'methi malai paneer'),
       'Methi Malai Paneer', 'methi malai paneer', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001081);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001081, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001081);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001081, 400703001, 400703001001, 400703001081, 400703001008, 25
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001081);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001081, 400703001081, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001081);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001081, 400703001081, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001081);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001082, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'palak lasuni'),
       'Palak Lasuni', 'palak lasuni', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001082);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001082, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001082);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001082, 400703001, 400703001001, 400703001082, 400703001008, 26
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001082);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001082, 400703001082, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001082);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001082, 400703001082, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001082);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001083, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer makhani'),
       'Paneer Makhani', 'paneer makhani', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001083);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001083, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001083);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001083, 400703001, 400703001001, 400703001083, 400703001008, 27
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001083);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001083, 400703001083, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001083);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001083, 400703001083, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001083);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001084, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kadai'),
       'Paneer Kadai', 'paneer kadai', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001084);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001084, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001084);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001084, 400703001, 400703001001, 400703001084, 400703001008, 28
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001084);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001084, 400703001084, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001084);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001084, 400703001084, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001084);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001085, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer kofta'),
       'Paneer Kofta', 'paneer kofta', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001085);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001085, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001085);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001085, 400703001, 400703001001, 400703001085, 400703001008, 29
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001085);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001085, 400703001085, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001085);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001085, 400703001085, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001085);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001086, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer korma'),
       'Paneer Korma', 'paneer korma', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001086);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001086, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001086);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001086, 400703001, 400703001001, 400703001086, 400703001008, 30
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001086);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001086, 400703001086, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001086);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001086, 400703001086, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001086);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001087, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer tomato'),
       'Paneer Tomato', 'paneer tomato', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001087);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001087, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001087);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001087, 400703001, 400703001001, 400703001087, 400703001008, 31
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001087);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001087, 400703001087, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001087);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001087, 400703001087, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001087);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001088, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sahi paneer'),
       'Sahi Paneer', 'sahi paneer', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001088);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001088, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001088);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001088, 400703001, 400703001001, 400703001088, 400703001008, 32
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001088);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001088, 400703001088, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001088);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001088, 400703001088, 170.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001088);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001089, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer handi'),
       'Paneer Handi', 'paneer handi', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001089);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001089, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001089);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001089, 400703001, 400703001001, 400703001089, 400703001008, 33
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001089);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001089, 400703001089, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001089);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001089, 400703001089, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001089);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001090, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer pasanda'),
       'Paneer Pasanda', 'paneer pasanda', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001090);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001090, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001090);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001090, 400703001, 400703001001, 400703001090, 400703001008, 34
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001090);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001090, 400703001090, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001090);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001090, 400703001090, 180.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001090);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001091, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'paneer channa'),
       'Paneer Channa', 'paneer channa', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001091);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001091, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001091);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001091, 400703001, 400703001001, 400703001091, 400703001008, 35
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001091);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001091, 400703001091, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001091);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001091, 400703001091, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001091);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001092, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tomato masala'),
       'Tomato Masala', 'tomato masala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001092);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001092, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001092);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001092, 400703001, 400703001001, 400703001092, 400703001008, 36
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001092);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001092, 400703001092, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001092);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001092, 400703001092, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001092);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001093, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'malai kofa'),
       'Malai Kofa', 'malai kofa', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001093);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001093, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001093);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001093, 400703001, 400703001001, 400703001093, 400703001008, 37
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001093);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001093, 400703001093, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001093);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001093, 400703001093, 190.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001093);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001094, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'channa masala'),
       'Channa Masala', 'channa masala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001094);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001094, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001094);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001094, 400703001, 400703001001, 400703001094, 400703001008, 38
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001094);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001094, 400703001094, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001094);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001094, 400703001094, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001094);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001095, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo gobhi'),
       'Aloo Gobhi', 'aloo gobhi', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001095);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001095, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001095);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001095, 400703001, 400703001001, 400703001095, 400703001008, 39
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001095);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001095, 400703001095, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001095);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001095, 400703001095, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001095);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001096, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo matar'),
       'Aloo Matar', 'aloo matar', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001096);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001096, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001096);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001096, 400703001, 400703001001, 400703001096, 400703001008, 40
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001096);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001096, 400703001096, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001096);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001096, 400703001096, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001096);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001097, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'veg kolhapuri'),
       'Veg Kolhapuri', 'veg kolhapuri', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001097);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001097, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001097);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001097, 400703001, 400703001001, 400703001097, 400703001008, 41
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001097);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001097, 400703001097, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001097);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001097, 400703001097, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001097);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001098, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'mix veg'),
       'Mix Veg', 'mix veg', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001098);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001098, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001098);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001098, 400703001, 400703001001, 400703001098, 400703001008, 42
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001098);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001098, 400703001098, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001098);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001098, 400703001098, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001098);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001099, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'green peas masala'),
       'Green Peas Masala', 'green peas masala', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001099);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001099, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001099);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001099, 400703001, 400703001001, 400703001099, 400703001008, 43
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001099);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001099, 400703001099, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001099);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001099, 400703001099, 150.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001099);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001100, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'bhindi masala fry'),
       'Bhindi Masala Fry', 'bhindi masala fry', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001100);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001100, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001100);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001100, 400703001, 400703001001, 400703001100, 400703001008, 44
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001100);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001100, 400703001100, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001100);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001100, 400703001100, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001100);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001101, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'aloo methi'),
       'Aloo Methi', 'aloo methi', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001101);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001101, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001101);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001101, 400703001, 400703001001, 400703001101, 400703001008, 45
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001101);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001101, 400703001101, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001101);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001101, 400703001101, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001101);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001102, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'methi palak'),
       'Methi Palak', 'methi palak', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001102);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001102, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001102);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001102, 400703001, 400703001001, 400703001102, 400703001008, 46
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001102);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001102, 400703001102, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001102);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001102, 400703001102, 160.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001102);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001103, 400703001, 400703001008, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dum aloo punjabi'),
       'Dum Aloo Punjabi', 'dum aloo punjabi', 'PUNJABI CURRY MASALA', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001103);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001103, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001103);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001103, 400703001, 400703001001, 400703001103, 400703001008, 47
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001103);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001103, 400703001103, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001103);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001103, 400703001103, 170.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001103);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001104, 400703001, 400703001009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'thali lunch / dinner'),
       'Thali Lunch / Dinner', 'thali lunch / dinner', 'LUNCH & DINNER', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001104);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001104, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001104);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001104, 400703001, 400703001001, 400703001104, 400703001009, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001104);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001104, 400703001104, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001104);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001104, 400703001104, 120.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001104);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001105, 400703001, 400703001009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'special lunch'),
       'Special Lunch', 'special lunch', 'LUNCH & DINNER', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001105);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001105, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001105);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001105, 400703001, 400703001001, 400703001105, 400703001009, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001105);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001105, 400703001105, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001105);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001105, 400703001105, 250.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001105);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001106, 400703001, 400703001009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'dal rice'),
       'Dal Rice', 'dal rice', 'LUNCH & DINNER', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001106);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001106, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001106);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001106, 400703001, 400703001001, 400703001106, 400703001009, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001106);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001106, 400703001106, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001106);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001106, 400703001106, 70.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001106);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001107, 400703001, 400703001009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sukha baji'),
       'Sukha Baji', 'sukha baji', 'LUNCH & DINNER', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001107);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001107, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001107);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001107, 400703001, 400703001001, 400703001107, 400703001009, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001107);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001107, 400703001107, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001107);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001107, 400703001107, 60.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001107);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001108, 400703001, 400703001009, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chappati baji'),
       'Chappati Baji', 'chappati baji', 'LUNCH & DINNER', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001108);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001108, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001108);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001108, 400703001, 400703001001, 400703001108, 400703001009, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001108);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001108, 400703001108, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001108);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001108, 400703001108, 70.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001108);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001109, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'tea'),
       'Tea', 'tea', 'BEVERAGES', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001109);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001109, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001109);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001109, 400703001, 400703001001, 400703001109, 400703001010, 1
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001109);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001109, 400703001109, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001109);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001109, 400703001109, 15.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001109);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001110, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'special tea'),
       'Special Tea', 'special tea', 'BEVERAGES', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001110);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001110, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001110);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001110, 400703001, 400703001001, 400703001110, 400703001010, 2
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001110);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001110, 400703001110, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001110);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001110, 400703001110, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001110);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001111, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'coffee'),
       'Coffee', 'coffee', 'BEVERAGES', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001111);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001111, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001111);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001111, 400703001, 400703001001, 400703001111, 400703001010, 3
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001111);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001111, 400703001111, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001111);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001111, 400703001111, 20.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001111);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001112, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'lassi'),
       'Lassi', 'lassi', 'BEVERAGES', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001112);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001112, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001112);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001112, 400703001, 400703001001, 400703001112, 400703001010, 4
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001112);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001112, 400703001112, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001112);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001112, 400703001112, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001112);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001113, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'chaas'),
       'Chaas', 'chaas', 'BEVERAGES', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001113);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001113, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001113);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001113, 400703001, 400703001001, 400703001113, 400703001010, 5
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001113);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001113, 400703001113, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001113);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001113, 400703001113, 20.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001113);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001114, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'sonkadi'),
       'Sonkadi', 'sonkadi', 'BEVERAGES', 'veg', 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001114);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001114, 400703001, 400703001001, 0.95, 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001114);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001114, 400703001, 400703001001, 400703001114, 400703001010, 6
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001114);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001114, 400703001114, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001114);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, source_id, effective_from, verification_status_code)
SELECT 400703001114, 400703001114, 40.00, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'unverified'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001114);

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
                        raw_category_text, food_classification_code, verification_status_code)
SELECT 400703001115, 400703001, 400703001010, (SELECT canonical_dish_id FROM canonical_dish WHERE normalized_name = 'ice cream'),
       'Ice Cream', 'ice cream', 'BEVERAGES', 'veg', 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 400703001115);
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT 400703001115, 400703001, 400703001001, 0.75, 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_source WHERE menu_item_id = 400703001115);
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT 400703001115, 400703001, 400703001001, 400703001115, 400703001010, 7
WHERE NOT EXISTS (SELECT 1 FROM menu_board_item WHERE menu_board_item_id = 400703001115);
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
SELECT 400703001115, 400703001115, 'Regular', 'fixed', TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item_variant WHERE variant_id = 400703001115);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, source_id, effective_from, verification_status_code)
SELECT 400703001115, 400703001115, NULL, TRUE, 400703001, (clock_timestamp() AT TIME ZONE 'UTC'), 'needs_review'
WHERE NOT EXISTS (SELECT 1 FROM menu_item_price WHERE price_id = 400703001115);

COMMIT;

-- ----------------------------------------------------------------------
-- Sanity check
-- ----------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM menu_category WHERE restaurant_id = 400703001) AS categories,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id = 400703001) AS items,
    (SELECT COUNT(*) FROM menu_item_variant miv JOIN menu_item mi ON mi.menu_item_id=miv.menu_item_id WHERE mi.restaurant_id=400703001) AS variants,
    (SELECT COUNT(*) FROM menu_item WHERE restaurant_id=400703001 AND verification_status_code='needs_review') AS flagged_for_review,
    (SELECT COUNT(*) FROM menu_item_price mip JOIN menu_item_variant miv ON miv.variant_id=mip.variant_id JOIN menu_item mi ON mi.menu_item_id=miv.menu_item_id WHERE mi.restaurant_id=400703001 AND mip.is_market_price) AS market_price_items;