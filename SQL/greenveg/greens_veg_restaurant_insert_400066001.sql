/* ============================================================================
   KHAUSTAN - RESTAURANT MENU INSERT SCRIPT (PostgreSQL / KhaustanRestaurantMenu)
   Restaurant : Greens Veg. Restaurant, Borivali East, Mumbai 400066
   Source     : Greens_Veg_Restaurant_Menu_1.json  (7 menu page images transcribed to JSON)
   Namespace  : establishment_id = restaurant_id = source_id = 400066001

   ID RULES (literal values, no sequences / nextval):
     9-digit  : establishment_id, restaurant_id, source_id            = 400066001
     12-digit : menu_board_id                                         = 400066001001
                menu_category, menu_item, menu_item_variant, menu_item_price,
                menu_item_availability, menu_board_item ids           start at 400066001001 (+1 per row, JSON order)
                menu_item_source.menu_item_id                         = the menu_item id (no second sequence)
                menu_board_category.restaurant_id                     = 400066001 (no standalone id column)
     Standalone ids outside those namespaces (restaurant_hours, menu_extraction_batch, bundle)
                use suffix 901+ : 400066001901, 400066001902, ...

   NOT DONE ON PURPOSE:
     - No INSERT/UPDATE/DELETE on any lookup table.
     - No INSERT into canonical_dish / canonical_dish_name. Items that match an existing canonical dish
       (exact match after trim + whitespace-collapse + case-fold) carry its canonical_dish_id; the rest
       have canonical_dish_id = NULL and are listed in the two CSV files delivered with this script.

   COUNTS: 24 categories, 429 menu_items, 432 variants, 431 prices (market-price items: none).

   INTERPRETATION DECISIONS (all from the JSON only):
     1. Headings ending " - continuation" and the repeated "Sandwiches & Grill" heading are merged into one
        category each; raw_category_text holds the printed heading without the " - continuation" suffix.
     2. Printed pairs that are sizes of one dish become ONE menu_item with two variants:
        Steam Rice (Full/Half), Vanilla (Small/Big), Cold Drinks (200 ml/500 ml). First-listed variant = default.
     3. The JSON has one overall menu and no board label -> one a_la_carte board (menu_board_id 400066001001).
     4. Operating hours "9 am-12 am" carry no day restriction -> one slot per day, Mon-Sun (day_of_week 1-7).
        12 am is stored as 00:00 (closes_at < opens_at = spans midnight, same convention as price_schedule).
     5. food_classification_code: the 3 "Omlet" items = egg (protein EGG); every other item = veg (inferred from
        the restaurant name / section headings). is_jain = TRUE only where the item name says "Jain".
     6. Punjabi Thali (page 7): one menu_item, price 280.00, availability 11:00-18:00 every day, one bundle row
        (bundle_type_code thali) whose description carries the printed contents. No component items invented.
     7. Restaurant-level fields the JSON does not give (phones, GST, bar, delivery partners) stay NULL / default;
        state/city/locality are taken from the JSON address; bar_license_type = none, has_bar = FALSE.
   ============================================================================ */

\connect "KhaustanRestaurantMenu"
BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Pre-flight checks (read-only). Any failure aborts the whole script.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400066001)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400066001)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 400066001)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400066001) THEN
        RAISE EXCEPTION 'Establishment/restaurant/source 400066001 is already onboarded - script not re-run';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM protein_type WHERE code = 'EGG') THEN
        RAISE EXCEPTION 'Lookup protein_type code EGG is missing - add it with a separate lookup seed script';
    END IF;
    IF EXISTS (SELECT 1 FROM unnest(ARRAY[10027,10045,10048,10085,10110,10118,10154,10157,10161,10164,10167,10171,10175,10196,10197,10206,10208,10228,10253,10254,10255,10306,10307,10321,10322,10325,10326,10327,10329,10336,10349,10364,10369,10383,10413,10421,10426,10428,10433,10448,10471,10476,10481,10486,10490,10500,10530,10532,10540,10543,10545,10555,10563,10571,10589,10591,10602,10603,10628,10631,10658,10704,10719,10722,10726,10756,10770,10773,10794,10805,10806,10810,10811,10814,10824,10849,10857,10859,10867,10871,10879,10884,10886,10888,10890,10893,11018,11019,13023,13026,13028,13075,13133,13134,13143,13151,13155,13176,13187,13218,13226,13233,13235,13236,13237,13242,13243,13247,13254,13262,13279,13285,13314,13316,13333,13337,13338,13340,13342,13349,13351,13356,13371,13385,13387,13395,13402,13404,13405,13407,13409,13417,13419,13431,13437,13448,13486,13507,13520,13523,13527,13557,13570,13581,13586,13592,13606,13615,13622,13632,13647,13650,13654,13657,13658,13659,13668,13704,13706,13715,13717,13725,13793,13804,13832,13853,13865,13918,13969,13977,13993,13994,14035,14038,14044,14069,14072,14097,14098,14104,14106,14108,14129,14138,14140,14151,14163,14166,14179,14181,14196,14199,14202,14204,14215,23006,23008,23012,23013,23017,23019,23024,23027,23033,23035,23040,23056,23061,23068,23069,23072,23078,23079,23089,23091,23092,23094,40005,40006,40008,40010,40020,40023,40035,50008,50013,50034,50036,50040,50053,50061,50062,50069,50081,50082,50083,50089,50102,50104,50111,50133,50136,50137,50142,50143,50152,50154,50162,53001,53003,60006,60042,60047,60048,60050,60058,60061,60062,60072,60076,60078,60086,60090,60095,60104,60110,60113,60126,60143,60155,60156,60157,60159,60163,60168,60170,60175,60179,60180,60182,60185,60186,60194,60196,60198,60202,60205,60208,60210,60213,60218,60226,60228,60229,60231,60232,60236,60240,60245,60248,60249,60251,60260,60261,60268,60278,60323,60339,60424,60428]::bigint[]) AS x(id)
               WHERE NOT EXISTS (SELECT 1 FROM canonical_dish c WHERE c.canonical_dish_id = x.id)) THEN
        RAISE EXCEPTION 'canonical_dish ids missing in database: %%',
            (SELECT string_agg(x.id::text, ',' ORDER BY x.id) FROM unnest(ARRAY[10027,10045,10048,10085,10110,10118,10154,10157,10161,10164,10167,10171,10175,10196,10197,10206,10208,10228,10253,10254,10255,10306,10307,10321,10322,10325,10326,10327,10329,10336,10349,10364,10369,10383,10413,10421,10426,10428,10433,10448,10471,10476,10481,10486,10490,10500,10530,10532,10540,10543,10545,10555,10563,10571,10589,10591,10602,10603,10628,10631,10658,10704,10719,10722,10726,10756,10770,10773,10794,10805,10806,10810,10811,10814,10824,10849,10857,10859,10867,10871,10879,10884,10886,10888,10890,10893,11018,11019,13023,13026,13028,13075,13133,13134,13143,13151,13155,13176,13187,13218,13226,13233,13235,13236,13237,13242,13243,13247,13254,13262,13279,13285,13314,13316,13333,13337,13338,13340,13342,13349,13351,13356,13371,13385,13387,13395,13402,13404,13405,13407,13409,13417,13419,13431,13437,13448,13486,13507,13520,13523,13527,13557,13570,13581,13586,13592,13606,13615,13622,13632,13647,13650,13654,13657,13658,13659,13668,13704,13706,13715,13717,13725,13793,13804,13832,13853,13865,13918,13969,13977,13993,13994,14035,14038,14044,14069,14072,14097,14098,14104,14106,14108,14129,14138,14140,14151,14163,14166,14179,14181,14196,14199,14202,14204,14215,23006,23008,23012,23013,23017,23019,23024,23027,23033,23035,23040,23056,23061,23068,23069,23072,23078,23079,23089,23091,23092,23094,40005,40006,40008,40010,40020,40023,40035,50008,50013,50034,50036,50040,50053,50061,50062,50069,50081,50082,50083,50089,50102,50104,50111,50133,50136,50137,50142,50143,50152,50154,50162,53001,53003,60006,60042,60047,60048,60050,60058,60061,60062,60072,60076,60078,60086,60090,60095,60104,60110,60113,60126,60143,60155,60156,60157,60159,60163,60168,60170,60175,60179,60180,60182,60185,60186,60194,60196,60198,60202,60205,60208,60210,60213,60218,60226,60228,60229,60231,60232,60236,60240,60245,60248,60249,60251,60260,60261,60268,60278,60323,60339,60424,60428]::bigint[]) AS x(id)
             WHERE NOT EXISTS (SELECT 1 FROM canonical_dish c WHERE c.canonical_dish_id = x.id));
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Establishment, restaurant, source, extraction batch
--    Source: JSON, "restaurant" (name, address, latitude, longitude, hours)
-- ---------------------------------------------------------------------------
INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code, latitude, longitude
) VALUES (
    400066001, 'Greens Veg. Restaurant', 'greens veg. restaurant', 'Apartment, Shop No. 8, Amita, 5, Kasthurba Rd', NULL,
    'Borivali East', 'Mumbai', 'Maharashtra', 'IN', '400066', 19.23010364214187, 72.86201085404011
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name, has_bar, bar_license_type
) VALUES (
    400066001, 400066001, 'Greens Veg. Restaurant', 'greens veg. restaurant', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, external_reference, source_uri)
VALUES (400066001, 'ai_menu_extraction', 'provided_images: page-0001.jpg, page-0002.jpg, page-0003.jpg, page-0004.jpg, page-0005.jpg, page-0006.jpg, page-0007.jpg', 'Greens_Veg_Restaurant_Menu_1.json');

INSERT INTO menu_extraction_batch (
    extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code
) VALUES (
    400066001901, 400066001, 400066001, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
);

-- ---------------------------------------------------------------------------
-- 2. Operating hours  (Source: JSON, "restaurant.hours" = "9 am-12 am", every day)
-- ---------------------------------------------------------------------------
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at) VALUES
    (400066001901, 400066001, 1, 1, '09:00', '00:00'),
    (400066001902, 400066001, 2, 1, '09:00', '00:00'),
    (400066001903, 400066001, 3, 1, '09:00', '00:00'),
    (400066001904, 400066001, 4, 1, '09:00', '00:00'),
    (400066001905, 400066001, 5, 1, '09:00', '00:00'),
    (400066001906, 400066001, 6, 1, '09:00', '00:00'),
    (400066001907, 400066001, 7, 1, '09:00', '00:00');

-- ---------------------------------------------------------------------------
-- 3. Canonical dishes: NO INSERTS (read-only). See the delivered CSV files.
--    Lookup rows used below are resolved by code (protein_type EGG) - nothing is inserted.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 4. Menu board and categories (leaf headings, JSON order, merged continuations)
-- ---------------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, display_sequence)
VALUES (400066001001, 400066001, 'Menu', 'a_la_carte', 1);

INSERT INTO menu_category (menu_category_id, restaurant_id, parent_category_id, name, display_sequence) VALUES
    (400066001001, 400066001, NULL, 'South Indian Dishes', 1),
    (400066001002, 400066001, NULL, 'Fasting Items', 2),
    (400066001003, 400066001, NULL, 'Sandwiches & Grill', 3),
    (400066001004, 400066001, NULL, 'Pizza', 4),
    (400066001005, 400066001, NULL, 'Hot Beverages', 5),
    (400066001006, 400066001, NULL, 'Pav Bhaji', 6),
    (400066001007, 400066001, NULL, 'Soups', 7),
    (400066001008, 400066001, NULL, 'Starter', 8),
    (400066001009, 400066001, NULL, 'Punjabi Dishes', 9),
    (400066001010, 400066001, NULL, 'Dal & Other Indian Dishes', 10),
    (400066001011, 400066001, NULL, 'Roti (Tandoori)', 11),
    (400066001012, 400066001, NULL, 'Rice, Biryani & Pulav', 12),
    (400066001013, 400066001, NULL, 'Chinese Dishes Vegetable', 13),
    (400066001014, 400066001, NULL, 'Chinese Rice & Noodles', 14),
    (400066001015, 400066001, NULL, 'Salad / Raitha', 15),
    (400066001016, 400066001, NULL, 'Cold Drinks', 16),
    (400066001017, 400066001, NULL, 'Lassi', 17),
    (400066001018, 400066001, NULL, 'Juices', 18),
    (400066001019, 400066001, NULL, 'Milk Shakes', 19),
    (400066001020, 400066001, NULL, 'Fruit Special', 20),
    (400066001021, 400066001, NULL, 'Falooda', 21),
    (400066001022, 400066001, NULL, 'Mocktails', 22),
    (400066001023, 400066001, NULL, 'Ice Cream Regular Cups / Candy', 23),
    (400066001024, 400066001, NULL, 'Punjabi Thali', 24);

-- ---------------------------------------------------------------------------
-- 5. Menu items, variants and prices (one block per JSON section, JSON order)
-- ---------------------------------------------------------------------------
-- Source: JSON, "pages[1].columns[0].sections[0].items"  [South Indian Dishes]  -> menu_category_id 400066001001
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001001, 400066001, 400066001001, 10321, 'Idli', 'idli', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #01
    (400066001002, 400066001, 400066001001, 10329, 'Idli Vada', 'idli vada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #02
    (400066001003, 400066001, 400066001001, 10448, 'Mendu Vada', 'mendu vada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #03
    (400066001004, 400066001, 400066001001, 10322, 'Idli Butter', 'idli butter', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #04
    (400066001005, 400066001, 400066001001, 10326, 'Idli Dahi', 'idli dahi', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #05
    (400066001006, 400066001, 400066001001, 10327, 'Idli Fry', 'idli fry', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #06
    (400066001007, 400066001, 400066001001, 10228, 'Dahi Vada', 'dahi vada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #07
    (400066001008, 400066001, 400066001001, 10726, 'Sada Dosa', 'sada dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #08
    (400066001009, 400066001, 400066001001, 10421, 'Masala Dosa', 'masala dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #09
    (400066001010, 400066001, 400066001001, NULL, 'Paper Sada', 'paper sada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #10
    (400066001011, 400066001, 400066001001, 13668, 'Paper Masala', 'paper masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #11
    (400066001012, 400066001, 400066001001, NULL, 'Cheese Paper Sada', 'cheese paper sada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #12
    (400066001013, 400066001, 400066001001, NULL, 'Cheese Paper Masala', 'cheese paper masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #13
    (400066001014, 400066001, 400066001001, 10500, 'Mysore Sada Dosa', 'mysore sada dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #14
    (400066001015, 400066001, 400066001001, NULL, 'Mysore Masala', 'mysore masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #15
    (400066001016, 400066001, 400066001001, 10704, 'Rava Dosa', 'rava dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #16
    (400066001017, 400066001, 400066001001, NULL, 'Rava Masala', 'rava masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #17
    (400066001018, 400066001, 400066001001, NULL, 'Onion Rava Sada', 'onion rava sada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #18
    (400066001019, 400066001, 400066001001, NULL, 'Onion Rava Masala', 'onion rava masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #19
    (400066001020, 400066001, 400066001001, 10824, 'Uttappam', 'uttappam', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #20
    (400066001021, 400066001, 400066001001, 10530, 'Onion Uttappam', 'onion uttappam', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #21
    (400066001022, 400066001, 400066001001, 10814, 'Tomato Uttappam', 'tomato uttappam', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #22
    (400066001023, 400066001, 400066001001, 10810, 'Tomato Onion Uttappam', 'tomato onion uttappam', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #23
    (400066001024, 400066001, 400066001001, 10208, 'Coconut Uttappam', 'coconut uttappam', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #24
    (400066001025, 400066001, 400066001001, 10433, 'Masala Uttappam', 'masala uttappam', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #25
    (400066001026, 400066001, 400066001001, NULL, 'Tomato Omlet', 'tomato omlet', NULL, 'South Indian Dishes', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), NULL, 'needs_review'), -- #26
    (400066001027, 400066001, 400066001001, 10773, 'Spring Dosa', 'spring dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #27
    (400066001028, 400066001, 400066001001, NULL, 'Palak Sada', 'palak sada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #28
    (400066001029, 400066001, 400066001001, NULL, 'Palak Masala', 'palak masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #29
    (400066001030, 400066001, 400066001001, NULL, 'Schezwan Dosa', 'schezwan dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #30
    (400066001031, 400066001, 400066001001, NULL, 'Schezwan Masala', 'schezwan masala', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #31
    (400066001032, 400066001, 400066001001, NULL, 'Millennium Dosa', 'millennium dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #32
    (400066001033, 400066001, 400066001001, 10197, 'Chinese Dosa', 'chinese dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #33
    (400066001034, 400066001, 400066001001, 23092, 'Puri Bhaji', 'puri bhaji', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #34
    (400066001035, 400066001, 400066001001, NULL, 'Cheese Spring Dosa', 'cheese spring dosa', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #35
    (400066001036, 400066001, 400066001001, NULL, 'Batata Wada', 'batata wada', NULL, 'South Indian Dishes', 'veg', NULL, NULL, 'unverified'); -- #379
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001001, 400066001001, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001002, 400066001002, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001003, 400066001003, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001004, 400066001004, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001005, 400066001005, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001006, 400066001006, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001007, 400066001007, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001008, 400066001008, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001009, 400066001009, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001010, 400066001010, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001011, 400066001011, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001012, 400066001012, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001013, 400066001013, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001014, 400066001014, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001015, 400066001015, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001016, 400066001016, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001017, 400066001017, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001018, 400066001018, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001019, 400066001019, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001020, 400066001020, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001021, 400066001021, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001022, 400066001022, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001023, 400066001023, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001024, 400066001024, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001025, 400066001025, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001026, 400066001026, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001027, 400066001027, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001028, 400066001028, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001029, 400066001029, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001030, 400066001030, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001031, 400066001031, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001032, 400066001032, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001033, 400066001033, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001034, 400066001034, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001035, 400066001035, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001036, 400066001036, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001001, 400066001001, 78.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001002, 400066001002, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001003, 400066001003, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001004, 400066001004, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001005, 400066001005, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001006, 400066001006, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001007, 400066001007, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001008, 400066001008, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001009, 400066001009, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001010, 400066001010, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001011, 400066001011, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001012, 400066001012, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001013, 400066001013, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001014, 400066001014, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001015, 400066001015, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001016, 400066001016, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001017, 400066001017, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001018, 400066001018, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001019, 400066001019, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001020, 400066001020, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001021, 400066001021, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001022, 400066001022, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001023, 400066001023, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001024, 400066001024, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001025, 400066001025, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001026, 400066001026, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001027, 400066001027, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001028, 400066001028, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001029, 400066001029, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001030, 400066001030, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001031, 400066001031, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001032, 400066001032, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001033, 400066001033, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001034, 400066001034, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001035, 400066001035, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001036, 400066001036, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[1].columns[0].sections[1].items"  [Fasting Items]  -> menu_category_id 400066001002
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001037, 400066001, 400066001002, 10253, 'Finger Chips', 'finger chips', NULL, 'Fasting Items', 'veg', NULL, NULL, 'unverified'), -- #36
    (400066001038, 400066001, 400066001002, 10369, 'Kachori', 'kachori', NULL, 'Fasting Items', 'veg', NULL, NULL, 'unverified'), -- #37
    (400066001039, 400066001, 400066001002, 13704, 'Potato Toast', 'potato toast', NULL, 'Fasting Items', 'veg', NULL, NULL, 'unverified'), -- #38
    (400066001040, 400066001, 400066001002, 10722, 'Sabudana Wada', 'sabudana wada', NULL, 'Fasting Items', 'veg', NULL, NULL, 'unverified'); -- #39
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001037, 400066001037, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001038, 400066001038, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001039, 400066001039, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001040, 400066001040, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001037, 400066001037, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001038, 400066001038, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001039, 400066001039, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001040, 400066001040, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[1].columns[0].sections[2].items"  [Sandwiches & Grill]  -> menu_category_id 400066001003
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001041, 400066001, 400066001003, 23008, 'Bread Butter', 'bread butter', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #40
    (400066001042, 400066001, 400066001003, 10110, 'Chatni Sandwich', 'chatni sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #41
    (400066001043, 400066001, 400066001003, 13853, 'Toast Butter', 'toast butter', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #42
    (400066001044, 400066001, 400066001003, 23056, 'Jam Bread', 'jam bread', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'); -- #43
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001041, 400066001041, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001042, 400066001042, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001043, 400066001043, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001044, 400066001044, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001041, 400066001041, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001042, 400066001042, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001043, 400066001043, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001044, 400066001044, 72.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[1].columns[1].sections[0].items"  [Sandwiches & Grill]  -> menu_category_id 400066001003
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001045, 400066001, 400066001003, 13387, 'Jam Toast', 'jam toast', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #44
    (400066001046, 400066001, 400066001003, 10886, 'Veg. Sandwich', 'veg. sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #45
    (400066001047, 400066001, 400066001003, 10364, 'Jam Sandwich', 'jam sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #46
    (400066001048, 400066001, 400066001003, 10806, 'Toast Veg. Sandwich', 'toast veg. sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #47
    (400066001049, 400066001, 400066001003, 10805, 'Toast Chatni Sandwich', 'toast chatni sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #48
    (400066001050, 400066001, 400066001003, 10167, 'Cheese Sandwich', 'cheese sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #49
    (400066001051, 400066001, 400066001003, 10171, 'Cheese Toast Sandwich', 'cheese toast sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #50
    (400066001052, 400066001, 400066001003, 10857, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #51
    (400066001053, 400066001, 400066001003, 10175, 'Cheese Veg. Toast Sandwich', 'cheese veg. toast sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #52
    (400066001054, 400066001, 400066001003, 11018, 'Omlet Sandwich', 'omlet sandwich', NULL, 'Sandwiches & Grill', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), NULL, 'needs_review'), -- #53
    (400066001055, 400066001, 400066001003, 10307, 'Grilled Sandwich', 'grilled sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #54
    (400066001056, 400066001, 400066001003, 11019, 'Toast Omlet Sandwich', 'toast omlet sandwich', NULL, 'Sandwiches & Grill', 'egg', (SELECT protein_type_id FROM protein_type WHERE code = 'EGG'), NULL, 'needs_review'), -- #55
    (400066001057, 400066001, 400066001003, 10206, 'Club Sandwich', 'club sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #56
    (400066001058, 400066001, 400066001003, 10719, 'Russian Sandwich', 'russian sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #57
    (400066001059, 400066001, 400066001003, 10532, 'Only Cheese Grilled Sandwich', 'only cheese grilled sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #58
    (400066001060, 400066001, 400066001003, NULL, 'Veg. Cheese Grilled Sandwich', 'veg. cheese grilled sandwich', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'), -- #59
    (400066001061, 400066001, 400066001003, 10118, 'Cheese Chilli Toast', 'cheese chilli toast', NULL, 'Sandwiches & Grill', 'veg', NULL, NULL, 'unverified'); -- #-
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001045, 400066001045, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001046, 400066001046, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001047, 400066001047, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001048, 400066001048, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001049, 400066001049, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001050, 400066001050, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001051, 400066001051, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001052, 400066001052, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001053, 400066001053, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001054, 400066001054, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001055, 400066001055, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001056, 400066001056, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001057, 400066001057, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001058, 400066001058, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001059, 400066001059, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001060, 400066001060, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001061, 400066001061, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001045, 400066001045, 82.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001046, 400066001046, 78.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001047, 400066001047, 89.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001048, 400066001048, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001049, 400066001049, 78.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001050, 400066001050, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001051, 400066001051, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001052, 400066001052, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001053, 400066001053, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001054, 400066001054, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001055, 400066001055, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001056, 400066001056, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001057, 400066001057, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001058, 400066001058, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001059, 400066001059, 177.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001060, 400066001060, 177.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001061, 400066001061, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[1].columns[1].sections[1].items"  [Pizza]  -> menu_category_id 400066001004
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001062, 400066001, 400066001004, 60113, 'Pineapple Pizza', 'pineapple pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #60
    (400066001063, 400066001, 400066001004, 10884, 'Veg. Pizza', 'veg. pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #61
    (400066001064, 400066001, 400066001004, 10486, 'Mushroom Pizza', 'mushroom pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #62
    (400066001065, 400066001, 400066001004, 10048, 'Baby Corn Pizza', 'baby corn pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #63
    (400066001066, 400066001, 400066001004, 10164, 'Cheese Pizza', 'cheese pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #64
    (400066001067, 400066001, 400066001004, 10428, 'Masala Pizza', 'masala pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #65
    (400066001068, 400066001, 400066001004, 10306, 'Green Spl. Pizza', 'green spl. pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #69
    (400066001069, 400066001, 400066001004, 10471, 'Mushroom Babycorn Pizza', 'mushroom babycorn pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'), -- #70
    (400066001070, 400066001, 400066001004, 10157, 'Cheese Paneer Pizza', 'cheese paneer pizza', NULL, 'Pizza', 'veg', NULL, NULL, 'unverified'); -- #505
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001062, 400066001062, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001063, 400066001063, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001064, 400066001064, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001065, 400066001065, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001066, 400066001066, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001067, 400066001067, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001068, 400066001068, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001069, 400066001069, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001070, 400066001070, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001062, 400066001062, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001063, 400066001063, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001064, 400066001064, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001065, 400066001065, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001066, 400066001066, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001067, 400066001067, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001068, 400066001068, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001069, 400066001069, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001070, 400066001070, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[1].columns[1].sections[2].items"  [Hot Beverages]  -> menu_category_id 400066001005
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001071, 400066001, 400066001005, 50154, 'Tea', 'tea', NULL, 'Hot Beverages', 'veg', NULL, NULL, 'unverified'), -- #71
    (400066001072, 400066001, 400066001005, NULL, 'Tea (Without Sugar)', 'tea (without sugar)', NULL, 'Hot Beverages', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001073, 400066001, 400066001005, 13622, 'Nescafe', 'nescafe', NULL, 'Hot Beverages', 'veg', NULL, NULL, 'unverified'); -- #72
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001071, 400066001071, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001072, 400066001072, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001073, 400066001073, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001071, 400066001071, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001072, 400066001072, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001073, 400066001073, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[1].columns[1].sections[3].items"  [Pav Bhaji]  -> menu_category_id 400066001006
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001074, 400066001, 400066001006, 10658, 'Pav Bhaji', 'pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #73
    (400066001075, 400066001, 400066001006, 10811, 'Tomato Pav Bhaji', 'tomato pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #74
    (400066001076, 400066001, 400066001006, 10349, 'Jain Pav Bhaji', 'jain pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, TRUE, 'unverified'), -- #75
    (400066001077, 400066001, 400066001006, 10383, 'Khada Pav Bhaji', 'khada pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #76
    (400066001078, 400066001, 400066001006, 13632, 'Only Bhaji', 'only bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #77
    (400066001079, 400066001, 400066001006, 10426, 'Masala Pav (2 Pcs)', 'masala pav (2 pcs)', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #78
    (400066001080, 400066001, 400066001006, 10085, 'Butter Pav', 'butter pav', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'needs_review'), -- #79
    (400066001081, 400066001, 400066001006, 13832, 'Tawa Pulav', 'tawa pulav', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #80
    (400066001082, 400066001, 400066001006, 14199, 'Paneer Tawa Pulav', 'paneer tawa pulav', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #81
    (400066001083, 400066001, 400066001006, 13155, 'Cheese Tawa Pulav', 'cheese tawa pulav', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #82
    (400066001084, 400066001, 400066001006, 13606, 'Mushroom Tawa Pulav', 'mushroom tawa pulav', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001085, 400066001, 400066001006, 10770, 'Special Pav Bhaji', 'special pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #83
    (400066001086, 400066001, 400066001006, 10161, 'Cheese Pav Bhaji', 'cheese pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #84
    (400066001087, 400066001, 400066001006, 10336, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', NULL, 'Pav Bhaji', 'veg', NULL, TRUE, 'unverified'), -- #518
    (400066001088, 400066001, 400066001006, 13431, 'Khada Bhaji', 'khada bhaji', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'), -- #85
    (400066001089, 400066001, 400066001006, 13385, 'Jain Bhaji', 'jain bhaji', NULL, 'Pav Bhaji', 'veg', NULL, TRUE, 'unverified'), -- #86
    (400066001090, 400066001, 400066001006, 10794, 'Tawa Idli', 'tawa idli', NULL, 'Pav Bhaji', 'veg', NULL, NULL, 'unverified'); -- #506
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001074, 400066001074, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001075, 400066001075, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001076, 400066001076, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001077, 400066001077, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001078, 400066001078, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001079, 400066001079, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001080, 400066001080, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001081, 400066001081, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001082, 400066001082, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001083, 400066001083, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001084, 400066001084, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001085, 400066001085, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001086, 400066001086, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001087, 400066001087, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001088, 400066001088, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001089, 400066001089, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001090, 400066001090, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001074, 400066001074, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001075, 400066001075, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001076, 400066001076, 164.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001077, 400066001077, 164.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001078, 400066001078, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001079, 400066001079, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001080, 400066001080, 14.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'needs_review'),
    (400066001081, 400066001081, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001082, 400066001082, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001083, 400066001083, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001084, 400066001084, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001085, 400066001085, 206.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001086, 400066001086, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001087, 400066001087, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001088, 400066001088, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001089, 400066001089, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001090, 400066001090, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[2].columns[0].sections[0].items"  [Soups]  -> menu_category_id 400066001007
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001091, 400066001, 400066001007, 13865, 'Tomato Soup', 'tomato soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #87
    (400066001092, 400066001, 400066001007, 13340, 'Green Palak Soup', 'green palak soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #88
    (400066001093, 400066001, 400066001007, 60323, 'Vegetable Soup', 'vegetable soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #89
    (400066001094, 400066001, 400066001007, NULL, 'Veg. Sweetcorn Soup', 'veg. sweetcorn soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #90
    (400066001095, 400066001, 400066001007, 13371, 'Hot & Sour Soup', 'hot & sour soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #91
    (400066001096, 400066001, 400066001007, 60218, 'Veg. Manchow Soup', 'veg. manchow soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #92
    (400066001097, 400066001, 400066001007, NULL, 'Veg. Clear Soup', 'veg. clear soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #93
    (400066001098, 400066001, 400066001007, 60236, 'Veg. Noodle Soup', 'veg. noodle soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #94
    (400066001099, 400066001, 400066001007, NULL, 'Veg. Mushroom Soup', 'veg. mushroom soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #95
    (400066001100, 400066001, 400066001007, 13725, 'Royal Soup', 'royal soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #96
    (400066001101, 400066001, 400066001007, NULL, 'Hong Kong Soup', 'hong kong soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #97
    (400066001102, 400066001, 400066001007, NULL, 'Tumyum Soup', 'tumyum soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'), -- #98
    (400066001103, 400066001, 400066001007, NULL, 'Paneer Manchow Soup', 'paneer manchow soup', NULL, 'Soups', 'veg', NULL, NULL, 'unverified'); -- #99
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001091, 400066001091, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001092, 400066001092, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001093, 400066001093, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001094, 400066001094, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001095, 400066001095, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001096, 400066001096, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001097, 400066001097, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001098, 400066001098, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001099, 400066001099, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001100, 400066001100, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001101, 400066001101, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001102, 400066001102, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001103, 400066001103, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001091, 400066001091, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001092, 400066001092, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001093, 400066001093, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001094, 400066001094, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001095, 400066001095, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001096, 400066001096, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001097, 400066001097, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001098, 400066001098, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001099, 400066001099, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001100, 400066001100, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001101, 400066001101, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001102, 400066001102, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001103, 400066001103, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[2].columns[0].sections[1].items"  [Starter]  -> menu_category_id 400066001008
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001104, 400066001, 400066001008, NULL, 'Mix Veg. Pakoda', 'mix veg. pakoda', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #100
    (400066001105, 400066001, 400066001008, 10154, 'Cheese Pakoda', 'cheese pakoda', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #101
    (400066001106, 400066001, 400066001008, 10603, 'Paneer Pakoda', 'paneer pakoda', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #102
    (400066001107, 400066001, 400066001008, 10543, 'Paneer Achari Tikka', 'paneer achari tikka', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #103
    (400066001108, 400066001, 400066001008, 60424, 'Paneer Reshmi Tikka', 'paneer reshmi tikka', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #104
    (400066001109, 400066001, 400066001008, 10602, 'Paneer Pahadi Tikka', 'paneer pahadi tikka', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #105
    (400066001110, 400066001, 400066001008, 10589, 'Paneer Malai Tikka', 'paneer malai tikka', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #106
    (400066001111, 400066001, 400066001008, 10631, 'Paneer Tikka', 'paneer tikka', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #114
    (400066001112, 400066001, 400066001008, 10490, 'Mushroom Tikka', 'mushroom tikka', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #528
    (400066001113, 400066001, 400066001008, NULL, 'Veg. Seekh Kabab', 'veg. seekh kabab', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #107
    (400066001114, 400066001, 400066001008, NULL, 'Veg. Chilly Milly Kabab', 'veg. chilly milly kabab', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #108
    (400066001115, 400066001, 400066001008, NULL, 'Corn Tikki', 'corn tikki', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #109
    (400066001116, 400066001, 400066001008, NULL, 'Alu Tikki', 'alu tikki', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #110
    (400066001117, 400066001, 400066001008, 10890, 'Veg. Spring Roll', 'veg. spring roll', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #111
    (400066001118, 400066001, 400066001008, NULL, 'Veg. Cheese Spring Roll', 'veg. cheese spring roll', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #392
    (400066001119, 400066001, 400066001008, NULL, 'Veg. Paneer Spring Roll', 'veg. paneer spring roll', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #393
    (400066001120, 400066001, 400066001008, NULL, 'Veg. Hara Bara Kabab', 'veg. hara bara kabab', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #112
    (400066001121, 400066001, 400066001008, 10879, 'Veg. Lollypop', 'veg. lollypop', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #113
    (400066001122, 400066001, 400066001008, 10254, 'Flower Lollypop', 'flower lollypop', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #508
    (400066001123, 400066001, 400066001008, 10325, 'Idli Chilly', 'idli chilly', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #115
    (400066001124, 400066001, 400066001008, NULL, 'Schezwan Finger', 'schezwan finger', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #116
    (400066001125, 400066001, 400066001008, 10196, 'Chinese Bhel', 'chinese bhel', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #117
    (400066001126, 400066001, 400066001008, NULL, 'Veg. Gold Coin', 'veg. gold coin', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #118
    (400066001127, 400066001, 400066001008, 10871, 'Veg. Crispy', 'veg. crispy', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #119
    (400066001128, 400066001, 400066001008, 10563, 'Paneer Chilly', 'paneer chilly', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #120
    (400066001129, 400066001, 400066001008, 10476, 'Mushroom Chilly', 'mushroom chilly', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #121
    (400066001130, 400066001, 400066001008, 10481, 'Mushroom Manchurian', 'mushroom manchurian', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #122
    (400066001131, 400066001, 400066001008, 10540, 'Paneer 65', 'paneer 65', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #123
    (400066001132, 400066001, 400066001008, 14179, 'Paneer Schezwan', 'paneer schezwan', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #124
    (400066001133, 400066001, 400066001008, 10045, 'Baby Corn Manchurian', 'baby corn manchurian', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #125
    (400066001134, 400066001, 400066001008, 10591, 'Paneer Manchurian', 'paneer manchurian', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'), -- #126
    (400066001135, 400066001, 400066001008, 10571, 'Paneer Crispy', 'paneer crispy', NULL, 'Starter', 'veg', NULL, NULL, 'unverified'); -- #378
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001104, 400066001104, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001105, 400066001105, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001106, 400066001106, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001107, 400066001107, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001108, 400066001108, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001109, 400066001109, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001110, 400066001110, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001111, 400066001111, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001112, 400066001112, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001113, 400066001113, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001114, 400066001114, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001115, 400066001115, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001116, 400066001116, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001117, 400066001117, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001118, 400066001118, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001119, 400066001119, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001120, 400066001120, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001121, 400066001121, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001122, 400066001122, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001123, 400066001123, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001124, 400066001124, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001125, 400066001125, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001126, 400066001126, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001127, 400066001127, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001128, 400066001128, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001129, 400066001129, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001130, 400066001130, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001131, 400066001131, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001132, 400066001132, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001133, 400066001133, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001134, 400066001134, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001135, 400066001135, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001104, 400066001104, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001105, 400066001105, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001106, 400066001106, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001107, 400066001107, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001108, 400066001108, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001109, 400066001109, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001110, 400066001110, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001111, 400066001111, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001112, 400066001112, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001113, 400066001113, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001114, 400066001114, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001115, 400066001115, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001116, 400066001116, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001117, 400066001117, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001118, 400066001118, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001119, 400066001119, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001120, 400066001120, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001121, 400066001121, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001122, 400066001122, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001123, 400066001123, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001124, 400066001124, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001125, 400066001125, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001126, 400066001126, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001127, 400066001127, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001128, 400066001128, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001129, 400066001129, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001130, 400066001130, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001131, 400066001131, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001132, 400066001132, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001133, 400066001133, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001134, 400066001134, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001135, 400066001135, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[2].columns[1].sections[0].items"  [Punjabi Dishes]  -> menu_category_id 400066001009
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001136, 400066001, 400066001009, 13407, 'Kaju Makhanwala', 'kaju makhanwala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #127
    (400066001137, 400066001, 400066001009, 13337, 'Green''s Spl. Veg.', 'green''s spl. veg.', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #128
    (400066001138, 400066001, 400066001009, 13448, 'Koya Kaju', 'koya kaju', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #129
    (400066001139, 400066001, 400066001009, NULL, 'Veg. Masthi (Your Choice)', 'veg. masthi (your choice)', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #130
    (400066001140, 400066001, 400066001009, NULL, 'Hara Bara Kabab Masala', 'hara bara kabab masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #131
    (400066001141, 400066001, 400066001009, 10888, 'Veg. Seekh Kabab Masala', 'veg. seekh kabab masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #132
    (400066001142, 400066001, 400066001009, 60240, 'Veg. Patiyala', 'veg. patiyala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #133
    (400066001143, 400066001, 400066001009, 13994, 'Veg. Cheese Butter Masala', 'veg. cheese butter masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #134
    (400066001144, 400066001, 400066001009, 10867, 'Veg. Chilly Milly Masala', 'veg. chilly milly masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #135
    (400066001145, 400066001, 400066001009, 60182, 'Veg. Hariyali', 'veg. hariyali', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #136
    (400066001146, 400066001, 400066001009, NULL, 'Veg. Maharaja', 'veg. maharaja', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #137
    (400066001147, 400066001, 400066001009, 60196, 'Veg. Jaipuri', 'veg. jaipuri', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #138
    (400066001148, 400066001, 400066001009, 60245, 'Veg. Rajsthani', 'veg. rajsthani', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #509
    (400066001149, 400066001, 400066001009, NULL, 'Veg. Jalfrezi', 'veg. jalfrezi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #139
    (400066001150, 400066001, 400066001009, 10893, 'Veg. Tawa', 'veg. tawa', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #140
    (400066001151, 400066001, 400066001009, 60198, 'Veg. Kadai', 'veg. kadai', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #141
    (400066001152, 400066001, 400066001009, 60180, 'Veg. Handi', 'veg. handi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #142
    (400066001153, 400066001, 400066001009, 60205, 'Veg. Kheema', 'veg. kheema', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #143
    (400066001154, 400066001, 400066001009, 60194, 'Veg. Hyderabadi', 'veg. hyderabadi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #144
    (400066001155, 400066001, 400066001009, NULL, 'Veg. Kofta', 'veg. kofta', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #145
    (400066001156, 400066001, 400066001009, 60208, 'Veg. Kolhapuri', 'veg. kolhapuri', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #146
    (400066001157, 400066001, 400066001009, 60213, 'Veg. Makhanwala', 'veg. makhanwala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #147
    (400066001158, 400066001, 400066001009, 60202, 'Veg. Kashmiri', 'veg. kashmiri', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #148
    (400066001159, 400066001, 400066001009, 60228, 'Veg. Moglai', 'veg. moglai', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #149
    (400066001160, 400066001, 400066001009, 60210, 'Veg. Kurma', 'veg. kurma', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #150
    (400066001161, 400066001, 400066001009, 13486, 'Malai Kofta', 'malai kofta', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #151
    (400066001162, 400066001, 400066001009, NULL, 'Veg. Nawabi', 'veg. nawabi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #152
    (400066001163, 400066001, 400066001009, 13402, 'Kaju Curry', 'kaju curry', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #153
    (400066001164, 400066001, 400066001009, 13404, 'Kaju Handi', 'kaju handi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #154
    (400066001165, 400066001, 400066001009, 13262, 'Deevani Handi', 'deevani handi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #391
    (400066001166, 400066001, 400066001009, 13405, 'Kaju Kadai', 'kaju kadai', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #155
    (400066001167, 400066001, 400066001009, 13409, 'Kaju Masala', 'kaju masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #156
    (400066001168, 400066001, 400066001009, 14098, 'Paneer Kaju Masala', 'paneer kaju masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #384
    (400066001169, 400066001, 400066001009, 60229, 'Veg. Mumtaj', 'veg. mumtaj', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #157
    (400066001170, 400066001, 400066001009, NULL, 'Veg. Peshwari', 'veg. peshwari', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #158
    (400066001171, 400066001, 400066001009, 60163, 'Veg. Dilkhush', 'veg. dilkhush', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #159
    (400066001172, 400066001, 400066001009, NULL, 'Veg. Koliwada', 'veg. koliwada', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #160
    (400066001173, 400066001, 400066001009, 13969, 'Veg. Afghani', 'veg. afghani', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #161
    (400066001174, 400066001, 400066001009, NULL, 'Veg. Chop. Masala', 'veg. chop. masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #386
    (400066001175, 400066001, 400066001009, 13557, 'Mix Vegetable', 'mix vegetable', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #162
    (400066001176, 400066001, 400066001009, NULL, 'Navaratan Kurma', 'navaratan kurma', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #163
    (400066001177, 400066001, 400066001009, 13523, 'Methi Malai Mutter', 'methi malai mutter', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #164
    (400066001178, 400066001, 400066001009, 13615, 'Nargis Kofta', 'nargis kofta', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #165
    (400066001179, 400066001, 400066001009, 13417, 'Kashmiri Kofta', 'kashmiri kofta', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #166
    (400066001180, 400066001, 400066001009, 13143, 'Cheese Kofta', 'cheese kofta', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #167
    (400066001181, 400066001, 400066001009, 13134, 'Cheese Butter Masala', 'cheese butter masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #168
    (400066001182, 400066001, 400066001009, NULL, 'Paneer Lasuni', 'paneer lasuni', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'); -- #387
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001136, 400066001136, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001137, 400066001137, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001138, 400066001138, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001139, 400066001139, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001140, 400066001140, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001141, 400066001141, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001142, 400066001142, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001143, 400066001143, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001144, 400066001144, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001145, 400066001145, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001146, 400066001146, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001147, 400066001147, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001148, 400066001148, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001149, 400066001149, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001150, 400066001150, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001151, 400066001151, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001152, 400066001152, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001153, 400066001153, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001154, 400066001154, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001155, 400066001155, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001156, 400066001156, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001157, 400066001157, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001158, 400066001158, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001159, 400066001159, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001160, 400066001160, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001161, 400066001161, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001162, 400066001162, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001163, 400066001163, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001164, 400066001164, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001165, 400066001165, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001166, 400066001166, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001167, 400066001167, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001168, 400066001168, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001169, 400066001169, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001170, 400066001170, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001171, 400066001171, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001172, 400066001172, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001173, 400066001173, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001174, 400066001174, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001175, 400066001175, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001176, 400066001176, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001177, 400066001177, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001178, 400066001178, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001179, 400066001179, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001180, 400066001180, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001181, 400066001181, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001182, 400066001182, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001136, 400066001136, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001137, 400066001137, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001138, 400066001138, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001139, 400066001139, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001140, 400066001140, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001141, 400066001141, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001142, 400066001142, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001143, 400066001143, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001144, 400066001144, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001145, 400066001145, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001146, 400066001146, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001147, 400066001147, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001148, 400066001148, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001149, 400066001149, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001150, 400066001150, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001151, 400066001151, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001152, 400066001152, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001153, 400066001153, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001154, 400066001154, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001155, 400066001155, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001156, 400066001156, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001157, 400066001157, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001158, 400066001158, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001159, 400066001159, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001160, 400066001160, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001161, 400066001161, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001162, 400066001162, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001163, 400066001163, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001164, 400066001164, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001165, 400066001165, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001166, 400066001166, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001167, 400066001167, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001168, 400066001168, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001169, 400066001169, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001170, 400066001170, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001171, 400066001171, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001172, 400066001172, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001173, 400066001173, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001174, 400066001174, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001175, 400066001175, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001176, 400066001176, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001177, 400066001177, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001178, 400066001178, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001179, 400066001179, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001180, 400066001180, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001181, 400066001181, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001182, 400066001182, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[3].columns[0].sections[0].items"  [Punjabi Dishes - continuation]  -> menu_category_id 400066001009
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001183, 400066001, 400066001009, 14140, 'Paneer Methi', 'paneer methi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #388
    (400066001184, 400066001, 400066001009, NULL, 'Paneer Hydrabadi', 'paneer hydrabadi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #389
    (400066001185, 400066001, 400066001009, 14204, 'Paneer Tikka Masala', 'paneer tikka masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #169
    (400066001186, 400066001, 400066001009, NULL, 'Paneer Lajwab', 'paneer lajwab', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #170
    (400066001187, 400066001, 400066001009, 14104, 'Paneer Kofta', 'paneer kofta', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #171
    (400066001188, 400066001, 400066001009, 14097, 'Paneer Kadai', 'paneer kadai', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #172
    (400066001189, 400066001, 400066001009, 14044, 'Paneer Butter Masala', 'paneer butter masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #173
    (400066001190, 400066001, 400066001009, 14166, 'Paneer Pasanda', 'paneer pasanda', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #174
    (400066001191, 400066001, 400066001009, 14072, 'Paneer Handi', 'paneer handi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #175
    (400066001192, 400066001, 400066001009, 14035, 'Paneer Bhurji', 'paneer bhurji', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #176
    (400066001193, 400066001, 400066001009, 14129, 'Paneer Makhanwala', 'paneer makhanwala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #177
    (400066001194, 400066001, 400066001009, NULL, 'Paneer Kurma', 'paneer kurma', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #178
    (400066001195, 400066001, 400066001009, 14151, 'Paneer Mutter', 'paneer mutter', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #179
    (400066001196, 400066001, 400066001009, 14163, 'Paneer Palak', 'paneer palak', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #180
    (400066001197, 400066001, 400066001009, 14106, 'Paneer Kolhapuri', 'paneer kolhapuri', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #181
    (400066001198, 400066001, 400066001009, 10628, 'Paneer Tawa', 'paneer tawa', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #182
    (400066001199, 400066001, 400066001009, 14138, 'Paneer Masala', 'paneer masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #183
    (400066001200, 400066001, 400066001009, NULL, 'Paneer Maushroom Tawa Masala', 'paneer maushroom tawa masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #184
    (400066001201, 400066001, 400066001009, NULL, 'Paneer Patiyala', 'paneer patiyala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #185
    (400066001202, 400066001, 400066001009, NULL, 'Paneer Channa', 'paneer channa', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #186
    (400066001203, 400066001, 400066001009, 14108, 'Paneer Koliwada', 'paneer koliwada', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #187
    (400066001204, 400066001, 400066001009, NULL, 'Paneer Punjabi', 'paneer punjabi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #188
    (400066001205, 400066001, 400066001009, 14215, 'Shahi Paneer', 'shahi paneer', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #189
    (400066001206, 400066001, 400066001009, NULL, 'Corn Masala', 'corn masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #190
    (400066001207, 400066001, 400066001009, 13592, 'Mushroom Masala', 'mushroom masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #191
    (400066001208, 400066001, 400066001009, 13586, 'Mushroom Kadai', 'mushroom kadai', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #192
    (400066001209, 400066001, 400066001009, 13581, 'Mushroom Handi', 'mushroom handi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #193
    (400066001210, 400066001, 400066001009, NULL, 'Sarso Ka Saag', 'sarso ka saag', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #194
    (400066001211, 400066001, 400066001009, NULL, 'Mushroom Babycorn Masala', 'mushroom babycorn masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #195
    (400066001212, 400066001, 400066001009, NULL, 'Mushroom Lazawabi', 'mushroom lazawabi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #390
    (400066001213, 400066001, 400066001009, NULL, 'Dum Alu Kashmiri', 'dum alu kashmiri', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #196
    (400066001214, 400066001, 400066001009, NULL, 'Dum Alu Punjabi', 'dum alu punjabi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #197
    (400066001215, 400066001, 400066001009, 13342, 'Green Peas Masala', 'green peas masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #198
    (400066001216, 400066001, 400066001009, NULL, 'Tomato Bartha', 'tomato bartha', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #199
    (400066001217, 400066001, 400066001009, NULL, 'Baingan Bartha', 'baingan bartha', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #200
    (400066001218, 400066001, 400066001009, 13804, 'Stuffed Tomato', 'stuffed tomato', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #201
    (400066001219, 400066001, 400066001009, NULL, 'Stuffed Capsicum', 'stuffed capsicum', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #202
    (400066001220, 400066001, 400066001009, 13075, 'Bhendi Masala', 'bhendi masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #203
    (400066001221, 400066001, 400066001009, NULL, 'Bhendi Fry', 'bhendi fry', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #204
    (400066001222, 400066001, 400066001009, NULL, 'Alu Gobi', 'alu gobi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #205
    (400066001223, 400066001, 400066001009, NULL, 'Alu Methi', 'alu methi', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #206
    (400066001224, 400066001, 400066001009, NULL, 'Alu Palak', 'alu palak', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #207
    (400066001225, 400066001, 400066001009, 13647, 'Palak', 'palak', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #208
    (400066001226, 400066001, 400066001009, NULL, 'Alu Mutter', 'alu mutter', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #209
    (400066001227, 400066001, 400066001009, 13026, 'Alu Jeera', 'alu jeera', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #210
    (400066001228, 400066001, 400066001009, 13333, 'Gobi Masala', 'gobi masala', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #211
    (400066001229, 400066001, 400066001009, NULL, 'Methi Dry', 'methi dry', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #212
    (400066001230, 400066001, 400066001009, 60278, 'Veg. Tiranga', 'veg. tiranga', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'), -- #213
    (400066001231, 400066001, 400066001009, 13658, 'Palak Mutter', 'palak mutter', NULL, 'Punjabi Dishes', 'veg', NULL, NULL, 'unverified'); -- #214
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001183, 400066001183, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001184, 400066001184, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001185, 400066001185, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001186, 400066001186, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001187, 400066001187, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001188, 400066001188, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001189, 400066001189, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001190, 400066001190, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001191, 400066001191, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001192, 400066001192, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001193, 400066001193, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001194, 400066001194, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001195, 400066001195, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001196, 400066001196, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001197, 400066001197, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001198, 400066001198, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001199, 400066001199, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001200, 400066001200, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001201, 400066001201, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001202, 400066001202, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001203, 400066001203, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001204, 400066001204, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001205, 400066001205, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001206, 400066001206, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001207, 400066001207, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001208, 400066001208, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001209, 400066001209, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001210, 400066001210, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001211, 400066001211, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001212, 400066001212, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001213, 400066001213, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001214, 400066001214, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001215, 400066001215, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001216, 400066001216, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001217, 400066001217, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001218, 400066001218, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001219, 400066001219, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001220, 400066001220, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001221, 400066001221, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001222, 400066001222, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001223, 400066001223, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001224, 400066001224, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001225, 400066001225, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001226, 400066001226, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001227, 400066001227, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001228, 400066001228, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001229, 400066001229, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001230, 400066001230, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001231, 400066001231, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001183, 400066001183, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001184, 400066001184, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001185, 400066001185, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001186, 400066001186, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001187, 400066001187, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001188, 400066001188, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001189, 400066001189, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001190, 400066001190, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001191, 400066001191, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001192, 400066001192, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001193, 400066001193, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001194, 400066001194, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001195, 400066001195, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001196, 400066001196, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001197, 400066001197, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001198, 400066001198, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001199, 400066001199, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001200, 400066001200, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001201, 400066001201, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001202, 400066001202, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001203, 400066001203, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001204, 400066001204, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001205, 400066001205, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001206, 400066001206, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001207, 400066001207, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001208, 400066001208, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001209, 400066001209, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001210, 400066001210, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001211, 400066001211, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001212, 400066001212, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001213, 400066001213, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001214, 400066001214, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001215, 400066001215, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001216, 400066001216, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001217, 400066001217, 225.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001218, 400066001218, 225.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001219, 400066001219, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001220, 400066001220, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001221, 400066001221, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001222, 400066001222, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001223, 400066001223, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001224, 400066001224, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001225, 400066001225, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001226, 400066001226, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001227, 400066001227, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001228, 400066001228, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001229, 400066001229, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001230, 400066001230, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001231, 400066001231, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[3].columns[1].sections[0].items"  [Dal & Other Indian Dishes]  -> menu_category_id 400066001010
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001232, 400066001, 400066001010, 13657, 'Palak Methi', 'palak methi', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #215
    (400066001233, 400066001, 400066001010, 13654, 'Palak Lasooni', 'palak lasooni', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001234, 400066001, 400066001010, 13023, 'Alu Capsicum', 'alu capsicum', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #216
    (400066001235, 400066001, 400066001010, 13527, 'Methi Mutter Masala', 'methi mutter masala', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #217
    (400066001236, 400066001, 400066001010, NULL, 'Channa Masala', 'channa masala', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #218
    (400066001237, 400066001, 400066001010, 13226, 'Dahi Pakoda Curry', 'dahi pakoda curry', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #507
    (400066001238, 400066001, 400066001010, 13254, 'Dal Tadka', 'dal tadka', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #219
    (400066001239, 400066001, 400066001010, 13235, 'Dal Fry', 'dal fry', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #220
    (400066001240, 400066001, 400066001010, 13237, 'Dal Fry Butter', 'dal fry butter', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #221
    (400066001241, 400066001, 400066001010, 13520, 'Methi Dal Fry', 'methi dal fry', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #222
    (400066001242, 400066001, 400066001010, 13650, 'Palak Dal Fry', 'palak dal fry', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #223
    (400066001243, 400066001, 400066001010, 13437, 'Kolhapuri Dal Fry', 'kolhapuri dal fry', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #224
    (400066001244, 400066001, 400066001010, 13247, 'Dal Makhani', 'dal makhani', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #225
    (400066001245, 400066001, 400066001010, 13706, 'Punjabi Dal Fry', 'punjabi dal fry', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #226
    (400066001246, 400066001, 400066001010, 13233, 'Dal (Plain)', 'dal (plain)', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #227
    (400066001247, 400066001, 400066001010, 23040, 'Chole Bathora', 'chole bathora', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #228
    (400066001248, 400066001, 400066001010, NULL, 'Sambar Plate', 'sambar plate', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #229
    (400066001249, 400066001, 400066001010, 10027, 'Alu Sukka Bhaji', 'alu sukka bhaji', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #230
    (400066001250, 400066001, 400066001010, NULL, 'Cheese Patiala', 'cheese patiala', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001251, 400066001, 400066001010, NULL, 'Paneer Amrutsari', 'paneer amrutsari', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001252, 400066001, 400066001010, 10545, 'Paneer Angara', 'paneer angara', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001253, 400066001, 400066001010, 10756, 'Sev Tomato Masala', 'sev tomato masala', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001254, 400066001, 400066001010, 13918, 'Veg Khajana', 'veg khajana', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001255, 400066001, 400066001010, 13236, 'Dal Fry (Gujarati)', 'dal fry (gujarati)', NULL, 'Dal & Other Indian Dishes', 'veg', NULL, NULL, 'unverified'); -- #-
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001232, 400066001232, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001233, 400066001233, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001234, 400066001234, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001235, 400066001235, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001236, 400066001236, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001237, 400066001237, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001238, 400066001238, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001239, 400066001239, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001240, 400066001240, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001241, 400066001241, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001242, 400066001242, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001243, 400066001243, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001244, 400066001244, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001245, 400066001245, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001246, 400066001246, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001247, 400066001247, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001248, 400066001248, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001249, 400066001249, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001250, 400066001250, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001251, 400066001251, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001252, 400066001252, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001253, 400066001253, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001254, 400066001254, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001255, 400066001255, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001232, 400066001232, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001233, 400066001233, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001234, 400066001234, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001235, 400066001235, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001236, 400066001236, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001237, 400066001237, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001238, 400066001238, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001239, 400066001239, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001240, 400066001240, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001241, 400066001241, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001242, 400066001242, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001243, 400066001243, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001244, 400066001244, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001245, 400066001245, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001246, 400066001246, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001247, 400066001247, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001248, 400066001248, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001249, 400066001249, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001250, 400066001250, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001251, 400066001251, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001252, 400066001252, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001253, 400066001253, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001254, 400066001254, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001255, 400066001255, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[3].columns[1].sections[1].items"  [Roti (Tandoori)]  -> menu_category_id 400066001011
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001256, 400066001, 400066001011, 23094, 'Roti', 'roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #231
    (400066001257, 400066001, 400066001011, 23024, 'Butter Roti', 'butter roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #232
    (400066001258, 400066001, 400066001011, 23027, 'Chapati', 'chapati', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #233
    (400066001259, 400066001, 400066001011, 23013, 'Butter Chapati', 'butter chapati', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #234
    (400066001260, 400066001, 400066001011, NULL, 'Parotha', 'parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #235
    (400066001261, 400066001, 400066001011, NULL, 'Butter Parotha', 'butter parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #236
    (400066001262, 400066001, 400066001011, NULL, 'Nan', 'nan', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #237
    (400066001263, 400066001, 400066001011, 23061, 'Kulcha', 'kulcha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #238
    (400066001264, 400066001, 400066001011, NULL, 'Butter Nan', 'butter nan', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #239
    (400066001265, 400066001, 400066001011, 23017, 'Butter Kulcha', 'butter kulcha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #240
    (400066001266, 400066001, 400066001011, NULL, 'Cheese Garlic Nan', 'cheese garlic nan', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #501
    (400066001267, 400066001, 400066001011, NULL, 'Kashmiri Nan', 'kashmiri nan', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #502
    (400066001268, 400066001, 400066001011, 23035, 'Cheese Kulcha', 'cheese kulcha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #503
    (400066001269, 400066001, 400066001011, 23033, 'Cheese Garlic Kulcha', 'cheese garlic kulcha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #504
    (400066001270, 400066001, 400066001011, 23078, 'Methi Roti', 'methi roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #241
    (400066001271, 400066001, 400066001011, 23069, 'Makai Roti', 'makai roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #242
    (400066001272, 400066001, 400066001011, 23079, 'Missi Roti', 'missi roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #243
    (400066001273, 400066001, 400066001011, 23072, 'Masala Kulcha', 'masala kulcha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #244
    (400066001274, 400066001, 400066001011, NULL, 'Alu Parotha', 'alu parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #245
    (400066001275, 400066001, 400066001011, NULL, 'Stuff Parotha', 'stuff parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #246
    (400066001276, 400066001, 400066001011, 14196, 'Paneer Stuff Parotha', 'paneer stuff parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001277, 400066001, 400066001011, NULL, 'Methi Parotha', 'methi parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'); -- #247
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001256, 400066001256, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001257, 400066001257, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001258, 400066001258, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001259, 400066001259, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001260, 400066001260, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001261, 400066001261, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001262, 400066001262, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001263, 400066001263, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001264, 400066001264, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001265, 400066001265, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001266, 400066001266, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001267, 400066001267, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001268, 400066001268, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001269, 400066001269, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001270, 400066001270, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001271, 400066001271, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001272, 400066001272, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001273, 400066001273, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001274, 400066001274, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001275, 400066001275, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001276, 400066001276, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001277, 400066001277, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001256, 400066001256, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001257, 400066001257, 38.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001258, 400066001258, 14.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001259, 400066001259, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001260, 400066001260, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001261, 400066001261, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001262, 400066001262, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001263, 400066001263, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001264, 400066001264, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001265, 400066001265, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001266, 400066001266, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001267, 400066001267, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001268, 400066001268, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001269, 400066001269, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001270, 400066001270, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001271, 400066001271, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001272, 400066001272, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001273, 400066001273, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001274, 400066001274, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001275, 400066001275, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001276, 400066001276, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001277, 400066001277, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[4].columns[0].sections[0].items"  [Roti (Tandoori) - continuation]  -> menu_category_id 400066001011
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001278, 400066001, 400066001011, 23089, 'Pudina Parotha', 'pudina parotha', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #248
    (400066001279, 400066001, 400066001011, NULL, 'Cheese Nan', 'cheese nan', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #249
    (400066001280, 400066001, 400066001011, NULL, 'Garlic Nan', 'garlic nan', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #250
    (400066001281, 400066001, 400066001011, 23006, 'Basket Roti', 'basket roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #251
    (400066001282, 400066001, 400066001011, NULL, 'Bathura (S)', 'bathura (s)', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #252
    (400066001283, 400066001, 400066001011, 23091, 'Puri', 'puri', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #253
    (400066001284, 400066001, 400066001011, 23012, 'Butter Basket Roti', 'butter basket roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001285, 400066001, 400066001011, 23068, 'Maida Roti', 'maida roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001286, 400066001, 400066001011, 23019, 'Butter Maida Roti', 'butter maida roti', NULL, 'Roti (Tandoori)', 'veg', NULL, NULL, 'unverified'); -- #-
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001278, 400066001278, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001279, 400066001279, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001280, 400066001280, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001281, 400066001281, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001282, 400066001282, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001283, 400066001283, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001284, 400066001284, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001285, 400066001285, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001286, 400066001286, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001278, 400066001278, 68.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001279, 400066001279, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001280, 400066001280, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001281, 400066001281, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001282, 400066001282, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001283, 400066001283, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001284, 400066001284, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001285, 400066001285, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001286, 400066001286, 48.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[4].columns[0].sections[1].items"  [Rice, Biryani & Pulav]  -> menu_category_id 400066001012
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001287, 400066001, 400066001012, 13793, 'Steam Rice', 'steam rice', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #254/255 (merged: Steam Rice (Full) + Steam Rice (Half))
    (400066001288, 400066001, 400066001012, 13395, 'Jeera Rice', 'jeera rice', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #256
    (400066001289, 400066001, 400066001012, NULL, 'Veg. Pulav', 'veg. pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #257
    (400066001290, 400066001, 400066001012, 13349, 'Green Peas Pulav', 'green peas pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #258
    (400066001291, 400066001, 400066001012, 13419, 'Kashmiri Pulav', 'kashmiri pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #259
    (400066001292, 400066001, 400066001012, 13977, 'Veg. Biryani', 'veg. biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #260
    (400066001293, 400066001, 400066001012, NULL, 'Paneer Pulav', 'paneer pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #261
    (400066001294, 400066001, 400066001012, 13832, 'Tawa Pulav', 'tawa pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #262
    (400066001295, 400066001, 400066001012, 13570, 'Mushroom Biryani', 'mushroom biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #510
    (400066001296, 400066001, 400066001012, 14038, 'Paneer Biryani', 'paneer biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #263
    (400066001297, 400066001, 400066001012, 13356, 'Handi Biryani', 'handi biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #264
    (400066001298, 400066001, 400066001012, NULL, 'Hydrabadi Biryani', 'hydrabadi biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #265
    (400066001299, 400066001, 400066001012, NULL, 'Veg. Kolhapuri Biryani', 'veg. kolhapuri biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #266
    (400066001300, 400066001, 400066001012, NULL, 'Veg. Cheese Pulav', 'veg. cheese pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #267
    (400066001301, 400066001, 400066001012, 13133, 'Cheese Biryani', 'cheese biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #268
    (400066001302, 400066001, 400066001012, 13151, 'Cheese Pulav', 'cheese pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #269
    (400066001303, 400066001, 400066001012, 13993, 'Veg. Cheese Biryani', 'veg. cheese biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #270
    (400066001304, 400066001, 400066001012, 13242, 'Dal Khichdi', 'dal khichdi', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #271
    (400066001305, 400066001, 400066001012, 13243, 'Dal Khichdi Tadka', 'dal khichdi tadka', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #511
    (400066001306, 400066001, 400066001012, 13659, 'Palak Rice', 'palak rice', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #272
    (400066001307, 400066001, 400066001012, NULL, 'Curd Rice (Tadka)', 'curd rice (tadka)', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #273
    (400066001308, 400066001, 400066001012, 13351, 'Green Spl. Briyani', 'green spl. briyani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #274
    (400066001309, 400066001, 400066001012, 13279, 'Dum Biryani', 'dum biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #275
    (400066001310, 400066001, 400066001012, 14202, 'Paneer Tikka Biryani', 'paneer tikka biryani', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'), -- #515
    (400066001311, 400066001, 400066001012, 60226, 'Veg. Masala Pulav', 'veg. masala pulav', NULL, 'Rice, Biryani & Pulav', 'veg', NULL, NULL, 'unverified'); -- #66
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001287, 400066001287, 'Full', 'fixed', NULL, NULL, 1, TRUE),
    (400066001288, 400066001287, 'Half', 'fixed', NULL, NULL, 2, FALSE),
    (400066001289, 400066001288, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001290, 400066001289, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001291, 400066001290, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001292, 400066001291, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001293, 400066001292, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001294, 400066001293, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001295, 400066001294, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001296, 400066001295, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001297, 400066001296, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001298, 400066001297, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001299, 400066001298, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001300, 400066001299, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001301, 400066001300, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001302, 400066001301, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001303, 400066001302, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001304, 400066001303, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001305, 400066001304, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001306, 400066001305, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001307, 400066001306, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001308, 400066001307, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001309, 400066001308, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001310, 400066001309, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001311, 400066001310, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001312, 400066001311, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001287, 400066001287, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001288, 400066001288, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001289, 400066001289, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001290, 400066001290, 199.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001291, 400066001291, 199.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001292, 400066001292, 209.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001293, 400066001293, 209.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001294, 400066001294, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001295, 400066001295, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001296, 400066001296, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001297, 400066001297, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001298, 400066001298, 228.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001299, 400066001299, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001300, 400066001300, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001301, 400066001301, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001302, 400066001302, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001303, 400066001303, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001304, 400066001304, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001305, 400066001305, 205.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001306, 400066001306, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001307, 400066001307, 205.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001308, 400066001308, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001309, 400066001309, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001310, 400066001310, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001311, 400066001311, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001312, 400066001312, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[4].columns[0].sections[2].items"  [Chinese Dishes Vegetable]  -> menu_category_id 400066001013
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001312, 400066001, 400066001013, 10413, 'Manchurian With Garlic Sauce', 'manchurian with garlic sauce', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #276
    (400066001313, 400066001, 400066001013, NULL, 'Manchurian Veg.', 'manchurian veg.', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #277
    (400066001314, 400066001, 400066001013, 10481, 'Mushroom Manchurian', 'mushroom manchurian', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #278
    (400066001315, 400066001, 400066001013, 10591, 'Paneer Manchurian', 'paneer manchurian', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #279
    (400066001316, 400066001, 400066001013, 10045, 'Baby Corn Manchurian', 'baby corn manchurian', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #280
    (400066001317, 400066001, 400066001013, 10255, 'Flower Manchurian', 'flower manchurian', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #281
    (400066001318, 400066001, 400066001013, 60156, 'Veg. Chow Chow', 'veg. chow chow', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #282
    (400066001319, 400066001, 400066001013, 60268, 'Veg. Sweet & Sour', 'veg. sweet & sour', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'); -- #283
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001313, 400066001312, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001314, 400066001313, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001315, 400066001314, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001316, 400066001315, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001317, 400066001316, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001318, 400066001317, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001319, 400066001318, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001320, 400066001319, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001313, 400066001313, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001314, 400066001314, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001315, 400066001315, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001316, 400066001316, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001317, 400066001317, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001318, 400066001318, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001319, 400066001319, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001320, 400066001320, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[4].columns[1].sections[0].items"  [Chinese Dishes Vegetable - continuation]  -> menu_category_id 400066001013
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001320, 400066001, 400066001013, 60185, 'Veg. Hong Kong', 'veg. hong kong', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #284
    (400066001321, 400066001, 400066001013, 60155, 'Veg. Chopsuey', 'veg. chopsuey', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #285
    (400066001322, 400066001, 400066001013, 13028, 'American Chopsuey', 'american chopsuey', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #286
    (400066001323, 400066001, 400066001013, 60157, 'Veg. Chowmein', 'veg. chowmein', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #287
    (400066001324, 400066001, 400066001013, 14179, 'Paneer Schezwan', 'paneer schezwan', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #288
    (400066001325, 400066001, 400066001013, 10540, 'Paneer 65', 'paneer 65', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #289
    (400066001326, 400066001, 400066001013, 60248, 'Veg. Schezwan', 'veg. schezwan', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #290
    (400066001327, 400066001, 400066001013, 10555, 'Paneer Chilli', 'paneer chilli', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #291
    (400066001328, 400066001, 400066001013, 10849, 'Veg. 65', 'veg. 65', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'), -- #292
    (400066001329, 400066001, 400066001013, 10859, 'Veg. Chilli', 'veg. chilli', NULL, 'Chinese Dishes Vegetable', 'veg', NULL, NULL, 'unverified'); -- #293
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001321, 400066001320, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001322, 400066001321, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001323, 400066001322, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001324, 400066001323, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001325, 400066001324, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001326, 400066001325, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001327, 400066001326, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001328, 400066001327, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001329, 400066001328, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001330, 400066001329, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001321, 400066001321, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001322, 400066001322, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001323, 400066001323, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001324, 400066001324, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001325, 400066001325, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001326, 400066001326, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001327, 400066001327, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001328, 400066001328, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001329, 400066001329, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001330, 400066001330, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[4].columns[1].sections[1].items"  [Chinese Rice & Noodles]  -> menu_category_id 400066001014
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001330, 400066001, 400066001014, 60168, 'Veg. Fried Rice', 'veg. fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #294
    (400066001331, 400066001, 400066001014, 60249, 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #295
    (400066001332, 400066001, 400066001014, 60159, 'Veg. Combination Fried Rice', 'veg. combination fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #296
    (400066001333, 400066001, 400066001014, 60175, 'Veg. Ginger Garlic Fried Rice', 'veg. ginger garlic fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #297
    (400066001334, 400066001, 400066001014, 60186, 'Veg. Hong Kong Fried Rice', 'veg. hong kong fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #298
    (400066001335, 400066001, 400066001014, 60260, 'Veg. Singapore Fried Rice', 'veg. singapore fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #299
    (400066001336, 400066001, 400066001014, NULL, 'Veg. Tripple Schezwan Fried Rice', 'veg. tripple schezwan fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #300
    (400066001337, 400066001, 400066001014, 60231, 'Veg. Mushroom Fried Rice', 'veg. mushroom fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #301
    (400066001338, 400066001, 400066001014, NULL, 'Veg. Chinese Pulav', 'veg. chinese pulav', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #302
    (400066001339, 400066001, 400066001014, NULL, 'Veg. Fried Rice With Noodles', 'veg. fried rice with noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #303
    (400066001340, 400066001, 400066001014, 60179, 'Veg. Hakka Noodles', 'veg. hakka noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #304
    (400066001341, 400066001, 400066001014, NULL, 'Veg. Hong Kong Noodles', 'veg. hong kong noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #305
    (400066001342, 400066001, 400066001014, 60251, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #306
    (400066001343, 400066001, 400066001014, NULL, 'Veg. Manchow Noodles', 'veg. manchow noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #307
    (400066001344, 400066001, 400066001014, 60261, 'Veg. Singapore Noodles', 'veg. singapore noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #308
    (400066001345, 400066001, 400066001014, 60232, 'Veg. Mushroom Noodles', 'veg. mushroom noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #309
    (400066001346, 400066001, 400066001014, NULL, 'Veg. Mix Noodles', 'veg. mix noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #394
    (400066001347, 400066001, 400066001014, NULL, 'Veg. Mix Schezwan Noodles', 'veg. mix schezwan noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #395
    (400066001348, 400066001, 400066001014, NULL, 'Veg. Tripple Schezwan Noodles', 'veg. tripple schezwan noodles', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #396
    (400066001349, 400066001, 400066001014, 14181, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #397
    (400066001350, 400066001, 400066001014, NULL, 'Veg. Mix Fried Rice', 'veg. mix fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #398
    (400066001351, 400066001, 400066001014, NULL, 'Veg. Mix Schezwan Fried Rice', 'veg. mix schezwan fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #399
    (400066001352, 400066001, 400066001014, 60170, 'Veg. Fried Rice With Manchurian', 'veg. fried rice with manchurian', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'), -- #310
    (400066001353, 400066001, 400066001014, 14069, 'Paneer Fried Rice', 'paneer fried rice', NULL, 'Chinese Rice & Noodles', 'veg', NULL, NULL, 'unverified'); -- #311
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001331, 400066001330, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001332, 400066001331, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001333, 400066001332, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001334, 400066001333, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001335, 400066001334, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001336, 400066001335, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001337, 400066001336, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001338, 400066001337, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001339, 400066001338, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001340, 400066001339, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001341, 400066001340, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001342, 400066001341, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001343, 400066001342, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001344, 400066001343, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001345, 400066001344, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001346, 400066001345, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001347, 400066001346, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001348, 400066001347, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001349, 400066001348, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001350, 400066001349, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001351, 400066001350, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001352, 400066001351, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001353, 400066001352, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001354, 400066001353, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001331, 400066001331, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001332, 400066001332, 225.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001333, 400066001333, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001334, 400066001334, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001335, 400066001335, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001336, 400066001336, 245.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001337, 400066001337, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001338, 400066001338, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001339, 400066001339, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001340, 400066001340, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001341, 400066001341, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001342, 400066001342, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001343, 400066001343, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001344, 400066001344, 225.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001345, 400066001345, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001346, 400066001346, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001347, 400066001347, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001348, 400066001348, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001349, 400066001349, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001350, 400066001350, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001351, 400066001351, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001352, 400066001352, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001353, 400066001353, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001354, 400066001354, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[4].columns[1].sections[2].items"  [Salad / Raitha]  -> menu_category_id 400066001015
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001354, 400066001, 400066001015, 60061, 'Green Salad', 'green salad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #312
    (400066001355, 400066001, 400066001015, NULL, 'Veg. Raitha', 'veg. raitha', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #313
    (400066001356, 400066001, 400066001015, NULL, 'Bundi Raitha', 'bundi raitha', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #314
    (400066001357, 400066001, 400066001015, NULL, 'Pineapple Raitha', 'pineapple raitha', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #315
    (400066001358, 400066001, 400066001015, 13218, 'Curd', 'curd', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #316
    (400066001359, 400066001, 400066001015, 60095, 'Masala Papad', 'masala papad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #317
    (400066001360, 400066001, 400066001015, 60126, 'Roasted Papad', 'roasted papad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #318
    (400066001361, 400066001, 400066001015, 60042, 'Fried Papad', 'fried papad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #319
    (400066001362, 400066001, 400066001015, 60076, 'Khichiya Masala Papad', 'khichiya masala papad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001363, 400066001, 400066001015, 60078, 'Khichiya Roasted Papad', 'khichiya roasted papad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'), -- #-
    (400066001364, 400066001, 400066001015, NULL, 'Khichiya Fry Papad', 'khichiya fry papad', NULL, 'Salad / Raitha', 'veg', NULL, NULL, 'unverified'); -- #-
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001355, 400066001354, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001356, 400066001355, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001357, 400066001356, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001358, 400066001357, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001359, 400066001358, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001360, 400066001359, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001361, 400066001360, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001362, 400066001361, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001363, 400066001362, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001364, 400066001363, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001365, 400066001364, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001355, 400066001355, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001356, 400066001356, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001357, 400066001357, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001358, 400066001358, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001359, 400066001359, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001360, 400066001360, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001361, 400066001361, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001362, 400066001362, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001363, 400066001363, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001364, 400066001364, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001365, 400066001365, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[0].sections[0].items"  [Cold Drinks]  -> menu_category_id 400066001016
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001365, 400066001, 400066001016, 50143, 'Soft Drinks', 'soft drinks', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #320
    (400066001366, 400066001, 400066001016, 50142, 'Soda', 'soda', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #321
    (400066001367, 400066001, 400066001016, 50061, 'Fresh Lime Soda', 'fresh lime soda', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #322
    (400066001368, 400066001, 400066001016, 50062, 'Fresh Lime Water', 'fresh lime water', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #323
    (400066001369, 400066001, 400066001016, 50111, 'Mineral Water (1000 Ml)', 'mineral water (1000 ml)', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #324
    (400066001370, 400066001, 400066001016, NULL, 'Cold Drinks', 'cold drinks', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #380/380 (merged: Cold Drinks (200 Ml) + Cold Drinks (500 Ml))
    (400066001371, 400066001, 400066001016, NULL, 'Bisleri (500 Ml)', 'bisleri (500 ml)', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #381
    (400066001372, 400066001, 400066001016, 13717, 'Red Bull', 'red bull', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'unverified'), -- #382
    (400066001373, 400066001, 400066001016, NULL, 'Frooti', 'frooti', NULL, 'Cold Drinks', 'veg', NULL, NULL, 'needs_review'); -- #383
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001366, 400066001365, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001367, 400066001366, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001368, 400066001367, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001369, 400066001368, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001370, 400066001369, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001371, 400066001370, '200 ml', 'fixed', 200, 'ml', 1, TRUE),
    (400066001372, 400066001370, '500 ml', 'fixed', 500, 'ml', 2, FALSE),
    (400066001373, 400066001371, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001374, 400066001372, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001375, 400066001373, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001366, 400066001366, 33.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001367, 400066001367, 28.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001368, 400066001368, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001369, 400066001369, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001370, 400066001370, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001371, 400066001371, 28.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001372, 400066001372, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001373, 400066001373, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001374, 400066001374, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[0].sections[1].items"  [Lassi]  -> menu_category_id 400066001017
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001374, 400066001, 400066001017, 50082, 'Kesar Lassi', 'kesar lassi', NULL, 'Lassi', 'veg', NULL, NULL, 'unverified'), -- #325
    (400066001375, 400066001, 400066001017, 50102, 'Mango Lassi', 'mango lassi', NULL, 'Lassi', 'veg', NULL, NULL, 'unverified'), -- #326
    (400066001376, 400066001, 400066001017, 50152, 'Sweet Lassi', 'sweet lassi', NULL, 'Lassi', 'veg', NULL, NULL, 'unverified'), -- #327
    (400066001377, 400066001, 400066001017, 50136, 'Salted Lassi', 'salted lassi', NULL, 'Lassi', 'veg', NULL, NULL, 'unverified'), -- #328
    (400066001378, 400066001, 400066001017, NULL, 'Butter Milk (Chas)', 'butter milk (chas)', NULL, 'Lassi', 'veg', NULL, NULL, 'unverified'), -- #329
    (400066001379, 400066001, 400066001017, 60062, 'Gulab Jamun', 'gulab jamun', NULL, 'Lassi', 'veg', NULL, NULL, 'needs_review'); -- #523
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001376, 400066001374, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001377, 400066001375, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001378, 400066001376, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001379, 400066001377, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001380, 400066001378, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001381, 400066001379, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001375, 400066001376, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001376, 400066001377, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001377, 400066001378, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001378, 400066001379, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001379, 400066001380, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001380, 400066001381, 33.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[0].sections[2].items"  [Juices]  -> menu_category_id 400066001018
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001380, 400066001, 400066001018, NULL, 'Mosambi (Sweet Lime)', 'mosambi (sweet lime)', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #330
    (400066001381, 400066001, 400066001018, 60104, 'Orange', 'orange', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #331
    (400066001382, 400066001, 400066001018, 60110, 'Pineapple', 'pineapple', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #332
    (400066001383, 400066001, 400066001018, 60006, 'Apple', 'apple', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #333
    (400066001384, 400066001, 400066001018, 60058, 'Grapes', 'grapes', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #334
    (400066001385, 400066001, 400066001018, 13316, 'Ganga Jamuna', 'ganga jamuna', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #335
    (400066001386, 400066001, 400066001018, 13507, 'Maramari', 'maramari', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #336
    (400066001387, 400066001, 400066001018, 53001, 'Cocktail', 'cocktail', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #337
    (400066001388, 400066001, 400066001018, NULL, 'Water Melon', 'water melon', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'), -- #338
    (400066001389, 400066001, 400066001018, 60086, 'Mango (Seasonal)', 'mango (seasonal)', NULL, 'Juices', 'veg', NULL, NULL, 'unverified'); -- #339
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001382, 400066001380, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001383, 400066001381, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001384, 400066001382, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001385, 400066001383, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001386, 400066001384, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001387, 400066001385, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001388, 400066001386, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001389, 400066001387, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001390, 400066001388, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001391, 400066001389, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001381, 400066001382, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001382, 400066001383, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001383, 400066001384, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001384, 400066001385, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001385, 400066001386, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001386, 400066001387, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001387, 400066001388, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001388, 400066001389, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001389, 400066001390, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001390, 400066001391, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[0].sections[3].items"  [Milk Shakes]  -> menu_category_id 400066001019
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001390, 400066001, 400066001019, 50034, 'Chikku Milk Shake', 'chikku milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #340
    (400066001391, 400066001, 400066001019, 50013, 'Banana Milk Shake', 'banana milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #385
    (400066001392, 400066001, 400066001019, 50008, 'Apple Milk Shake', 'apple milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #341
    (400066001393, 400066001, 400066001019, 60428, 'Pineapple Milk Shake', 'pineapple milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #386
    (400066001394, 400066001, 400066001019, 50036, 'Chocolate Milk Shake', 'chocolate milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #342
    (400066001395, 400066001, 400066001019, NULL, 'Rose Milk Shake', 'rose milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #343
    (400066001396, 400066001, 400066001019, 50083, 'Kesar Milk Shake', 'kesar milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #344
    (400066001397, 400066001, 400066001019, 50104, 'Mango Milk Shake', 'mango milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #345
    (400066001398, 400066001, 400066001019, 50162, 'Vanilla Milk Shake', 'vanilla milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #346
    (400066001399, 400066001, 400066001019, 53003, 'Cocktail Milk Shake', 'cocktail milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'); -- #347
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001392, 400066001390, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001393, 400066001391, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001394, 400066001392, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001395, 400066001393, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001396, 400066001394, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001397, 400066001395, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001398, 400066001396, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001399, 400066001397, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001400, 400066001398, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001401, 400066001399, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001391, 400066001392, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001392, 400066001393, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001393, 400066001394, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001394, 400066001395, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001395, 400066001396, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001396, 400066001397, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001397, 400066001398, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001398, 400066001399, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001399, 400066001400, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001400, 400066001401, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[1].sections[0].items"  [Milk Shakes - continuation]  -> menu_category_id 400066001019
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001400, 400066001, 400066001019, 50137, 'Seetaphal Milk Shake (Seasonal)', 'seetaphal milk shake (seasonal)', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #348
    (400066001401, 400066001, 400066001019, NULL, 'Strawberry Milk Shake (Seasonal)', 'strawberry milk shake (seasonal)', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #349
    (400066001402, 400066001, 400066001019, 50040, 'Cold Coffee', 'cold coffee', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'), -- #350
    (400066001403, 400066001, 400066001019, 50053, 'Dry Fruit Milk Shake', 'dry fruit milk shake', NULL, 'Milk Shakes', 'veg', NULL, NULL, 'unverified'); -- #351
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001402, 400066001400, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001403, 400066001401, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001404, 400066001402, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001405, 400066001403, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001401, 400066001402, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001402, 400066001403, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001403, 400066001404, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001404, 400066001405, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[1].sections[1].items"  [Fruit Special]  -> menu_category_id 400066001020
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001404, 400066001, 400066001020, 60048, 'Fruit Salad', 'fruit salad', NULL, 'Fruit Special', 'veg', NULL, NULL, 'unverified'), -- #352
    (400066001405, 400066001, 400066001020, 60072, 'Jelly Plain', 'jelly plain', NULL, 'Fruit Special', 'veg', NULL, NULL, 'unverified'), -- #353
    (400066001406, 400066001, 400066001020, 60050, 'Fruit Salad Jelly', 'fruit salad jelly', NULL, 'Fruit Special', 'veg', NULL, NULL, 'unverified'); -- #354
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001406, 400066001404, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001407, 400066001405, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001408, 400066001406, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001405, 400066001406, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001406, 400066001407, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001407, 400066001408, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[1].sections[2].items"  [Falooda]  -> menu_category_id 400066001021
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001407, 400066001, 400066001021, 50069, 'Green Special Falooda', 'green special falooda', NULL, 'Falooda', 'veg', NULL, NULL, 'unverified'), -- #355
    (400066001408, 400066001, 400066001021, 50089, 'Kulfi Falooda', 'kulfi falooda', NULL, 'Falooda', 'veg', NULL, NULL, 'unverified'), -- #356
    (400066001409, 400066001, 400066001021, 50081, 'Kesar Falooda', 'kesar falooda', NULL, 'Falooda', 'veg', NULL, NULL, 'unverified'), -- #357
    (400066001410, 400066001, 400066001021, 50133, 'Royal Falooda', 'royal falooda', NULL, 'Falooda', 'veg', NULL, NULL, 'unverified'), -- #358
    (400066001411, 400066001, 400066001021, 13314, 'Gadbad Special', 'gadbad special', NULL, 'Falooda', 'veg', NULL, NULL, 'unverified'); -- #359
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001409, 400066001407, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001410, 400066001408, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001411, 400066001409, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001412, 400066001410, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001413, 400066001411, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001408, 400066001409, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001409, 400066001410, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001410, 400066001411, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001411, 400066001412, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001412, 400066001413, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[1].sections[3].items"  [Mocktails]  -> menu_category_id 400066001022
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001412, 400066001, 400066001022, 60047, 'Fruit Punch', 'fruit punch', 'Assorted Fruit Juices With Vanilla Ice Cream & Grenedine Syrup', 'Mocktails', 'veg', NULL, NULL, 'unverified'), -- #360
    (400066001413, 400066001, 400066001022, 60339, 'Yadeen', 'yadeen', 'Pineapple Juice, Vanilla Ice Cream & Rose Syrup', 'Mocktails', 'veg', NULL, NULL, 'unverified'), -- #361
    (400066001414, 400066001, 400066001022, 13338, 'Green Cooler', 'green cooler', 'Limca, Khus Syrup & Honey Seeds Sabja', 'Mocktails', 'veg', NULL, NULL, 'unverified'), -- #362
    (400066001415, 400066001, 400066001022, 13285, 'Exotica', 'exotica', 'Mango, Juice, Soda & Khus Syrup', 'Mocktails', 'veg', NULL, NULL, 'unverified'); -- #363
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001414, 400066001412, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001415, 400066001413, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001416, 400066001414, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001417, 400066001415, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001413, 400066001414, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001414, 400066001415, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001415, 400066001416, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001416, 400066001417, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[5].columns[1].sections[4].items"  [Ice Cream Regular Cups / Candy]  -> menu_category_id 400066001023
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001416, 400066001, 400066001023, 40035, 'Vanilla', 'vanilla', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #364/365 (merged: Vanilla (Small) + Vanilla (Big))
    (400066001417, 400066001, 400066001023, 60143, 'Strawberry', 'strawberry', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #366
    (400066001418, 400066001, 400066001023, 40005, 'Butter Scotch', 'butter scotch', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #367
    (400066001419, 400066001, 400066001023, 13187, 'Classic Casata', 'classic casata', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #368
    (400066001420, 400066001, 400066001023, NULL, 'Kesar Pista', 'kesar pista', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #369
    (400066001421, 400066001, 400066001023, 13176, 'Chocolate Feast', 'chocolate feast', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #370
    (400066001422, 400066001, 400066001023, 40010, 'Chocolate Cone', 'chocolate cone', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #371
    (400066001423, 400066001, 400066001023, 40006, 'Butter Scotch Cone', 'butter scotch cone', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #372
    (400066001424, 400066001, 400066001023, 40008, 'Choco Bar', 'choco bar', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #373
    (400066001425, 400066001, 400066001023, 60090, 'Mango Duet', 'mango duet', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #374
    (400066001426, 400066001, 400066001023, 13715, 'Raspberry Duet', 'raspberry duet', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #375
    (400066001427, 400066001, 400066001023, 40023, 'Malai Kulfi', 'malai kulfi', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'), -- #376
    (400066001428, 400066001, 400066001023, 40020, 'Kesar Kulfi', 'kesar kulfi', NULL, 'Ice Cream Regular Cups / Candy', 'veg', NULL, NULL, 'unverified'); -- #377
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001418, 400066001416, 'Small', 'fixed', NULL, NULL, 1, TRUE),
    (400066001419, 400066001416, 'Big', 'fixed', NULL, NULL, 2, FALSE),
    (400066001420, 400066001417, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001421, 400066001418, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001422, 400066001419, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001423, 400066001420, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001424, 400066001421, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001425, 400066001422, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001426, 400066001423, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001427, 400066001424, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001428, 400066001425, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001429, 400066001426, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001430, 400066001427, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (400066001431, 400066001428, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001417, 400066001418, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001418, 400066001419, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001419, 400066001420, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001420, 400066001421, 37.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001421, 400066001422, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001422, 400066001423, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001423, 400066001424, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001424, 400066001425, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001425, 400066001426, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001426, 400066001427, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001427, 400066001428, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001428, 400066001429, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001429, 400066001430, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified'),
    (400066001430, 400066001431, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- Source: JSON, "pages[6].content[0].items"  [Punjabi Thali]  -> menu_category_id 400066001024
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name, description,
    raw_category_text, food_classification_code, protein_type_id, is_jain, verification_status_code
) VALUES
    (400066001429, 400066001, 400066001024, NULL, 'Punjabi Thali', 'punjabi thali', NULL, 'Punjabi Thali', 'veg', NULL, NULL, 'unverified'); -- #-
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default) VALUES
    (400066001432, 400066001429, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) VALUES
    (400066001431, 400066001432, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400066001, 'unverified');

-- ---------------------------------------------------------------------------
-- 6. Source links (menu_item_source / menu_item_price_source)
-- ---------------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) VALUES
    (400066001001, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001002, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001003, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001004, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001005, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001006, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001007, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001008, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001009, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001010, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001011, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001012, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001013, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001014, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001015, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001016, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001017, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001018, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001019, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001020, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001021, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001022, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001023, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001024, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001025, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001026, 400066001, 400066001901, 0.90, 'needs_review'),
    (400066001027, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001028, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001029, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001030, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001031, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001032, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001033, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001034, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001035, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001036, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001037, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001038, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001039, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001040, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001041, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001042, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001043, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001044, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001045, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001046, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001047, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001048, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001049, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001050, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001051, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001052, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001053, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001054, 400066001, 400066001901, 0.90, 'needs_review'),
    (400066001055, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001056, 400066001, 400066001901, 0.90, 'needs_review'),
    (400066001057, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001058, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001059, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001060, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001061, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001062, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001063, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001064, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001065, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001066, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001067, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001068, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001069, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001070, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001071, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001072, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001073, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001074, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001075, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001076, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001077, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001078, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001079, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001080, 400066001, 400066001901, 0.95, 'needs_review'),
    (400066001081, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001082, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001083, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001084, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001085, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001086, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001087, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001088, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001089, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001090, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001091, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001092, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001093, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001094, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001095, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001096, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001097, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001098, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001099, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001100, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001101, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001102, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001103, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001104, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001105, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001106, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001107, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001108, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001109, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001110, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001111, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001112, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001113, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001114, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001115, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001116, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001117, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001118, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001119, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001120, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001121, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001122, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001123, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001124, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001125, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001126, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001127, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001128, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001129, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001130, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001131, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001132, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001133, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001134, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001135, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001136, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001137, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001138, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001139, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001140, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001141, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001142, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001143, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001144, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001145, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001146, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001147, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001148, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001149, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001150, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001151, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001152, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001153, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001154, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001155, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001156, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001157, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001158, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001159, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001160, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001161, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001162, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001163, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001164, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001165, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001166, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001167, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001168, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001169, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001170, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001171, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001172, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001173, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001174, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001175, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001176, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001177, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001178, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001179, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001180, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001181, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001182, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001183, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001184, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001185, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001186, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001187, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001188, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001189, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001190, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001191, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001192, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001193, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001194, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001195, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001196, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001197, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001198, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001199, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001200, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001201, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001202, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001203, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001204, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001205, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001206, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001207, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001208, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001209, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001210, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001211, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001212, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001213, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001214, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001215, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001216, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001217, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001218, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001219, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001220, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001221, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001222, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001223, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001224, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001225, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001226, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001227, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001228, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001229, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001230, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001231, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001232, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001233, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001234, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001235, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001236, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001237, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001238, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001239, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001240, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001241, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001242, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001243, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001244, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001245, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001246, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001247, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001248, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001249, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001250, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001251, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001252, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001253, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001254, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001255, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001256, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001257, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001258, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001259, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001260, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001261, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001262, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001263, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001264, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001265, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001266, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001267, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001268, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001269, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001270, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001271, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001272, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001273, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001274, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001275, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001276, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001277, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001278, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001279, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001280, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001281, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001282, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001283, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001284, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001285, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001286, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001287, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001288, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001289, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001290, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001291, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001292, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001293, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001294, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001295, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001296, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001297, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001298, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001299, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001300, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001301, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001302, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001303, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001304, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001305, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001306, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001307, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001308, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001309, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001310, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001311, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001312, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001313, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001314, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001315, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001316, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001317, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001318, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001319, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001320, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001321, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001322, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001323, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001324, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001325, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001326, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001327, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001328, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001329, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001330, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001331, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001332, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001333, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001334, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001335, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001336, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001337, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001338, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001339, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001340, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001341, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001342, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001343, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001344, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001345, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001346, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001347, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001348, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001349, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001350, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001351, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001352, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001353, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001354, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001355, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001356, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001357, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001358, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001359, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001360, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001361, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001362, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001363, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001364, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001365, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001366, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001367, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001368, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001369, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001370, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001371, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001372, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001373, 400066001, 400066001901, 0.90, 'needs_review'),
    (400066001374, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001375, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001376, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001377, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001378, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001379, 400066001, 400066001901, 0.85, 'needs_review'),
    (400066001380, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001381, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001382, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001383, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001384, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001385, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001386, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001387, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001388, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001389, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001390, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001391, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001392, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001393, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001394, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001395, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001396, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001397, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001398, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001399, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001400, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001401, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001402, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001403, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001404, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001405, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001406, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001407, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001408, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001409, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001410, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001411, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001412, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001413, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001414, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001415, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001416, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001417, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001418, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001419, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001420, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001421, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001422, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001423, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001424, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001425, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001426, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001427, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001428, 400066001, 400066001901, 0.95, 'unverified'),
    (400066001429, 400066001, 400066001901, 0.95, 'unverified');

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence) VALUES
    (400066001001, 400066001, 400066001901, 0.95),
    (400066001002, 400066001, 400066001901, 0.95),
    (400066001003, 400066001, 400066001901, 0.95),
    (400066001004, 400066001, 400066001901, 0.95),
    (400066001005, 400066001, 400066001901, 0.95),
    (400066001006, 400066001, 400066001901, 0.95),
    (400066001007, 400066001, 400066001901, 0.95),
    (400066001008, 400066001, 400066001901, 0.95),
    (400066001009, 400066001, 400066001901, 0.95),
    (400066001010, 400066001, 400066001901, 0.95),
    (400066001011, 400066001, 400066001901, 0.95),
    (400066001012, 400066001, 400066001901, 0.95),
    (400066001013, 400066001, 400066001901, 0.95),
    (400066001014, 400066001, 400066001901, 0.95),
    (400066001015, 400066001, 400066001901, 0.95),
    (400066001016, 400066001, 400066001901, 0.95),
    (400066001017, 400066001, 400066001901, 0.95),
    (400066001018, 400066001, 400066001901, 0.95),
    (400066001019, 400066001, 400066001901, 0.95),
    (400066001020, 400066001, 400066001901, 0.95),
    (400066001021, 400066001, 400066001901, 0.95),
    (400066001022, 400066001, 400066001901, 0.95),
    (400066001023, 400066001, 400066001901, 0.95),
    (400066001024, 400066001, 400066001901, 0.95),
    (400066001025, 400066001, 400066001901, 0.95),
    (400066001026, 400066001, 400066001901, 0.95),
    (400066001027, 400066001, 400066001901, 0.95),
    (400066001028, 400066001, 400066001901, 0.95),
    (400066001029, 400066001, 400066001901, 0.95),
    (400066001030, 400066001, 400066001901, 0.95),
    (400066001031, 400066001, 400066001901, 0.95),
    (400066001032, 400066001, 400066001901, 0.95),
    (400066001033, 400066001, 400066001901, 0.95),
    (400066001034, 400066001, 400066001901, 0.95),
    (400066001035, 400066001, 400066001901, 0.95),
    (400066001036, 400066001, 400066001901, 0.95),
    (400066001037, 400066001, 400066001901, 0.95),
    (400066001038, 400066001, 400066001901, 0.95),
    (400066001039, 400066001, 400066001901, 0.95),
    (400066001040, 400066001, 400066001901, 0.95),
    (400066001041, 400066001, 400066001901, 0.95),
    (400066001042, 400066001, 400066001901, 0.95),
    (400066001043, 400066001, 400066001901, 0.95),
    (400066001044, 400066001, 400066001901, 0.95),
    (400066001045, 400066001, 400066001901, 0.95),
    (400066001046, 400066001, 400066001901, 0.95),
    (400066001047, 400066001, 400066001901, 0.95),
    (400066001048, 400066001, 400066001901, 0.95),
    (400066001049, 400066001, 400066001901, 0.95),
    (400066001050, 400066001, 400066001901, 0.95),
    (400066001051, 400066001, 400066001901, 0.95),
    (400066001052, 400066001, 400066001901, 0.95),
    (400066001053, 400066001, 400066001901, 0.95),
    (400066001054, 400066001, 400066001901, 0.95),
    (400066001055, 400066001, 400066001901, 0.95),
    (400066001056, 400066001, 400066001901, 0.95),
    (400066001057, 400066001, 400066001901, 0.95),
    (400066001058, 400066001, 400066001901, 0.95),
    (400066001059, 400066001, 400066001901, 0.95),
    (400066001060, 400066001, 400066001901, 0.95),
    (400066001061, 400066001, 400066001901, 0.95),
    (400066001062, 400066001, 400066001901, 0.95),
    (400066001063, 400066001, 400066001901, 0.95),
    (400066001064, 400066001, 400066001901, 0.95),
    (400066001065, 400066001, 400066001901, 0.95),
    (400066001066, 400066001, 400066001901, 0.95),
    (400066001067, 400066001, 400066001901, 0.95),
    (400066001068, 400066001, 400066001901, 0.95),
    (400066001069, 400066001, 400066001901, 0.95),
    (400066001070, 400066001, 400066001901, 0.95),
    (400066001071, 400066001, 400066001901, 0.95),
    (400066001072, 400066001, 400066001901, 0.95),
    (400066001073, 400066001, 400066001901, 0.95),
    (400066001074, 400066001, 400066001901, 0.95),
    (400066001075, 400066001, 400066001901, 0.95),
    (400066001076, 400066001, 400066001901, 0.95),
    (400066001077, 400066001, 400066001901, 0.95),
    (400066001078, 400066001, 400066001901, 0.95),
    (400066001079, 400066001, 400066001901, 0.95),
    (400066001080, 400066001, 400066001901, 0.70),
    (400066001081, 400066001, 400066001901, 0.95),
    (400066001082, 400066001, 400066001901, 0.95),
    (400066001083, 400066001, 400066001901, 0.95),
    (400066001084, 400066001, 400066001901, 0.95),
    (400066001085, 400066001, 400066001901, 0.95),
    (400066001086, 400066001, 400066001901, 0.95),
    (400066001087, 400066001, 400066001901, 0.95),
    (400066001088, 400066001, 400066001901, 0.95),
    (400066001089, 400066001, 400066001901, 0.95),
    (400066001090, 400066001, 400066001901, 0.95),
    (400066001091, 400066001, 400066001901, 0.95),
    (400066001092, 400066001, 400066001901, 0.95),
    (400066001093, 400066001, 400066001901, 0.95),
    (400066001094, 400066001, 400066001901, 0.95),
    (400066001095, 400066001, 400066001901, 0.95),
    (400066001096, 400066001, 400066001901, 0.95),
    (400066001097, 400066001, 400066001901, 0.95),
    (400066001098, 400066001, 400066001901, 0.95),
    (400066001099, 400066001, 400066001901, 0.95),
    (400066001100, 400066001, 400066001901, 0.95),
    (400066001101, 400066001, 400066001901, 0.95),
    (400066001102, 400066001, 400066001901, 0.95),
    (400066001103, 400066001, 400066001901, 0.95),
    (400066001104, 400066001, 400066001901, 0.95),
    (400066001105, 400066001, 400066001901, 0.95),
    (400066001106, 400066001, 400066001901, 0.95),
    (400066001107, 400066001, 400066001901, 0.95),
    (400066001108, 400066001, 400066001901, 0.95),
    (400066001109, 400066001, 400066001901, 0.95),
    (400066001110, 400066001, 400066001901, 0.95),
    (400066001111, 400066001, 400066001901, 0.95),
    (400066001112, 400066001, 400066001901, 0.95),
    (400066001113, 400066001, 400066001901, 0.95),
    (400066001114, 400066001, 400066001901, 0.95),
    (400066001115, 400066001, 400066001901, 0.95),
    (400066001116, 400066001, 400066001901, 0.95),
    (400066001117, 400066001, 400066001901, 0.95),
    (400066001118, 400066001, 400066001901, 0.95),
    (400066001119, 400066001, 400066001901, 0.95),
    (400066001120, 400066001, 400066001901, 0.95),
    (400066001121, 400066001, 400066001901, 0.95),
    (400066001122, 400066001, 400066001901, 0.95),
    (400066001123, 400066001, 400066001901, 0.95),
    (400066001124, 400066001, 400066001901, 0.95),
    (400066001125, 400066001, 400066001901, 0.95),
    (400066001126, 400066001, 400066001901, 0.95),
    (400066001127, 400066001, 400066001901, 0.95),
    (400066001128, 400066001, 400066001901, 0.95),
    (400066001129, 400066001, 400066001901, 0.95),
    (400066001130, 400066001, 400066001901, 0.95),
    (400066001131, 400066001, 400066001901, 0.95),
    (400066001132, 400066001, 400066001901, 0.95),
    (400066001133, 400066001, 400066001901, 0.95),
    (400066001134, 400066001, 400066001901, 0.95),
    (400066001135, 400066001, 400066001901, 0.95),
    (400066001136, 400066001, 400066001901, 0.95),
    (400066001137, 400066001, 400066001901, 0.95),
    (400066001138, 400066001, 400066001901, 0.95),
    (400066001139, 400066001, 400066001901, 0.95),
    (400066001140, 400066001, 400066001901, 0.95),
    (400066001141, 400066001, 400066001901, 0.95),
    (400066001142, 400066001, 400066001901, 0.95),
    (400066001143, 400066001, 400066001901, 0.95),
    (400066001144, 400066001, 400066001901, 0.95),
    (400066001145, 400066001, 400066001901, 0.95),
    (400066001146, 400066001, 400066001901, 0.95),
    (400066001147, 400066001, 400066001901, 0.95),
    (400066001148, 400066001, 400066001901, 0.95),
    (400066001149, 400066001, 400066001901, 0.95),
    (400066001150, 400066001, 400066001901, 0.95),
    (400066001151, 400066001, 400066001901, 0.95),
    (400066001152, 400066001, 400066001901, 0.95),
    (400066001153, 400066001, 400066001901, 0.95),
    (400066001154, 400066001, 400066001901, 0.95),
    (400066001155, 400066001, 400066001901, 0.95),
    (400066001156, 400066001, 400066001901, 0.95),
    (400066001157, 400066001, 400066001901, 0.95),
    (400066001158, 400066001, 400066001901, 0.95),
    (400066001159, 400066001, 400066001901, 0.95),
    (400066001160, 400066001, 400066001901, 0.95),
    (400066001161, 400066001, 400066001901, 0.95),
    (400066001162, 400066001, 400066001901, 0.95),
    (400066001163, 400066001, 400066001901, 0.95),
    (400066001164, 400066001, 400066001901, 0.95),
    (400066001165, 400066001, 400066001901, 0.95),
    (400066001166, 400066001, 400066001901, 0.95),
    (400066001167, 400066001, 400066001901, 0.95),
    (400066001168, 400066001, 400066001901, 0.95),
    (400066001169, 400066001, 400066001901, 0.95),
    (400066001170, 400066001, 400066001901, 0.95),
    (400066001171, 400066001, 400066001901, 0.95),
    (400066001172, 400066001, 400066001901, 0.95),
    (400066001173, 400066001, 400066001901, 0.95),
    (400066001174, 400066001, 400066001901, 0.95),
    (400066001175, 400066001, 400066001901, 0.95),
    (400066001176, 400066001, 400066001901, 0.95),
    (400066001177, 400066001, 400066001901, 0.95),
    (400066001178, 400066001, 400066001901, 0.95),
    (400066001179, 400066001, 400066001901, 0.95),
    (400066001180, 400066001, 400066001901, 0.95),
    (400066001181, 400066001, 400066001901, 0.95),
    (400066001182, 400066001, 400066001901, 0.95),
    (400066001183, 400066001, 400066001901, 0.95),
    (400066001184, 400066001, 400066001901, 0.95),
    (400066001185, 400066001, 400066001901, 0.95),
    (400066001186, 400066001, 400066001901, 0.95),
    (400066001187, 400066001, 400066001901, 0.95),
    (400066001188, 400066001, 400066001901, 0.95),
    (400066001189, 400066001, 400066001901, 0.95),
    (400066001190, 400066001, 400066001901, 0.95),
    (400066001191, 400066001, 400066001901, 0.95),
    (400066001192, 400066001, 400066001901, 0.95),
    (400066001193, 400066001, 400066001901, 0.95),
    (400066001194, 400066001, 400066001901, 0.95),
    (400066001195, 400066001, 400066001901, 0.95),
    (400066001196, 400066001, 400066001901, 0.95),
    (400066001197, 400066001, 400066001901, 0.95),
    (400066001198, 400066001, 400066001901, 0.95),
    (400066001199, 400066001, 400066001901, 0.95),
    (400066001200, 400066001, 400066001901, 0.95),
    (400066001201, 400066001, 400066001901, 0.95),
    (400066001202, 400066001, 400066001901, 0.95),
    (400066001203, 400066001, 400066001901, 0.95),
    (400066001204, 400066001, 400066001901, 0.95),
    (400066001205, 400066001, 400066001901, 0.95),
    (400066001206, 400066001, 400066001901, 0.95),
    (400066001207, 400066001, 400066001901, 0.95),
    (400066001208, 400066001, 400066001901, 0.95),
    (400066001209, 400066001, 400066001901, 0.95),
    (400066001210, 400066001, 400066001901, 0.95),
    (400066001211, 400066001, 400066001901, 0.95),
    (400066001212, 400066001, 400066001901, 0.95),
    (400066001213, 400066001, 400066001901, 0.95),
    (400066001214, 400066001, 400066001901, 0.95),
    (400066001215, 400066001, 400066001901, 0.95),
    (400066001216, 400066001, 400066001901, 0.95),
    (400066001217, 400066001, 400066001901, 0.95),
    (400066001218, 400066001, 400066001901, 0.95),
    (400066001219, 400066001, 400066001901, 0.95),
    (400066001220, 400066001, 400066001901, 0.95),
    (400066001221, 400066001, 400066001901, 0.95),
    (400066001222, 400066001, 400066001901, 0.95),
    (400066001223, 400066001, 400066001901, 0.95),
    (400066001224, 400066001, 400066001901, 0.95),
    (400066001225, 400066001, 400066001901, 0.95),
    (400066001226, 400066001, 400066001901, 0.95),
    (400066001227, 400066001, 400066001901, 0.95),
    (400066001228, 400066001, 400066001901, 0.95),
    (400066001229, 400066001, 400066001901, 0.95),
    (400066001230, 400066001, 400066001901, 0.95),
    (400066001231, 400066001, 400066001901, 0.95),
    (400066001232, 400066001, 400066001901, 0.95),
    (400066001233, 400066001, 400066001901, 0.95),
    (400066001234, 400066001, 400066001901, 0.95),
    (400066001235, 400066001, 400066001901, 0.95),
    (400066001236, 400066001, 400066001901, 0.95),
    (400066001237, 400066001, 400066001901, 0.95),
    (400066001238, 400066001, 400066001901, 0.95),
    (400066001239, 400066001, 400066001901, 0.95),
    (400066001240, 400066001, 400066001901, 0.95),
    (400066001241, 400066001, 400066001901, 0.95),
    (400066001242, 400066001, 400066001901, 0.95),
    (400066001243, 400066001, 400066001901, 0.95),
    (400066001244, 400066001, 400066001901, 0.95),
    (400066001245, 400066001, 400066001901, 0.95),
    (400066001246, 400066001, 400066001901, 0.95),
    (400066001247, 400066001, 400066001901, 0.95),
    (400066001248, 400066001, 400066001901, 0.95),
    (400066001249, 400066001, 400066001901, 0.95),
    (400066001250, 400066001, 400066001901, 0.95),
    (400066001251, 400066001, 400066001901, 0.95),
    (400066001252, 400066001, 400066001901, 0.95),
    (400066001253, 400066001, 400066001901, 0.95),
    (400066001254, 400066001, 400066001901, 0.95),
    (400066001255, 400066001, 400066001901, 0.95),
    (400066001256, 400066001, 400066001901, 0.95),
    (400066001257, 400066001, 400066001901, 0.95),
    (400066001258, 400066001, 400066001901, 0.95),
    (400066001259, 400066001, 400066001901, 0.95),
    (400066001260, 400066001, 400066001901, 0.95),
    (400066001261, 400066001, 400066001901, 0.95),
    (400066001262, 400066001, 400066001901, 0.95),
    (400066001263, 400066001, 400066001901, 0.95),
    (400066001264, 400066001, 400066001901, 0.95),
    (400066001265, 400066001, 400066001901, 0.95),
    (400066001266, 400066001, 400066001901, 0.95),
    (400066001267, 400066001, 400066001901, 0.95),
    (400066001268, 400066001, 400066001901, 0.95),
    (400066001269, 400066001, 400066001901, 0.95),
    (400066001270, 400066001, 400066001901, 0.95),
    (400066001271, 400066001, 400066001901, 0.95),
    (400066001272, 400066001, 400066001901, 0.95),
    (400066001273, 400066001, 400066001901, 0.95),
    (400066001274, 400066001, 400066001901, 0.95),
    (400066001275, 400066001, 400066001901, 0.95),
    (400066001276, 400066001, 400066001901, 0.95),
    (400066001277, 400066001, 400066001901, 0.95),
    (400066001278, 400066001, 400066001901, 0.95),
    (400066001279, 400066001, 400066001901, 0.95),
    (400066001280, 400066001, 400066001901, 0.95),
    (400066001281, 400066001, 400066001901, 0.95),
    (400066001282, 400066001, 400066001901, 0.95),
    (400066001283, 400066001, 400066001901, 0.95),
    (400066001284, 400066001, 400066001901, 0.95),
    (400066001285, 400066001, 400066001901, 0.95),
    (400066001286, 400066001, 400066001901, 0.95),
    (400066001287, 400066001, 400066001901, 0.95),
    (400066001288, 400066001, 400066001901, 0.95),
    (400066001289, 400066001, 400066001901, 0.95),
    (400066001290, 400066001, 400066001901, 0.95),
    (400066001291, 400066001, 400066001901, 0.95),
    (400066001292, 400066001, 400066001901, 0.95),
    (400066001293, 400066001, 400066001901, 0.95),
    (400066001294, 400066001, 400066001901, 0.95),
    (400066001295, 400066001, 400066001901, 0.95),
    (400066001296, 400066001, 400066001901, 0.95),
    (400066001297, 400066001, 400066001901, 0.95),
    (400066001298, 400066001, 400066001901, 0.95),
    (400066001299, 400066001, 400066001901, 0.95),
    (400066001300, 400066001, 400066001901, 0.95),
    (400066001301, 400066001, 400066001901, 0.95),
    (400066001302, 400066001, 400066001901, 0.95),
    (400066001303, 400066001, 400066001901, 0.95),
    (400066001304, 400066001, 400066001901, 0.95),
    (400066001305, 400066001, 400066001901, 0.95),
    (400066001306, 400066001, 400066001901, 0.95),
    (400066001307, 400066001, 400066001901, 0.95),
    (400066001308, 400066001, 400066001901, 0.95),
    (400066001309, 400066001, 400066001901, 0.95),
    (400066001310, 400066001, 400066001901, 0.95),
    (400066001311, 400066001, 400066001901, 0.95),
    (400066001312, 400066001, 400066001901, 0.95),
    (400066001313, 400066001, 400066001901, 0.95),
    (400066001314, 400066001, 400066001901, 0.95),
    (400066001315, 400066001, 400066001901, 0.95),
    (400066001316, 400066001, 400066001901, 0.95),
    (400066001317, 400066001, 400066001901, 0.95),
    (400066001318, 400066001, 400066001901, 0.95),
    (400066001319, 400066001, 400066001901, 0.95),
    (400066001320, 400066001, 400066001901, 0.95),
    (400066001321, 400066001, 400066001901, 0.95),
    (400066001322, 400066001, 400066001901, 0.95),
    (400066001323, 400066001, 400066001901, 0.95),
    (400066001324, 400066001, 400066001901, 0.95),
    (400066001325, 400066001, 400066001901, 0.95),
    (400066001326, 400066001, 400066001901, 0.95),
    (400066001327, 400066001, 400066001901, 0.95),
    (400066001328, 400066001, 400066001901, 0.95),
    (400066001329, 400066001, 400066001901, 0.95),
    (400066001330, 400066001, 400066001901, 0.95),
    (400066001331, 400066001, 400066001901, 0.95),
    (400066001332, 400066001, 400066001901, 0.95),
    (400066001333, 400066001, 400066001901, 0.95),
    (400066001334, 400066001, 400066001901, 0.95),
    (400066001335, 400066001, 400066001901, 0.95),
    (400066001336, 400066001, 400066001901, 0.95),
    (400066001337, 400066001, 400066001901, 0.95),
    (400066001338, 400066001, 400066001901, 0.95),
    (400066001339, 400066001, 400066001901, 0.95),
    (400066001340, 400066001, 400066001901, 0.95),
    (400066001341, 400066001, 400066001901, 0.95),
    (400066001342, 400066001, 400066001901, 0.95),
    (400066001343, 400066001, 400066001901, 0.95),
    (400066001344, 400066001, 400066001901, 0.95),
    (400066001345, 400066001, 400066001901, 0.95),
    (400066001346, 400066001, 400066001901, 0.95),
    (400066001347, 400066001, 400066001901, 0.95),
    (400066001348, 400066001, 400066001901, 0.95),
    (400066001349, 400066001, 400066001901, 0.95),
    (400066001350, 400066001, 400066001901, 0.95),
    (400066001351, 400066001, 400066001901, 0.95),
    (400066001352, 400066001, 400066001901, 0.95),
    (400066001353, 400066001, 400066001901, 0.95),
    (400066001354, 400066001, 400066001901, 0.95),
    (400066001355, 400066001, 400066001901, 0.95),
    (400066001356, 400066001, 400066001901, 0.95),
    (400066001357, 400066001, 400066001901, 0.95),
    (400066001358, 400066001, 400066001901, 0.95),
    (400066001359, 400066001, 400066001901, 0.95),
    (400066001360, 400066001, 400066001901, 0.95),
    (400066001361, 400066001, 400066001901, 0.95),
    (400066001362, 400066001, 400066001901, 0.95),
    (400066001363, 400066001, 400066001901, 0.95),
    (400066001364, 400066001, 400066001901, 0.95),
    (400066001365, 400066001, 400066001901, 0.95),
    (400066001366, 400066001, 400066001901, 0.95),
    (400066001367, 400066001, 400066001901, 0.95),
    (400066001368, 400066001, 400066001901, 0.95),
    (400066001369, 400066001, 400066001901, 0.95),
    (400066001370, 400066001, 400066001901, 0.95),
    (400066001371, 400066001, 400066001901, 0.95),
    (400066001372, 400066001, 400066001901, 0.95),
    (400066001373, 400066001, 400066001901, 0.95),
    (400066001374, 400066001, 400066001901, 0.95),
    (400066001375, 400066001, 400066001901, 0.95),
    (400066001376, 400066001, 400066001901, 0.95),
    (400066001377, 400066001, 400066001901, 0.95),
    (400066001378, 400066001, 400066001901, 0.95),
    (400066001379, 400066001, 400066001901, 0.95),
    (400066001380, 400066001, 400066001901, 0.95),
    (400066001381, 400066001, 400066001901, 0.95),
    (400066001382, 400066001, 400066001901, 0.95),
    (400066001383, 400066001, 400066001901, 0.95),
    (400066001384, 400066001, 400066001901, 0.95),
    (400066001385, 400066001, 400066001901, 0.95),
    (400066001386, 400066001, 400066001901, 0.95),
    (400066001387, 400066001, 400066001901, 0.95),
    (400066001388, 400066001, 400066001901, 0.95),
    (400066001389, 400066001, 400066001901, 0.95),
    (400066001390, 400066001, 400066001901, 0.95),
    (400066001391, 400066001, 400066001901, 0.95),
    (400066001392, 400066001, 400066001901, 0.95),
    (400066001393, 400066001, 400066001901, 0.95),
    (400066001394, 400066001, 400066001901, 0.95),
    (400066001395, 400066001, 400066001901, 0.95),
    (400066001396, 400066001, 400066001901, 0.95),
    (400066001397, 400066001, 400066001901, 0.95),
    (400066001398, 400066001, 400066001901, 0.95),
    (400066001399, 400066001, 400066001901, 0.95),
    (400066001400, 400066001, 400066001901, 0.95),
    (400066001401, 400066001, 400066001901, 0.95),
    (400066001402, 400066001, 400066001901, 0.95),
    (400066001403, 400066001, 400066001901, 0.95),
    (400066001404, 400066001, 400066001901, 0.95),
    (400066001405, 400066001, 400066001901, 0.95),
    (400066001406, 400066001, 400066001901, 0.95),
    (400066001407, 400066001, 400066001901, 0.95),
    (400066001408, 400066001, 400066001901, 0.95),
    (400066001409, 400066001, 400066001901, 0.95),
    (400066001410, 400066001, 400066001901, 0.95),
    (400066001411, 400066001, 400066001901, 0.95),
    (400066001412, 400066001, 400066001901, 0.95),
    (400066001413, 400066001, 400066001901, 0.95),
    (400066001414, 400066001, 400066001901, 0.95),
    (400066001415, 400066001, 400066001901, 0.95),
    (400066001416, 400066001, 400066001901, 0.95),
    (400066001417, 400066001, 400066001901, 0.95),
    (400066001418, 400066001, 400066001901, 0.95),
    (400066001419, 400066001, 400066001901, 0.95),
    (400066001420, 400066001, 400066001901, 0.95),
    (400066001421, 400066001, 400066001901, 0.95),
    (400066001422, 400066001, 400066001901, 0.95),
    (400066001423, 400066001, 400066001901, 0.95),
    (400066001424, 400066001, 400066001901, 0.95),
    (400066001425, 400066001, 400066001901, 0.95),
    (400066001426, 400066001, 400066001901, 0.95),
    (400066001427, 400066001, 400066001901, 0.95),
    (400066001428, 400066001, 400066001901, 0.95),
    (400066001429, 400066001, 400066001901, 0.95),
    (400066001430, 400066001, 400066001901, 0.95),
    (400066001431, 400066001, 400066001901, 0.95);

-- ---------------------------------------------------------------------------
-- 7. Item availability and bundle  (Source: JSON, "pages[6].content[0]" - Punjabi Thali, "11 am to 6 pm")
-- ---------------------------------------------------------------------------
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time, is_active)
VALUES (400066001001, 400066001429, NULL, '11:00', '18:00', TRUE);

INSERT INTO bundle (bundle_id, menu_item_id, bundle_type_code, is_customizable, description)
VALUES (400066001901, 400066001429, 'thali', FALSE, 'Paneer Bhaji, Mix Veg, Dal Fry, Jeera Rice, Veg Raita, Gulab Jamun, Rosted Papad, Roti / Chapati / Puri (Any One)');

-- ---------------------------------------------------------------------------
-- 8. Board <-> category and board <-> item mappings
-- ---------------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
    (400066001, 400066001001, 400066001001, 1),
    (400066001, 400066001001, 400066001002, 2),
    (400066001, 400066001001, 400066001003, 3),
    (400066001, 400066001001, 400066001004, 4),
    (400066001, 400066001001, 400066001005, 5),
    (400066001, 400066001001, 400066001006, 6),
    (400066001, 400066001001, 400066001007, 7),
    (400066001, 400066001001, 400066001008, 8),
    (400066001, 400066001001, 400066001009, 9),
    (400066001, 400066001001, 400066001010, 10),
    (400066001, 400066001001, 400066001011, 11),
    (400066001, 400066001001, 400066001012, 12),
    (400066001, 400066001001, 400066001013, 13),
    (400066001, 400066001001, 400066001014, 14),
    (400066001, 400066001001, 400066001015, 15),
    (400066001, 400066001001, 400066001016, 16),
    (400066001, 400066001001, 400066001017, 17),
    (400066001, 400066001001, 400066001018, 18),
    (400066001, 400066001001, 400066001019, 19),
    (400066001, 400066001001, 400066001020, 20),
    (400066001, 400066001001, 400066001021, 21),
    (400066001, 400066001001, 400066001022, 22),
    (400066001, 400066001001, 400066001023, 23),
    (400066001, 400066001001, 400066001024, 24);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence) VALUES
    (400066001001, 400066001, 400066001001, 400066001001, 400066001001, 1),
    (400066001002, 400066001, 400066001001, 400066001002, 400066001001, 2),
    (400066001003, 400066001, 400066001001, 400066001003, 400066001001, 3),
    (400066001004, 400066001, 400066001001, 400066001004, 400066001001, 4),
    (400066001005, 400066001, 400066001001, 400066001005, 400066001001, 5),
    (400066001006, 400066001, 400066001001, 400066001006, 400066001001, 6),
    (400066001007, 400066001, 400066001001, 400066001007, 400066001001, 7),
    (400066001008, 400066001, 400066001001, 400066001008, 400066001001, 8),
    (400066001009, 400066001, 400066001001, 400066001009, 400066001001, 9),
    (400066001010, 400066001, 400066001001, 400066001010, 400066001001, 10),
    (400066001011, 400066001, 400066001001, 400066001011, 400066001001, 11),
    (400066001012, 400066001, 400066001001, 400066001012, 400066001001, 12),
    (400066001013, 400066001, 400066001001, 400066001013, 400066001001, 13),
    (400066001014, 400066001, 400066001001, 400066001014, 400066001001, 14),
    (400066001015, 400066001, 400066001001, 400066001015, 400066001001, 15),
    (400066001016, 400066001, 400066001001, 400066001016, 400066001001, 16),
    (400066001017, 400066001, 400066001001, 400066001017, 400066001001, 17),
    (400066001018, 400066001, 400066001001, 400066001018, 400066001001, 18),
    (400066001019, 400066001, 400066001001, 400066001019, 400066001001, 19),
    (400066001020, 400066001, 400066001001, 400066001020, 400066001001, 20),
    (400066001021, 400066001, 400066001001, 400066001021, 400066001001, 21),
    (400066001022, 400066001, 400066001001, 400066001022, 400066001001, 22),
    (400066001023, 400066001, 400066001001, 400066001023, 400066001001, 23),
    (400066001024, 400066001, 400066001001, 400066001024, 400066001001, 24),
    (400066001025, 400066001, 400066001001, 400066001025, 400066001001, 25),
    (400066001026, 400066001, 400066001001, 400066001026, 400066001001, 26),
    (400066001027, 400066001, 400066001001, 400066001027, 400066001001, 27),
    (400066001028, 400066001, 400066001001, 400066001028, 400066001001, 28),
    (400066001029, 400066001, 400066001001, 400066001029, 400066001001, 29),
    (400066001030, 400066001, 400066001001, 400066001030, 400066001001, 30),
    (400066001031, 400066001, 400066001001, 400066001031, 400066001001, 31),
    (400066001032, 400066001, 400066001001, 400066001032, 400066001001, 32),
    (400066001033, 400066001, 400066001001, 400066001033, 400066001001, 33),
    (400066001034, 400066001, 400066001001, 400066001034, 400066001001, 34),
    (400066001035, 400066001, 400066001001, 400066001035, 400066001001, 35),
    (400066001036, 400066001, 400066001001, 400066001036, 400066001001, 36),
    (400066001037, 400066001, 400066001001, 400066001037, 400066001002, 37),
    (400066001038, 400066001, 400066001001, 400066001038, 400066001002, 38),
    (400066001039, 400066001, 400066001001, 400066001039, 400066001002, 39),
    (400066001040, 400066001, 400066001001, 400066001040, 400066001002, 40),
    (400066001041, 400066001, 400066001001, 400066001041, 400066001003, 41),
    (400066001042, 400066001, 400066001001, 400066001042, 400066001003, 42),
    (400066001043, 400066001, 400066001001, 400066001043, 400066001003, 43),
    (400066001044, 400066001, 400066001001, 400066001044, 400066001003, 44),
    (400066001045, 400066001, 400066001001, 400066001045, 400066001003, 45),
    (400066001046, 400066001, 400066001001, 400066001046, 400066001003, 46),
    (400066001047, 400066001, 400066001001, 400066001047, 400066001003, 47),
    (400066001048, 400066001, 400066001001, 400066001048, 400066001003, 48),
    (400066001049, 400066001, 400066001001, 400066001049, 400066001003, 49),
    (400066001050, 400066001, 400066001001, 400066001050, 400066001003, 50),
    (400066001051, 400066001, 400066001001, 400066001051, 400066001003, 51),
    (400066001052, 400066001, 400066001001, 400066001052, 400066001003, 52),
    (400066001053, 400066001, 400066001001, 400066001053, 400066001003, 53),
    (400066001054, 400066001, 400066001001, 400066001054, 400066001003, 54),
    (400066001055, 400066001, 400066001001, 400066001055, 400066001003, 55),
    (400066001056, 400066001, 400066001001, 400066001056, 400066001003, 56),
    (400066001057, 400066001, 400066001001, 400066001057, 400066001003, 57),
    (400066001058, 400066001, 400066001001, 400066001058, 400066001003, 58),
    (400066001059, 400066001, 400066001001, 400066001059, 400066001003, 59),
    (400066001060, 400066001, 400066001001, 400066001060, 400066001003, 60),
    (400066001061, 400066001, 400066001001, 400066001061, 400066001003, 61),
    (400066001062, 400066001, 400066001001, 400066001062, 400066001004, 62),
    (400066001063, 400066001, 400066001001, 400066001063, 400066001004, 63),
    (400066001064, 400066001, 400066001001, 400066001064, 400066001004, 64),
    (400066001065, 400066001, 400066001001, 400066001065, 400066001004, 65),
    (400066001066, 400066001, 400066001001, 400066001066, 400066001004, 66),
    (400066001067, 400066001, 400066001001, 400066001067, 400066001004, 67),
    (400066001068, 400066001, 400066001001, 400066001068, 400066001004, 68),
    (400066001069, 400066001, 400066001001, 400066001069, 400066001004, 69),
    (400066001070, 400066001, 400066001001, 400066001070, 400066001004, 70),
    (400066001071, 400066001, 400066001001, 400066001071, 400066001005, 71),
    (400066001072, 400066001, 400066001001, 400066001072, 400066001005, 72),
    (400066001073, 400066001, 400066001001, 400066001073, 400066001005, 73),
    (400066001074, 400066001, 400066001001, 400066001074, 400066001006, 74),
    (400066001075, 400066001, 400066001001, 400066001075, 400066001006, 75),
    (400066001076, 400066001, 400066001001, 400066001076, 400066001006, 76),
    (400066001077, 400066001, 400066001001, 400066001077, 400066001006, 77),
    (400066001078, 400066001, 400066001001, 400066001078, 400066001006, 78),
    (400066001079, 400066001, 400066001001, 400066001079, 400066001006, 79),
    (400066001080, 400066001, 400066001001, 400066001080, 400066001006, 80),
    (400066001081, 400066001, 400066001001, 400066001081, 400066001006, 81),
    (400066001082, 400066001, 400066001001, 400066001082, 400066001006, 82),
    (400066001083, 400066001, 400066001001, 400066001083, 400066001006, 83),
    (400066001084, 400066001, 400066001001, 400066001084, 400066001006, 84),
    (400066001085, 400066001, 400066001001, 400066001085, 400066001006, 85),
    (400066001086, 400066001, 400066001001, 400066001086, 400066001006, 86),
    (400066001087, 400066001, 400066001001, 400066001087, 400066001006, 87),
    (400066001088, 400066001, 400066001001, 400066001088, 400066001006, 88),
    (400066001089, 400066001, 400066001001, 400066001089, 400066001006, 89),
    (400066001090, 400066001, 400066001001, 400066001090, 400066001006, 90),
    (400066001091, 400066001, 400066001001, 400066001091, 400066001007, 91),
    (400066001092, 400066001, 400066001001, 400066001092, 400066001007, 92),
    (400066001093, 400066001, 400066001001, 400066001093, 400066001007, 93),
    (400066001094, 400066001, 400066001001, 400066001094, 400066001007, 94),
    (400066001095, 400066001, 400066001001, 400066001095, 400066001007, 95),
    (400066001096, 400066001, 400066001001, 400066001096, 400066001007, 96),
    (400066001097, 400066001, 400066001001, 400066001097, 400066001007, 97),
    (400066001098, 400066001, 400066001001, 400066001098, 400066001007, 98),
    (400066001099, 400066001, 400066001001, 400066001099, 400066001007, 99),
    (400066001100, 400066001, 400066001001, 400066001100, 400066001007, 100),
    (400066001101, 400066001, 400066001001, 400066001101, 400066001007, 101),
    (400066001102, 400066001, 400066001001, 400066001102, 400066001007, 102),
    (400066001103, 400066001, 400066001001, 400066001103, 400066001007, 103),
    (400066001104, 400066001, 400066001001, 400066001104, 400066001008, 104),
    (400066001105, 400066001, 400066001001, 400066001105, 400066001008, 105),
    (400066001106, 400066001, 400066001001, 400066001106, 400066001008, 106),
    (400066001107, 400066001, 400066001001, 400066001107, 400066001008, 107),
    (400066001108, 400066001, 400066001001, 400066001108, 400066001008, 108),
    (400066001109, 400066001, 400066001001, 400066001109, 400066001008, 109),
    (400066001110, 400066001, 400066001001, 400066001110, 400066001008, 110),
    (400066001111, 400066001, 400066001001, 400066001111, 400066001008, 111),
    (400066001112, 400066001, 400066001001, 400066001112, 400066001008, 112),
    (400066001113, 400066001, 400066001001, 400066001113, 400066001008, 113),
    (400066001114, 400066001, 400066001001, 400066001114, 400066001008, 114),
    (400066001115, 400066001, 400066001001, 400066001115, 400066001008, 115),
    (400066001116, 400066001, 400066001001, 400066001116, 400066001008, 116),
    (400066001117, 400066001, 400066001001, 400066001117, 400066001008, 117),
    (400066001118, 400066001, 400066001001, 400066001118, 400066001008, 118),
    (400066001119, 400066001, 400066001001, 400066001119, 400066001008, 119),
    (400066001120, 400066001, 400066001001, 400066001120, 400066001008, 120),
    (400066001121, 400066001, 400066001001, 400066001121, 400066001008, 121),
    (400066001122, 400066001, 400066001001, 400066001122, 400066001008, 122),
    (400066001123, 400066001, 400066001001, 400066001123, 400066001008, 123),
    (400066001124, 400066001, 400066001001, 400066001124, 400066001008, 124),
    (400066001125, 400066001, 400066001001, 400066001125, 400066001008, 125),
    (400066001126, 400066001, 400066001001, 400066001126, 400066001008, 126),
    (400066001127, 400066001, 400066001001, 400066001127, 400066001008, 127),
    (400066001128, 400066001, 400066001001, 400066001128, 400066001008, 128),
    (400066001129, 400066001, 400066001001, 400066001129, 400066001008, 129),
    (400066001130, 400066001, 400066001001, 400066001130, 400066001008, 130),
    (400066001131, 400066001, 400066001001, 400066001131, 400066001008, 131),
    (400066001132, 400066001, 400066001001, 400066001132, 400066001008, 132),
    (400066001133, 400066001, 400066001001, 400066001133, 400066001008, 133),
    (400066001134, 400066001, 400066001001, 400066001134, 400066001008, 134),
    (400066001135, 400066001, 400066001001, 400066001135, 400066001008, 135),
    (400066001136, 400066001, 400066001001, 400066001136, 400066001009, 136),
    (400066001137, 400066001, 400066001001, 400066001137, 400066001009, 137),
    (400066001138, 400066001, 400066001001, 400066001138, 400066001009, 138),
    (400066001139, 400066001, 400066001001, 400066001139, 400066001009, 139),
    (400066001140, 400066001, 400066001001, 400066001140, 400066001009, 140),
    (400066001141, 400066001, 400066001001, 400066001141, 400066001009, 141),
    (400066001142, 400066001, 400066001001, 400066001142, 400066001009, 142),
    (400066001143, 400066001, 400066001001, 400066001143, 400066001009, 143),
    (400066001144, 400066001, 400066001001, 400066001144, 400066001009, 144),
    (400066001145, 400066001, 400066001001, 400066001145, 400066001009, 145),
    (400066001146, 400066001, 400066001001, 400066001146, 400066001009, 146),
    (400066001147, 400066001, 400066001001, 400066001147, 400066001009, 147),
    (400066001148, 400066001, 400066001001, 400066001148, 400066001009, 148),
    (400066001149, 400066001, 400066001001, 400066001149, 400066001009, 149),
    (400066001150, 400066001, 400066001001, 400066001150, 400066001009, 150),
    (400066001151, 400066001, 400066001001, 400066001151, 400066001009, 151),
    (400066001152, 400066001, 400066001001, 400066001152, 400066001009, 152),
    (400066001153, 400066001, 400066001001, 400066001153, 400066001009, 153),
    (400066001154, 400066001, 400066001001, 400066001154, 400066001009, 154),
    (400066001155, 400066001, 400066001001, 400066001155, 400066001009, 155),
    (400066001156, 400066001, 400066001001, 400066001156, 400066001009, 156),
    (400066001157, 400066001, 400066001001, 400066001157, 400066001009, 157),
    (400066001158, 400066001, 400066001001, 400066001158, 400066001009, 158),
    (400066001159, 400066001, 400066001001, 400066001159, 400066001009, 159),
    (400066001160, 400066001, 400066001001, 400066001160, 400066001009, 160),
    (400066001161, 400066001, 400066001001, 400066001161, 400066001009, 161),
    (400066001162, 400066001, 400066001001, 400066001162, 400066001009, 162),
    (400066001163, 400066001, 400066001001, 400066001163, 400066001009, 163),
    (400066001164, 400066001, 400066001001, 400066001164, 400066001009, 164),
    (400066001165, 400066001, 400066001001, 400066001165, 400066001009, 165),
    (400066001166, 400066001, 400066001001, 400066001166, 400066001009, 166),
    (400066001167, 400066001, 400066001001, 400066001167, 400066001009, 167),
    (400066001168, 400066001, 400066001001, 400066001168, 400066001009, 168),
    (400066001169, 400066001, 400066001001, 400066001169, 400066001009, 169),
    (400066001170, 400066001, 400066001001, 400066001170, 400066001009, 170),
    (400066001171, 400066001, 400066001001, 400066001171, 400066001009, 171),
    (400066001172, 400066001, 400066001001, 400066001172, 400066001009, 172),
    (400066001173, 400066001, 400066001001, 400066001173, 400066001009, 173),
    (400066001174, 400066001, 400066001001, 400066001174, 400066001009, 174),
    (400066001175, 400066001, 400066001001, 400066001175, 400066001009, 175),
    (400066001176, 400066001, 400066001001, 400066001176, 400066001009, 176),
    (400066001177, 400066001, 400066001001, 400066001177, 400066001009, 177),
    (400066001178, 400066001, 400066001001, 400066001178, 400066001009, 178),
    (400066001179, 400066001, 400066001001, 400066001179, 400066001009, 179),
    (400066001180, 400066001, 400066001001, 400066001180, 400066001009, 180),
    (400066001181, 400066001, 400066001001, 400066001181, 400066001009, 181),
    (400066001182, 400066001, 400066001001, 400066001182, 400066001009, 182),
    (400066001183, 400066001, 400066001001, 400066001183, 400066001009, 183),
    (400066001184, 400066001, 400066001001, 400066001184, 400066001009, 184),
    (400066001185, 400066001, 400066001001, 400066001185, 400066001009, 185),
    (400066001186, 400066001, 400066001001, 400066001186, 400066001009, 186),
    (400066001187, 400066001, 400066001001, 400066001187, 400066001009, 187),
    (400066001188, 400066001, 400066001001, 400066001188, 400066001009, 188),
    (400066001189, 400066001, 400066001001, 400066001189, 400066001009, 189),
    (400066001190, 400066001, 400066001001, 400066001190, 400066001009, 190),
    (400066001191, 400066001, 400066001001, 400066001191, 400066001009, 191),
    (400066001192, 400066001, 400066001001, 400066001192, 400066001009, 192),
    (400066001193, 400066001, 400066001001, 400066001193, 400066001009, 193),
    (400066001194, 400066001, 400066001001, 400066001194, 400066001009, 194),
    (400066001195, 400066001, 400066001001, 400066001195, 400066001009, 195),
    (400066001196, 400066001, 400066001001, 400066001196, 400066001009, 196),
    (400066001197, 400066001, 400066001001, 400066001197, 400066001009, 197),
    (400066001198, 400066001, 400066001001, 400066001198, 400066001009, 198),
    (400066001199, 400066001, 400066001001, 400066001199, 400066001009, 199),
    (400066001200, 400066001, 400066001001, 400066001200, 400066001009, 200),
    (400066001201, 400066001, 400066001001, 400066001201, 400066001009, 201),
    (400066001202, 400066001, 400066001001, 400066001202, 400066001009, 202),
    (400066001203, 400066001, 400066001001, 400066001203, 400066001009, 203),
    (400066001204, 400066001, 400066001001, 400066001204, 400066001009, 204),
    (400066001205, 400066001, 400066001001, 400066001205, 400066001009, 205),
    (400066001206, 400066001, 400066001001, 400066001206, 400066001009, 206),
    (400066001207, 400066001, 400066001001, 400066001207, 400066001009, 207),
    (400066001208, 400066001, 400066001001, 400066001208, 400066001009, 208),
    (400066001209, 400066001, 400066001001, 400066001209, 400066001009, 209),
    (400066001210, 400066001, 400066001001, 400066001210, 400066001009, 210),
    (400066001211, 400066001, 400066001001, 400066001211, 400066001009, 211),
    (400066001212, 400066001, 400066001001, 400066001212, 400066001009, 212),
    (400066001213, 400066001, 400066001001, 400066001213, 400066001009, 213),
    (400066001214, 400066001, 400066001001, 400066001214, 400066001009, 214),
    (400066001215, 400066001, 400066001001, 400066001215, 400066001009, 215),
    (400066001216, 400066001, 400066001001, 400066001216, 400066001009, 216),
    (400066001217, 400066001, 400066001001, 400066001217, 400066001009, 217),
    (400066001218, 400066001, 400066001001, 400066001218, 400066001009, 218),
    (400066001219, 400066001, 400066001001, 400066001219, 400066001009, 219),
    (400066001220, 400066001, 400066001001, 400066001220, 400066001009, 220),
    (400066001221, 400066001, 400066001001, 400066001221, 400066001009, 221),
    (400066001222, 400066001, 400066001001, 400066001222, 400066001009, 222),
    (400066001223, 400066001, 400066001001, 400066001223, 400066001009, 223),
    (400066001224, 400066001, 400066001001, 400066001224, 400066001009, 224),
    (400066001225, 400066001, 400066001001, 400066001225, 400066001009, 225),
    (400066001226, 400066001, 400066001001, 400066001226, 400066001009, 226),
    (400066001227, 400066001, 400066001001, 400066001227, 400066001009, 227),
    (400066001228, 400066001, 400066001001, 400066001228, 400066001009, 228),
    (400066001229, 400066001, 400066001001, 400066001229, 400066001009, 229),
    (400066001230, 400066001, 400066001001, 400066001230, 400066001009, 230),
    (400066001231, 400066001, 400066001001, 400066001231, 400066001009, 231),
    (400066001232, 400066001, 400066001001, 400066001232, 400066001010, 232),
    (400066001233, 400066001, 400066001001, 400066001233, 400066001010, 233),
    (400066001234, 400066001, 400066001001, 400066001234, 400066001010, 234),
    (400066001235, 400066001, 400066001001, 400066001235, 400066001010, 235),
    (400066001236, 400066001, 400066001001, 400066001236, 400066001010, 236),
    (400066001237, 400066001, 400066001001, 400066001237, 400066001010, 237),
    (400066001238, 400066001, 400066001001, 400066001238, 400066001010, 238),
    (400066001239, 400066001, 400066001001, 400066001239, 400066001010, 239),
    (400066001240, 400066001, 400066001001, 400066001240, 400066001010, 240),
    (400066001241, 400066001, 400066001001, 400066001241, 400066001010, 241),
    (400066001242, 400066001, 400066001001, 400066001242, 400066001010, 242),
    (400066001243, 400066001, 400066001001, 400066001243, 400066001010, 243),
    (400066001244, 400066001, 400066001001, 400066001244, 400066001010, 244),
    (400066001245, 400066001, 400066001001, 400066001245, 400066001010, 245),
    (400066001246, 400066001, 400066001001, 400066001246, 400066001010, 246),
    (400066001247, 400066001, 400066001001, 400066001247, 400066001010, 247),
    (400066001248, 400066001, 400066001001, 400066001248, 400066001010, 248),
    (400066001249, 400066001, 400066001001, 400066001249, 400066001010, 249),
    (400066001250, 400066001, 400066001001, 400066001250, 400066001010, 250),
    (400066001251, 400066001, 400066001001, 400066001251, 400066001010, 251),
    (400066001252, 400066001, 400066001001, 400066001252, 400066001010, 252),
    (400066001253, 400066001, 400066001001, 400066001253, 400066001010, 253),
    (400066001254, 400066001, 400066001001, 400066001254, 400066001010, 254),
    (400066001255, 400066001, 400066001001, 400066001255, 400066001010, 255),
    (400066001256, 400066001, 400066001001, 400066001256, 400066001011, 256),
    (400066001257, 400066001, 400066001001, 400066001257, 400066001011, 257),
    (400066001258, 400066001, 400066001001, 400066001258, 400066001011, 258),
    (400066001259, 400066001, 400066001001, 400066001259, 400066001011, 259),
    (400066001260, 400066001, 400066001001, 400066001260, 400066001011, 260),
    (400066001261, 400066001, 400066001001, 400066001261, 400066001011, 261),
    (400066001262, 400066001, 400066001001, 400066001262, 400066001011, 262),
    (400066001263, 400066001, 400066001001, 400066001263, 400066001011, 263),
    (400066001264, 400066001, 400066001001, 400066001264, 400066001011, 264),
    (400066001265, 400066001, 400066001001, 400066001265, 400066001011, 265),
    (400066001266, 400066001, 400066001001, 400066001266, 400066001011, 266),
    (400066001267, 400066001, 400066001001, 400066001267, 400066001011, 267),
    (400066001268, 400066001, 400066001001, 400066001268, 400066001011, 268),
    (400066001269, 400066001, 400066001001, 400066001269, 400066001011, 269),
    (400066001270, 400066001, 400066001001, 400066001270, 400066001011, 270),
    (400066001271, 400066001, 400066001001, 400066001271, 400066001011, 271),
    (400066001272, 400066001, 400066001001, 400066001272, 400066001011, 272),
    (400066001273, 400066001, 400066001001, 400066001273, 400066001011, 273),
    (400066001274, 400066001, 400066001001, 400066001274, 400066001011, 274),
    (400066001275, 400066001, 400066001001, 400066001275, 400066001011, 275),
    (400066001276, 400066001, 400066001001, 400066001276, 400066001011, 276),
    (400066001277, 400066001, 400066001001, 400066001277, 400066001011, 277),
    (400066001278, 400066001, 400066001001, 400066001278, 400066001011, 278),
    (400066001279, 400066001, 400066001001, 400066001279, 400066001011, 279),
    (400066001280, 400066001, 400066001001, 400066001280, 400066001011, 280),
    (400066001281, 400066001, 400066001001, 400066001281, 400066001011, 281),
    (400066001282, 400066001, 400066001001, 400066001282, 400066001011, 282),
    (400066001283, 400066001, 400066001001, 400066001283, 400066001011, 283),
    (400066001284, 400066001, 400066001001, 400066001284, 400066001011, 284),
    (400066001285, 400066001, 400066001001, 400066001285, 400066001011, 285),
    (400066001286, 400066001, 400066001001, 400066001286, 400066001011, 286),
    (400066001287, 400066001, 400066001001, 400066001287, 400066001012, 287),
    (400066001288, 400066001, 400066001001, 400066001288, 400066001012, 288),
    (400066001289, 400066001, 400066001001, 400066001289, 400066001012, 289),
    (400066001290, 400066001, 400066001001, 400066001290, 400066001012, 290),
    (400066001291, 400066001, 400066001001, 400066001291, 400066001012, 291),
    (400066001292, 400066001, 400066001001, 400066001292, 400066001012, 292),
    (400066001293, 400066001, 400066001001, 400066001293, 400066001012, 293),
    (400066001294, 400066001, 400066001001, 400066001294, 400066001012, 294),
    (400066001295, 400066001, 400066001001, 400066001295, 400066001012, 295),
    (400066001296, 400066001, 400066001001, 400066001296, 400066001012, 296),
    (400066001297, 400066001, 400066001001, 400066001297, 400066001012, 297),
    (400066001298, 400066001, 400066001001, 400066001298, 400066001012, 298),
    (400066001299, 400066001, 400066001001, 400066001299, 400066001012, 299),
    (400066001300, 400066001, 400066001001, 400066001300, 400066001012, 300),
    (400066001301, 400066001, 400066001001, 400066001301, 400066001012, 301),
    (400066001302, 400066001, 400066001001, 400066001302, 400066001012, 302),
    (400066001303, 400066001, 400066001001, 400066001303, 400066001012, 303),
    (400066001304, 400066001, 400066001001, 400066001304, 400066001012, 304),
    (400066001305, 400066001, 400066001001, 400066001305, 400066001012, 305),
    (400066001306, 400066001, 400066001001, 400066001306, 400066001012, 306),
    (400066001307, 400066001, 400066001001, 400066001307, 400066001012, 307),
    (400066001308, 400066001, 400066001001, 400066001308, 400066001012, 308),
    (400066001309, 400066001, 400066001001, 400066001309, 400066001012, 309),
    (400066001310, 400066001, 400066001001, 400066001310, 400066001012, 310),
    (400066001311, 400066001, 400066001001, 400066001311, 400066001012, 311),
    (400066001312, 400066001, 400066001001, 400066001312, 400066001013, 312),
    (400066001313, 400066001, 400066001001, 400066001313, 400066001013, 313),
    (400066001314, 400066001, 400066001001, 400066001314, 400066001013, 314),
    (400066001315, 400066001, 400066001001, 400066001315, 400066001013, 315),
    (400066001316, 400066001, 400066001001, 400066001316, 400066001013, 316),
    (400066001317, 400066001, 400066001001, 400066001317, 400066001013, 317),
    (400066001318, 400066001, 400066001001, 400066001318, 400066001013, 318),
    (400066001319, 400066001, 400066001001, 400066001319, 400066001013, 319),
    (400066001320, 400066001, 400066001001, 400066001320, 400066001013, 320),
    (400066001321, 400066001, 400066001001, 400066001321, 400066001013, 321),
    (400066001322, 400066001, 400066001001, 400066001322, 400066001013, 322),
    (400066001323, 400066001, 400066001001, 400066001323, 400066001013, 323),
    (400066001324, 400066001, 400066001001, 400066001324, 400066001013, 324),
    (400066001325, 400066001, 400066001001, 400066001325, 400066001013, 325),
    (400066001326, 400066001, 400066001001, 400066001326, 400066001013, 326),
    (400066001327, 400066001, 400066001001, 400066001327, 400066001013, 327),
    (400066001328, 400066001, 400066001001, 400066001328, 400066001013, 328),
    (400066001329, 400066001, 400066001001, 400066001329, 400066001013, 329),
    (400066001330, 400066001, 400066001001, 400066001330, 400066001014, 330),
    (400066001331, 400066001, 400066001001, 400066001331, 400066001014, 331),
    (400066001332, 400066001, 400066001001, 400066001332, 400066001014, 332),
    (400066001333, 400066001, 400066001001, 400066001333, 400066001014, 333),
    (400066001334, 400066001, 400066001001, 400066001334, 400066001014, 334),
    (400066001335, 400066001, 400066001001, 400066001335, 400066001014, 335),
    (400066001336, 400066001, 400066001001, 400066001336, 400066001014, 336),
    (400066001337, 400066001, 400066001001, 400066001337, 400066001014, 337),
    (400066001338, 400066001, 400066001001, 400066001338, 400066001014, 338),
    (400066001339, 400066001, 400066001001, 400066001339, 400066001014, 339),
    (400066001340, 400066001, 400066001001, 400066001340, 400066001014, 340),
    (400066001341, 400066001, 400066001001, 400066001341, 400066001014, 341),
    (400066001342, 400066001, 400066001001, 400066001342, 400066001014, 342),
    (400066001343, 400066001, 400066001001, 400066001343, 400066001014, 343),
    (400066001344, 400066001, 400066001001, 400066001344, 400066001014, 344),
    (400066001345, 400066001, 400066001001, 400066001345, 400066001014, 345),
    (400066001346, 400066001, 400066001001, 400066001346, 400066001014, 346),
    (400066001347, 400066001, 400066001001, 400066001347, 400066001014, 347),
    (400066001348, 400066001, 400066001001, 400066001348, 400066001014, 348),
    (400066001349, 400066001, 400066001001, 400066001349, 400066001014, 349),
    (400066001350, 400066001, 400066001001, 400066001350, 400066001014, 350),
    (400066001351, 400066001, 400066001001, 400066001351, 400066001014, 351),
    (400066001352, 400066001, 400066001001, 400066001352, 400066001014, 352),
    (400066001353, 400066001, 400066001001, 400066001353, 400066001014, 353),
    (400066001354, 400066001, 400066001001, 400066001354, 400066001015, 354),
    (400066001355, 400066001, 400066001001, 400066001355, 400066001015, 355),
    (400066001356, 400066001, 400066001001, 400066001356, 400066001015, 356),
    (400066001357, 400066001, 400066001001, 400066001357, 400066001015, 357),
    (400066001358, 400066001, 400066001001, 400066001358, 400066001015, 358),
    (400066001359, 400066001, 400066001001, 400066001359, 400066001015, 359),
    (400066001360, 400066001, 400066001001, 400066001360, 400066001015, 360),
    (400066001361, 400066001, 400066001001, 400066001361, 400066001015, 361),
    (400066001362, 400066001, 400066001001, 400066001362, 400066001015, 362),
    (400066001363, 400066001, 400066001001, 400066001363, 400066001015, 363),
    (400066001364, 400066001, 400066001001, 400066001364, 400066001015, 364),
    (400066001365, 400066001, 400066001001, 400066001365, 400066001016, 365),
    (400066001366, 400066001, 400066001001, 400066001366, 400066001016, 366),
    (400066001367, 400066001, 400066001001, 400066001367, 400066001016, 367),
    (400066001368, 400066001, 400066001001, 400066001368, 400066001016, 368),
    (400066001369, 400066001, 400066001001, 400066001369, 400066001016, 369),
    (400066001370, 400066001, 400066001001, 400066001370, 400066001016, 370),
    (400066001371, 400066001, 400066001001, 400066001371, 400066001016, 371),
    (400066001372, 400066001, 400066001001, 400066001372, 400066001016, 372),
    (400066001373, 400066001, 400066001001, 400066001373, 400066001016, 373),
    (400066001374, 400066001, 400066001001, 400066001374, 400066001017, 374),
    (400066001375, 400066001, 400066001001, 400066001375, 400066001017, 375),
    (400066001376, 400066001, 400066001001, 400066001376, 400066001017, 376),
    (400066001377, 400066001, 400066001001, 400066001377, 400066001017, 377),
    (400066001378, 400066001, 400066001001, 400066001378, 400066001017, 378),
    (400066001379, 400066001, 400066001001, 400066001379, 400066001017, 379),
    (400066001380, 400066001, 400066001001, 400066001380, 400066001018, 380),
    (400066001381, 400066001, 400066001001, 400066001381, 400066001018, 381),
    (400066001382, 400066001, 400066001001, 400066001382, 400066001018, 382),
    (400066001383, 400066001, 400066001001, 400066001383, 400066001018, 383),
    (400066001384, 400066001, 400066001001, 400066001384, 400066001018, 384),
    (400066001385, 400066001, 400066001001, 400066001385, 400066001018, 385),
    (400066001386, 400066001, 400066001001, 400066001386, 400066001018, 386),
    (400066001387, 400066001, 400066001001, 400066001387, 400066001018, 387),
    (400066001388, 400066001, 400066001001, 400066001388, 400066001018, 388),
    (400066001389, 400066001, 400066001001, 400066001389, 400066001018, 389),
    (400066001390, 400066001, 400066001001, 400066001390, 400066001019, 390),
    (400066001391, 400066001, 400066001001, 400066001391, 400066001019, 391),
    (400066001392, 400066001, 400066001001, 400066001392, 400066001019, 392),
    (400066001393, 400066001, 400066001001, 400066001393, 400066001019, 393),
    (400066001394, 400066001, 400066001001, 400066001394, 400066001019, 394),
    (400066001395, 400066001, 400066001001, 400066001395, 400066001019, 395),
    (400066001396, 400066001, 400066001001, 400066001396, 400066001019, 396),
    (400066001397, 400066001, 400066001001, 400066001397, 400066001019, 397),
    (400066001398, 400066001, 400066001001, 400066001398, 400066001019, 398),
    (400066001399, 400066001, 400066001001, 400066001399, 400066001019, 399),
    (400066001400, 400066001, 400066001001, 400066001400, 400066001019, 400),
    (400066001401, 400066001, 400066001001, 400066001401, 400066001019, 401),
    (400066001402, 400066001, 400066001001, 400066001402, 400066001019, 402),
    (400066001403, 400066001, 400066001001, 400066001403, 400066001019, 403),
    (400066001404, 400066001, 400066001001, 400066001404, 400066001020, 404),
    (400066001405, 400066001, 400066001001, 400066001405, 400066001020, 405),
    (400066001406, 400066001, 400066001001, 400066001406, 400066001020, 406),
    (400066001407, 400066001, 400066001001, 400066001407, 400066001021, 407),
    (400066001408, 400066001, 400066001001, 400066001408, 400066001021, 408),
    (400066001409, 400066001, 400066001001, 400066001409, 400066001021, 409),
    (400066001410, 400066001, 400066001001, 400066001410, 400066001021, 410),
    (400066001411, 400066001, 400066001001, 400066001411, 400066001021, 411),
    (400066001412, 400066001, 400066001001, 400066001412, 400066001022, 412),
    (400066001413, 400066001, 400066001001, 400066001413, 400066001022, 413),
    (400066001414, 400066001, 400066001001, 400066001414, 400066001022, 414),
    (400066001415, 400066001, 400066001001, 400066001415, 400066001022, 415),
    (400066001416, 400066001, 400066001001, 400066001416, 400066001023, 416),
    (400066001417, 400066001, 400066001001, 400066001417, 400066001023, 417),
    (400066001418, 400066001, 400066001001, 400066001418, 400066001023, 418),
    (400066001419, 400066001, 400066001001, 400066001419, 400066001023, 419),
    (400066001420, 400066001, 400066001001, 400066001420, 400066001023, 420),
    (400066001421, 400066001, 400066001001, 400066001421, 400066001023, 421),
    (400066001422, 400066001, 400066001001, 400066001422, 400066001023, 422),
    (400066001423, 400066001, 400066001001, 400066001423, 400066001023, 423),
    (400066001424, 400066001, 400066001001, 400066001424, 400066001023, 424),
    (400066001425, 400066001, 400066001001, 400066001425, 400066001023, 425),
    (400066001426, 400066001, 400066001001, 400066001426, 400066001023, 426),
    (400066001427, 400066001, 400066001001, 400066001427, 400066001023, 427),
    (400066001428, 400066001, 400066001001, 400066001428, 400066001023, 428),
    (400066001429, 400066001, 400066001001, 400066001429, 400066001024, 429);

-- ---------------------------------------------------------------------------
-- 9. Post-load assertions (abort + roll back on any mismatch)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    bad text;
BEGIN
    IF (SELECT count(*) FROM menu_category WHERE restaurant_id = 400066001) <> 24 THEN RAISE EXCEPTION 'Row count mismatch in menu_category (expected 24)'; END IF;
    IF (SELECT count(*) FROM menu_item WHERE restaurant_id = 400066001) <> 429 THEN RAISE EXCEPTION 'Row count mismatch in menu_item (expected 429)'; END IF;
    IF (SELECT count(*) FROM menu_item_variant WHERE menu_item_id BETWEEN 400066001001 AND 400066001429) <> 432 THEN RAISE EXCEPTION 'Row count mismatch in menu_item_variant (expected 432)'; END IF;
    IF (SELECT count(*) FROM menu_item_price WHERE price_id BETWEEN 400066001001 AND 400066001431) <> 431 THEN RAISE EXCEPTION 'Row count mismatch in menu_item_price (expected 431)'; END IF;
    IF (SELECT count(*) FROM menu_item_source WHERE source_id = 400066001) <> 429 THEN RAISE EXCEPTION 'Row count mismatch in menu_item_source (expected 429)'; END IF;
    IF (SELECT count(*) FROM menu_item_price_source WHERE source_id = 400066001) <> 431 THEN RAISE EXCEPTION 'Row count mismatch in menu_item_price_source (expected 431)'; END IF;
    IF (SELECT count(*) FROM menu_board_item WHERE restaurant_id = 400066001) <> 429 THEN RAISE EXCEPTION 'Row count mismatch in menu_board_item (expected 429)'; END IF;
    IF (SELECT count(*) FROM menu_board_category WHERE restaurant_id = 400066001) <> 24 THEN RAISE EXCEPTION 'Row count mismatch in menu_board_category (expected 24)'; END IF;
    IF (SELECT count(*) FROM restaurant_hours WHERE restaurant_id = 400066001) <> 7 THEN RAISE EXCEPTION 'Row count mismatch in restaurant_hours (expected 7)'; END IF;
    IF (SELECT count(*) FROM menu_item_availability WHERE availability_id = 400066001001) <> 1 THEN RAISE EXCEPTION 'Row count mismatch in menu_item_availability (expected 1)'; END IF;
    SELECT string_agg(i.menu_item_id::text, ',') INTO bad FROM menu_item i WHERE i.restaurant_id = 400066001
        AND NOT EXISTS (SELECT 1 FROM menu_item_variant v WHERE v.menu_item_id = i.menu_item_id);
    IF bad IS NOT NULL THEN RAISE EXCEPTION 'menu_items without a variant: %', bad; END IF;
    SELECT string_agg(i.menu_item_id::text, ',') INTO bad FROM menu_item i WHERE i.restaurant_id = 400066001 AND i.canonical_dish_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM canonical_dish c WHERE c.canonical_dish_id = i.canonical_dish_id);
    IF bad IS NOT NULL THEN RAISE EXCEPTION 'menu_items with unknown canonical_dish_id: %', bad; END IF;
END $$;

COMMIT;

/* ============================================================================
   TRAILING BLOCK A - rows with verification_status_code = needs_review or confidence < 0.8
   ============================================================================ */
-- menu_item 400066001026 "Tomato Omlet" (South Indian Dishes): needs_review, item confidence 0.90 - Classified 'egg' from the name 'Omlet' inside a restaurant named 'Veg.'; may be a besan/veg omelette
-- menu_item 400066001054 "Omlet Sandwich" (Sandwiches & Grill): needs_review, item confidence 0.90 - Classified 'egg' from the name 'Omlet' inside a restaurant named 'Veg.'; may be a besan/veg omelette
-- menu_item 400066001056 "Toast Omlet Sandwich" (Sandwiches & Grill): needs_review, item confidence 0.90 - Classified 'egg' from the name 'Omlet' inside a restaurant named 'Veg.'; may be a besan/veg omelette
-- menu_item 400066001080 "Butter Pav" (Pav Bhaji): needs_review, item confidence 0.95 - Price 14.00 is far below neighbouring Pav Bhaji items (130-260); may be per-piece or a dropped digit
-- menu_item_price 400066001080 (variant 400066001080, "Butter Pav" 14.00): confidence 0.70, price needs_review - Price 14.00 is far below neighbouring Pav Bhaji items (130-260); may be per-piece or a dropped digit
-- menu_item 400066001373 "Frooti" (Cold Drinks): needs_review, item confidence 0.90 - JSON price is null; item and variant created, no menu_item_price row
-- menu_item 400066001379 "Gulab Jamun" (Lassi): needs_review, item confidence 0.85 - Listed under Lassi in JSON (printed no. 523, out of sequence); kept in that category as transcribed

/* ============================================================================
   TRAILING BLOCK B - restaurant-level notes / JSON content with no schema home (nothing was guessed)
   ============================================================================ */
-- Section note [South Indian Dishes] (pages[1].columns[0].sections[0]): "Extra Sambar & Chatni Rs 10/-"
-- Section note [South Indian Dishes] (pages[1].columns[0].sections[0]): "With Butter Rs. 15/- Extra With Cheese Rs. 40/- Extra"
-- Section note [Dal & Other Indian Dishes] (pages[3].columns[1].sections[0]): "With Butter Rs. 20/- Extra With Cheese Rs. 40/- Extra"
-- Section note [Roti (Tandoori) - continuation] (pages[4].columns[0].sections[0]): "With Butter Rs. 20/- Extra With Cheese Rs. 40/- Extra"
-- Section note [Milk Shakes - continuation] (pages[5].columns[1].sections[0]): "With Ice Cream Rs. 15/- Extra"
-- Section note [Fruit Special] (pages[5].columns[1].sections[1]): "With Ice Cream Rs. 15/- Extra"
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "We Undertake Kitty Parties."
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "We Also Undertake Outdoor Catering"
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "We Provide all the Facilities for all Kind of Functions."
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "Extra Chatni, Sambar & Veg Raitha Will be Charged Rs. 20/-"
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "Buffets Arranged to Your Satisfaction at Reasonable Price"
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "Extra Dry Noodles & Sauce Will be Charged Rs. 20/-"
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "THANK YOU!"
-- Section note [NOTE] (pages[5].columns[1].sections[5]): "VISIT AGAIN !!"
--   -> Priced extras (butter/cheese/sambar/ice cream) were NOT modelled as addon_group/addon_option: the JSON gives
--      no item-level scope. The "With Butter Rs. 20/- Extra With Cheese Rs. 40/- Extra" note is printed under
--      "Dal & Other Indian Dishes" and again under the Roti section; it most likely belongs to the rotis, but
--      the JSON does not say. Confirm scope, then add addon_group / addon_option / menu_item_addon_group.
-- NOTE panel (pages[5].columns[1].sections[5]): "We Undertake Kitty Parties."
-- NOTE panel (pages[5].columns[1].sections[5]): "We Also Undertake Outdoor Catering"
-- NOTE panel (pages[5].columns[1].sections[5]): "We Provide all the Facilities for all Kind of Functions."
-- NOTE panel (pages[5].columns[1].sections[5]): "Extra Chatni, Sambar & Veg Raitha Will be Charged Rs. 20/-"
-- NOTE panel (pages[5].columns[1].sections[5]): "Buffets Arranged to Your Satisfaction at Reasonable Price"
-- NOTE panel (pages[5].columns[1].sections[5]): "Extra Dry Noodles & Sauce Will be Charged Rs. 20/-"
-- NOTE panel (pages[5].columns[1].sections[5]): "THANK YOU!"
-- NOTE panel (pages[5].columns[1].sections[5]): "VISIT AGAIN !!"
--   -> Kitty parties / outdoor catering / buffets / functions are service statements (restaurant_service_mode
--      bulk_catering exists as a lookup row, but the JSON does not tie them to a service mode, so none was set).
-- INTERNAL CONFLICT: "Extra Sambar & Chatni Rs 10/-" (South Indian Dishes) vs "Extra Chatni, Sambar & Veg Raitha
--      Will be Charged Rs. 20/-" (NOTE panel). Not resolved; both are recorded here only.
-- Printed item numbers (the "no" field) have no column and were not stored. Printed number 380 is shared by the
--      Cold Drinks 200 ml / 500 ml lines (merged into one item); printed number 386 is used twice for different
--      dishes (Veg. Chop. Masala and Pineapple Milk Shake).
-- Restaurant name says "Veg." but the menu has three Omlet items (classified egg, needs_review);
--      restaurant.veg_nonveg_status was therefore left NULL and no PURE_VEG restaurant_tag was added.
-- Not present in the JSON, left NULL/default: phone numbers, GST/tax, bar licence, delivery partners
--      (delivery_partners_visible_in_text_or_logos = []), delivery radius / minimum order, kitchen closing time.
-- Jain options exist (Jain Pav Bhaji, Jain Cheese Pav Bhaji, Jain Bhaji -> is_jain TRUE); no restaurant_tag
--      JAIN_AVAILABLE was inserted because tags are only attached when the JSON states them for the restaurant.
-- Same dish name, different price in different sections (inserted as separate items, per the standing rule):
--      Mushroom Manchurian: Starter = 285.00; Chinese Dishes Vegetable = 280.00
--      Baby Corn Manchurian: Starter = 265.00; Chinese Dishes Vegetable = 270.00
--      Paneer Manchurian: Starter = 275.00; Chinese Dishes Vegetable = 270.00
-- Thali contents (Paneer Bhaji, Mix Veg, Dal Fry, Jeera Rice, Veg Raita, Gulab Jamun, Rosted Papad, Roti / Chapati /
--      Puri (Any One)) are stored only as bundle.description; no component menu_items were created.
