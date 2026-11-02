/* ============================================================================
   KHAUSTAN -- RESTAURANT ONBOARDING (JSON source): Rangoon Zaika
   Source: Rangoon_Zaika_text_menu.json (pandoc AST of the restaurant's take-away menu)
   Target: KhaustanRestaurantMenu database.
   Built against the schema-resolved JSON->Postgres methodology document
   supplied with this request. ESTABLISHMENT_ID = 400070007.

   JSON-ONLY SOURCING: per the methodology's explicit rule, nothing here
   uses outside knowledge of this restaurant, including facts recorded in
   this session's own memory from an earlier docx-based version of this
   same restaurant (a different address was on file there -- "Wing 5B,
   Lal Bahadur Shastri Marg" -- vs. this JSON's own "Shop No. 4B-4C, Opp.
   Kalpana Cinema, Beside Ansari Weight Bridge, L.B.S. Marg"). This script
   uses only what the attached JSON itself states; the discrepancy is
   flagged, not resolved by picking one.

   DEVIATION FROM THE METHODOLOGY DOCUMENT, FLAGGED PER ITS OWN RULE
   ("if you spot something wrong, say so"): Step 7's template opens with
   \connect "KhaustanRestaurantMenu" -- that's a psql-only meta-command,
   confirmed not valid in pgAdmin4's Query Tool earlier this session (the
   exact error that had to be fixed on three earlier scripts). Omitted here
   the same way; connect the Query Tool to that database directly first.

   ID NAMESPACE: establishment_id = restaurant_id = source_id = 400070007.
   menu_board/menu_category/menu_item/variant/price/availability/board_item
   each have their own counter starting at 400070007001 and incrementing by 1
   within that table only (so, e.g., the first menu_item and the first
   menu_category are both 400070007001 -- same number, different tables, no
   collision, per the spec). menu_item_source has no id of its own (uses
   menu_item_id); menu_board_category has no id of its own (uses
   restaurant_id + menu_board_id + menu_category_id). Everything NOT in
   that mandatory list (restaurant_phone_id, restaurant_hours_id,
   menu_extraction_batch_id, canonical_dish_id, canonical_dish_name_id,
   restaurant_delivery_provider_id) uses a separate sequence, per the
   methodology's own instruction to keep those out of the deterministic
   namespace.

   LOOKUP TABLES: read-only, nothing inserted. Delivery: the JSON states
   "ORDER ONLINE ON: ZOMATO | SWIGGY" directly (stronger than an inferred
   mention), so both are linked via restaurant_delivery_provider, matched
   by provider_code. "FREE DELIVERY" is also stated -- self-delivery is
   recorded too, with no minimum order given anywhere in the JSON (left NULL).

   UNMAPPED / NO SCHEMA HOME: HALAL marking (no allergen/cert column and no
   confirmed HALAL platform_tag to match -- flagged, not guessed); GST No.
   27BMKPK2607N1ZP and FSSAI Lic No. 11518007000075 (no column for a
   registration number); email/website/Instagram handles (no columns);
   "AC PARTY HALL", "FAMILY DASTARKHWAN", "OUTDOOR CATERING SERVICE" and
   proprietor name Javed Khan (folded into restaurant.description instead,
   no dedicated columns); no operating hours stated anywhere in the JSON,
   so restaurant_hours is not populated ("FREE DELIVERY" alone isn't hours).
   ============================================================================ */

-- pgAdmin4 / any plain SQL client: connect to "KhaustanRestaurantMenu" directly
-- before running this (no \connect meta-command -- see the deviation note above).

BEGIN;

-- Sequence for ids explicitly excluded from the mandatory deterministic namespace.
DO $do$
DECLARE v_max BIGINT;
BEGIN
  SELECT GREATEST(
    COALESCE((SELECT MAX(restaurant_phone_id) FROM restaurant_phone), 0),
    COALESCE((SELECT MAX(extraction_batch_id) FROM menu_extraction_batch), 0),
    COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
    COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0),
    COALESCE((SELECT MAX(restaurant_delivery_provider_id) FROM restaurant_delivery_provider), 0)
  ) INTO v_max;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS rangoon_other_id_seq START WITH %s', v_max + 1);
END $do$;

-- Re-run guard: stop if this exact source has already been fully loaded for this restaurant.
DO $do$
DECLARE v_already_done BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM menu_extraction_batch
    WHERE restaurant_id = 400070007
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Rangoon_Zaika_text_menu.json')
      AND status_code = 'completed'
  ) INTO v_already_done;
  IF v_already_done THEN
    RAISE EXCEPTION 'Rangoon_Zaika_text_menu.json already fully loaded for restaurant 400070007 -- aborting to avoid duplicate menu items.';
  END IF;
END $do$;

INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2, locality, city, state, country_code, postal_code, latitude, longitude)
VALUES (400070007, 'Rangoon Zaika', 'rangoon zaika',
        'Shop No. 4B-4C, Opp. Kalpana Cinema', 'Beside Ansari Weight Bridge, L.B.S. Marg',
        'Kurla (West)', 'Mumbai', 'Maharashtra', 'IN', '400070', 19.077009592206522, 72.87795096152591);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, description, has_bar, bar_license_type)
VALUES (400070007, 400070007, 'Rangoon Zaika', 'rangoon zaika', '"Authentic Tawa & Grill Taste -- The Pleasure Of Variety On Your Plate." AC party hall, family dastarkhwan, outdoor catering service. Proprietor: Javed Khan. Halal, no beef.', FALSE, 'none');

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400070007, 'ai_menu_extraction', 'Rangoon_Zaika_text_menu.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
VALUES (400070007500, 400070007, 400070007, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

-- Three phone numbers, all printed together under the header with no individual labels --
-- first one marked primary as a reasonable default, not because the JSON singles it out.
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary, is_personal_number)
VALUES (nextval('rangoon_other_id_seq'), 400070007, '9967294173', TRUE, FALSE),
       (nextval('rangoon_other_id_seq'), 400070007, '9619164173', FALSE, FALSE),
       (nextval('rangoon_other_id_seq'), 400070007, '9820299018', FALSE, FALSE);

-- "FREE DELIVERY" stated; no minimum order amount given anywhere in the JSON.
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, currency_code)
VALUES (400070007, TRUE, TRUE, 'INR');

-- "ORDER ONLINE ON: ZOMATO | SWIGGY" -- stated directly, not inferred.
INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, effective_from)
SELECT nextval('rangoon_other_id_seq'), 400070007, dp.delivery_provider_id, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM delivery_provider dp WHERE dp.provider_code IN ('ZOMATO', 'SWIGGY');

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, notes)
VALUES (400070007, 1, 'AC party hall / family dastarkhwan seating stated on the menu'),
       (400070007, 3, 'TAKE AWAY MENU is this document''s own title'),
       (400070007, 4, 'FREE DELIVERY stated; ZOMATO/SWIGGY also linked'),
       (400070007, 5, 'AC party hall, family dastarkhwan, outdoor catering service stated on the menu');

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
VALUES (400070007001, 400070007, 'Rangoon Zaika Menu', 'a_la_carte');

INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
VALUES
    (400070007001, 400070007, 'B.L Tandoori Starter', 1),
    (400070007002, 400070007, 'Tandoori Starter', 2),
    (400070007003, 400070007, 'Chicken Gravy', 3),
    (400070007004, 400070007, 'Mutton Gravy', 4),
    (400070007005, 400070007, 'Paneer Gravy', 5),
    (400070007006, 400070007, 'Mutton Tandoori Starters', 6),
    (400070007007, 400070007, 'Mutton Tawa', 7),
    (400070007008, 400070007, 'Dal', 8),
    (400070007009, 400070007, 'Rice', 9),
    (400070007010, 400070007, 'Roti', 10),
    (400070007011, 400070007, 'Mutton Biryani', 11),
    (400070007012, 400070007, 'Chicken Biryani', 12),
    (400070007013, 400070007, 'Sea Food Biryani', 13),
    (400070007014, 400070007, 'Paneer Biryani', 14),
    (400070007015, 400070007, 'Mughlai Khepsa', 15),
    (400070007016, 400070007, 'Sea Food Starter', 16),
    (400070007017, 400070007, 'Fish Gravy', 17),
    (400070007018, 400070007, 'Chinese Soup', 18),
    (400070007019, 400070007, 'Chinese Starter', 19),
    (400070007020, 400070007, 'Chinese Rice With Masala', 20),
    (400070007021, 400070007, 'Chinese Khepsa', 21),
    (400070007022, 400070007, 'Chinese Biryani', 22),
    (400070007023, 400070007, 'Chinese Gravy', 23),
    (400070007024, 400070007, 'Chinese Rice', 24),
    (400070007025, 400070007, 'Chinese Noodles', 25),
    (400070007026, 400070007, 'Dessert', 26);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400070007, 400070007001, 400070007001, 1),
    (400070007, 400070007001, 400070007002, 2),
    (400070007, 400070007001, 400070007003, 3),
    (400070007, 400070007001, 400070007004, 4),
    (400070007, 400070007001, 400070007005, 5),
    (400070007, 400070007001, 400070007006, 6),
    (400070007, 400070007001, 400070007007, 7),
    (400070007, 400070007001, 400070007008, 8),
    (400070007, 400070007001, 400070007009, 9),
    (400070007, 400070007001, 400070007010, 10),
    (400070007, 400070007001, 400070007011, 11),
    (400070007, 400070007001, 400070007012, 12),
    (400070007, 400070007001, 400070007013, 13),
    (400070007, 400070007001, 400070007014, 14),
    (400070007, 400070007001, 400070007015, 15),
    (400070007, 400070007001, 400070007016, 16),
    (400070007, 400070007001, 400070007017, 17),
    (400070007, 400070007001, 400070007018, 18),
    (400070007, 400070007001, 400070007019, 19),
    (400070007, 400070007001, 400070007020, 20),
    (400070007, 400070007001, 400070007021, 21),
    (400070007, 400070007001, 400070007022, 22),
    (400070007, 400070007001, 400070007023, 23),
    (400070007, 400070007001, 400070007024, 24),
    (400070007, 400070007001, 400070007025, 25),
    (400070007, 400070007001, 400070007026, 26);

-- ----------------------------------------------------------------------------
-- Canonical dishes: 233 distinct names across 251 menu lines
-- (own sequence, per the methodology's own note that canonical_dish is not
-- part of the mandatory restaurant/menu child-ID namespace).
-- ----------------------------------------------------------------------------
WITH new_dish_90397521 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tikka (6 Pcs)', 'chicken tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka (6 Pcs)', 'chicken tikka (6 pcs)', 'primary'
FROM new_dish_90397521;

WITH new_dish_91113320 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Malai Tikka (6 Pcs)', 'malai tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Malai Tikka (6 Pcs)', 'malai tikka (6 pcs)', 'primary'
FROM new_dish_91113320;

WITH new_dish_88387551 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Pahadi Tikka (6 Pcs)', 'pahadi tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pahadi tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Pahadi Tikka (6 Pcs)', 'pahadi tikka (6 pcs)', 'primary'
FROM new_dish_88387551;

WITH new_dish_14344921 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Peshawari / Reshmi Tikka (6 Pcs)', 'peshawari / reshmi tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peshawari / reshmi tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Peshawari / Reshmi Tikka (6 Pcs)', 'peshawari / reshmi tikka (6 pcs)', 'primary'
FROM new_dish_14344921;

WITH new_dish_88073710 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Kalimiri Tikka (6 Pcs)', 'kalimiri tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kalimiri tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Kalimiri Tikka (6 Pcs)', 'kalimiri tikka (6 pcs)', 'primary'
FROM new_dish_88073710;

WITH new_dish_27136639 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Amul Dahi Tikka (6 Pcs)', 'amul dahi tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'amul dahi tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Amul Dahi Tikka (6 Pcs)', 'amul dahi tikka (6 pcs)', 'primary'
FROM new_dish_27136639;

WITH new_dish_96200258 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Banjara Tikka (6 Pcs)', 'banjara tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'banjara tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Banjara Tikka (6 Pcs)', 'banjara tikka (6 pcs)', 'primary'
FROM new_dish_96200258;

WITH new_dish_57525920 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Garlic Tikka (6 Pcs)', 'garlic tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Garlic Tikka (6 Pcs)', 'garlic tikka (6 pcs)', 'primary'
FROM new_dish_57525920;

WITH new_dish_86260186 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Achari Tikka (6 Pcs)', 'achari tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'achari tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Achari Tikka (6 Pcs)', 'achari tikka (6 pcs)', 'primary'
FROM new_dish_86260186;

WITH new_dish_38734442 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Italian Tikka (6 Pcs)', 'italian tikka (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'italian tikka (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Italian Tikka (6 Pcs)', 'italian tikka (6 pcs)', 'primary'
FROM new_dish_38734442;

WITH new_dish_79315977 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chk Seekh (3Pcs/6Pcs)', 'chk seekh (3pcs/6pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chk seekh (3pcs/6pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chk Seekh (3Pcs/6Pcs)', 'chk seekh (3pcs/6pcs)', 'primary'
FROM new_dish_79315977;

WITH new_dish_47711283 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chk Cheese Seekh (3Pcs/6Pcs)', 'chk cheese seekh (3pcs/6pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chk cheese seekh (3pcs/6pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chk Cheese Seekh (3Pcs/6Pcs)', 'chk cheese seekh (3pcs/6pcs)', 'primary'
FROM new_dish_47711283;

WITH new_dish_75830725 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Malai Seekh Barrah (3Pcs/6Pcs)', 'malai seekh barrah (3pcs/6pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai seekh barrah (3pcs/6pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Malai Seekh Barrah (3Pcs/6Pcs)', 'malai seekh barrah (3pcs/6pcs)', 'primary'
FROM new_dish_75830725;

WITH new_dish_85278510 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tandoori', 'chicken tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori', 'chicken tandoori', 'primary'
FROM new_dish_85278510;

WITH new_dish_15242750 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tandoori Butter', 'chicken tandoori butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Butter', 'chicken tandoori butter', 'primary'
FROM new_dish_15242750;

WITH new_dish_67008803 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tandoori Schezwan', 'chicken tandoori schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Schezwan', 'chicken tandoori schezwan', 'primary'
FROM new_dish_67008803;

WITH new_dish_5783391 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Kalimiri Tandoori', 'chicken kalimiri tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kalimiri tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kalimiri Tandoori', 'chicken kalimiri tandoori', 'primary'
FROM new_dish_5783391;

WITH new_dish_26073646 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tandoori Lemon', 'chicken tandoori lemon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori lemon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Lemon', 'chicken tandoori lemon', 'primary'
FROM new_dish_26073646;

WITH new_dish_79972636 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Afghani Tandoori', 'chicken afghani tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afghani tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Afghani Tandoori', 'chicken afghani tandoori', 'primary'
FROM new_dish_79972636;

WITH new_dish_10345378 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Banjara Tandoori', 'chicken banjara tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken banjara tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Banjara Tandoori', 'chicken banjara tandoori', 'primary'
FROM new_dish_10345378;

WITH new_dish_16870186 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tandoor Barrah', 'chicken tandoor barrah'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoor barrah')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoor Barrah', 'chicken tandoor barrah', 'primary'
FROM new_dish_16870186;

WITH new_dish_65281483 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Peshawari Tandoori', 'chicken peshawari tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken peshawari tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Peshawari Tandoori', 'chicken peshawari tandoori', 'primary'
FROM new_dish_65281483;

WITH new_dish_42606962 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chk Tandoori Cream Barra', 'chk tandoori cream barra'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chk tandoori cream barra')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chk Tandoori Cream Barra', 'chk tandoori cream barra', 'primary'
FROM new_dish_42606962;

WITH new_dish_88654002 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Tandoori (8 Pcs)', 'lollipop tandoori (8 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop tandoori (8 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Tandoori (8 Pcs)', 'lollipop tandoori (8 pcs)', 'primary'
FROM new_dish_88654002;

WITH new_dish_81150952 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tandoori Leg / Breast', 'tandoori leg / breast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori leg / breast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Leg / Breast', 'tandoori leg / breast', 'primary'
FROM new_dish_81150952;

WITH new_dish_37792782 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Spl Platters', 'rangoon spl platters'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon spl platters')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Spl Platters', 'rangoon spl platters', 'primary'
FROM new_dish_37792782;

WITH new_dish_56816467 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Do Pyaza', 'chicken do pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken do pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Do Pyaza', 'chicken do pyaza', 'primary'
FROM new_dish_56816467;

WITH new_dish_69394209 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Korma', 'chicken korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Korma', 'chicken korma', 'primary'
FROM new_dish_69394209;

WITH new_dish_70156131 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Akbari', 'chicken akbari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken akbari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Akbari', 'chicken akbari', 'primary'
FROM new_dish_70156131;

WITH new_dish_14128658 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Kofta', 'chicken kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kofta', 'chicken kofta', 'primary'
FROM new_dish_14128658;

WITH new_dish_88674338 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Cream Tawa', 'chicken cream tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken cream tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Cream Tawa', 'chicken cream tawa', 'primary'
FROM new_dish_88674338;

WITH new_dish_89374844 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken White Korma', 'chicken white korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken white korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken White Korma', 'chicken white korma', 'primary'
FROM new_dish_89374844;

WITH new_dish_21269692 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Afghani', 'chicken afghani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afghani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Afghani', 'chicken afghani', 'primary'
FROM new_dish_21269692;

WITH new_dish_49080167 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Lahori', 'chicken lahori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lahori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Lahori', 'chicken lahori', 'primary'
FROM new_dish_49080167;

WITH new_dish_59317207 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Kashmiri', 'chicken kashmiri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kashmiri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kashmiri', 'chicken kashmiri', 'primary'
FROM new_dish_59317207;

WITH new_dish_49758228 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Patiala', 'chicken patiala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken patiala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Patiala', 'chicken patiala', 'primary'
FROM new_dish_49758228;

WITH new_dish_57580206 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Laziz', 'chicken laziz'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken laziz')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Laziz', 'chicken laziz', 'primary'
FROM new_dish_57580206;

WITH new_dish_33981562 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Lajawab', 'chicken lajawab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lajawab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Lajawab', 'chicken lajawab', 'primary'
FROM new_dish_33981562;

WITH new_dish_97855591 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Malai Kofta', 'chicken malai kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Malai Kofta', 'chicken malai kofta', 'primary'
FROM new_dish_97855591;

WITH new_dish_75166615 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Angara', 'chicken angara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken angara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Angara', 'chicken angara', 'primary'
FROM new_dish_75166615;

WITH new_dish_55144589 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Aflatoon', 'chicken aflatoon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken aflatoon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Aflatoon', 'chicken aflatoon', 'primary'
FROM new_dish_55144589;

WITH new_dish_4091506 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Murg Musallam', 'murg musallam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg musallam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Murg Musallam', 'murg musallam', 'primary'
FROM new_dish_4091506;

WITH new_dish_12732322 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Handi', 'chicken handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Handi', 'chicken handi', 'primary'
FROM new_dish_12732322;

WITH new_dish_99054738 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Bhuna', 'chicken bhuna'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken bhuna')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Bhuna', 'chicken bhuna', 'primary'
FROM new_dish_99054738;

WITH new_dish_67646746 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Kadai', 'chicken kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kadai', 'chicken kadai', 'primary'
FROM new_dish_67646746;

WITH new_dish_49451251 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Masala', 'chicken masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Masala', 'chicken masala', 'primary'
FROM new_dish_49451251;

WITH new_dish_15129365 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Butter Chicken', 'butter chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Butter Chicken', 'butter chicken', 'primary'
FROM new_dish_15129365;

WITH new_dish_71773871 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Changezi', 'chicken changezi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken changezi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Changezi', 'chicken changezi', 'primary'
FROM new_dish_71773871;

WITH new_dish_15726876 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Dal Gosht', 'mutton dal gosht'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dal gosht')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Dal Gosht', 'mutton dal gosht', 'primary'
FROM new_dish_15726876;

WITH new_dish_67472680 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Handi', 'mutton handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Handi', 'mutton handi', 'primary'
FROM new_dish_67472680;

WITH new_dish_33360232 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Bhuna', 'mutton bhuna'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton bhuna')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Bhuna', 'mutton bhuna', 'primary'
FROM new_dish_33360232;

WITH new_dish_40114953 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Kadai', 'mutton kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Kadai', 'mutton kadai', 'primary'
FROM new_dish_40114953;

WITH new_dish_81541289 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Masala', 'mutton masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Masala', 'mutton masala', 'primary'
FROM new_dish_81541289;

WITH new_dish_82813254 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Changezi', 'mutton changezi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton changezi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Changezi', 'mutton changezi', 'primary'
FROM new_dish_82813254;

WITH new_dish_64142526 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Do Pyaza', 'mutton do pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton do pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Do Pyaza', 'mutton do pyaza', 'primary'
FROM new_dish_64142526;

WITH new_dish_5568245 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Korma', 'mutton korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Korma', 'mutton korma', 'primary'
FROM new_dish_5568245;

WITH new_dish_68369424 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Akbari', 'mutton akbari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton akbari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Akbari', 'mutton akbari', 'primary'
FROM new_dish_68369424;

WITH new_dish_94366860 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Cream Tawa', 'mutton cream tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton cream tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Cream Tawa', 'mutton cream tawa', 'primary'
FROM new_dish_94366860;

WITH new_dish_73058273 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Afghani', 'mutton afghani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton afghani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Afghani', 'mutton afghani', 'primary'
FROM new_dish_73058273;

WITH new_dish_80908489 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Lahori', 'mutton lahori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lahori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Lahori', 'mutton lahori', 'primary'
FROM new_dish_80908489;

WITH new_dish_30259780 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Kashmiri', 'mutton kashmiri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kashmiri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Kashmiri', 'mutton kashmiri', 'primary'
FROM new_dish_30259780;

WITH new_dish_71511307 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Patiala', 'mutton patiala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton patiala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Patiala', 'mutton patiala', 'primary'
FROM new_dish_71511307;

WITH new_dish_3145602 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Laziz', 'mutton laziz'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton laziz')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Laziz', 'mutton laziz', 'primary'
FROM new_dish_3145602;

WITH new_dish_83596645 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Shahi Korma', 'mutton shahi korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton shahi korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Shahi Korma', 'mutton shahi korma', 'primary'
FROM new_dish_83596645;

WITH new_dish_14070053 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Lajawab', 'mutton lajawab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lajawab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Lajawab', 'mutton lajawab', 'primary'
FROM new_dish_14070053;

WITH new_dish_46412788 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Malai Kofta', 'mutton malai kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton malai kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Malai Kofta', 'mutton malai kofta', 'primary'
FROM new_dish_46412788;

WITH new_dish_85778102 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Angara', 'mutton angara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton angara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Angara', 'mutton angara', 'primary'
FROM new_dish_85778102;

WITH new_dish_3823987 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Aflatoon', 'mutton aflatoon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton aflatoon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Aflatoon', 'mutton aflatoon', 'primary'
FROM new_dish_3823987;

WITH new_dish_63863133 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Kadai', 'paneer kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Kadai', 'paneer kadai', 'primary'
FROM new_dish_63863133;

WITH new_dish_13403191 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Masala', 'paneer masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Masala', 'paneer masala', 'primary'
FROM new_dish_13403191;

WITH new_dish_33258992 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Mutter', 'paneer mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Mutter', 'paneer mutter', 'primary'
FROM new_dish_33258992;

WITH new_dish_19704716 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Changezi', 'paneer changezi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer changezi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Changezi', 'paneer changezi', 'primary'
FROM new_dish_19704716;

WITH new_dish_92438553 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Makhamwala', 'paneer makhamwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhamwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Makhamwala', 'paneer makhamwala', 'primary'
FROM new_dish_92438553;

WITH new_dish_61722942 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Do Pyaza', 'paneer do pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer do pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Do Pyaza', 'paneer do pyaza', 'primary'
FROM new_dish_61722942;

WITH new_dish_11782082 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Cream Tawa', 'paneer cream tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer cream tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Cream Tawa', 'paneer cream tawa', 'primary'
FROM new_dish_11782082;

WITH new_dish_89424951 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Shahi Korma', 'paneer shahi korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer shahi korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Shahi Korma', 'paneer shahi korma', 'primary'
FROM new_dish_89424951;

WITH new_dish_87288551 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Afghani', 'paneer afghani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer afghani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Afghani', 'paneer afghani', 'primary'
FROM new_dish_87288551;

WITH new_dish_24861912 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Lajawab', 'paneer lajawab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lajawab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Lajawab', 'paneer lajawab', 'primary'
FROM new_dish_24861912;

WITH new_dish_56143725 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Barra (6Pcs/12Pcs)', 'mutton barra (6pcs/12pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton barra (6pcs/12pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Barra (6Pcs/12Pcs)', 'mutton barra (6pcs/12pcs)', 'primary'
FROM new_dish_56143725;

WITH new_dish_13891501 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Cream Barra (6Pcs/12Pcs)', 'cream barra (6pcs/12pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream barra (6pcs/12pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Cream Barra (6Pcs/12Pcs)', 'cream barra (6pcs/12pcs)', 'primary'
FROM new_dish_13891501;

WITH new_dish_683401 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Tawa Dry (7Pcs/14Pcs)', 'mutton tawa dry (7pcs/14pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton tawa dry (7pcs/14pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Tawa Dry (7Pcs/14Pcs)', 'mutton tawa dry (7pcs/14pcs)', 'primary'
FROM new_dish_683401;

WITH new_dish_98103677 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Kalimiri Dry (7Pcs/14Pcs)', 'kalimiri dry (7pcs/14pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kalimiri dry (7pcs/14pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Kalimiri Dry (7Pcs/14Pcs)', 'kalimiri dry (7pcs/14pcs)', 'primary'
FROM new_dish_98103677;

WITH new_dish_5494881 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tomato Onion Dry (7Pcs/14Pcs)', 'tomato onion dry (7pcs/14pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato onion dry (7pcs/14pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tomato Onion Dry (7Pcs/14Pcs)', 'tomato onion dry (7pcs/14pcs)', 'primary'
FROM new_dish_5494881;

WITH new_dish_86990371 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Schezwan Dry (7Pcs/14Pcs)', 'schezwan dry (7pcs/14pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan dry (7pcs/14pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Schezwan Dry (7Pcs/14Pcs)', 'schezwan dry (7pcs/14pcs)', 'primary'
FROM new_dish_86990371;

WITH new_dish_71971921 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dal Fry', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary'
FROM new_dish_71971921;

WITH new_dish_87158434 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dal Tadka', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary'
FROM new_dish_87158434;

WITH new_dish_82828093 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dal Khichdi', 'dal khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi', 'dal khichdi', 'primary'
FROM new_dish_82828093;

WITH new_dish_7091753 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dal Khichdi Tadka', 'dal khichdi tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi Tadka', 'dal khichdi tadka', 'primary'
FROM new_dish_7091753;

WITH new_dish_80035760 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Plain Rice', 'plain rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Plain Rice', 'plain rice', 'primary'
FROM new_dish_80035760;

WITH new_dish_3272449 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lemon Rice', 'lemon rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lemon Rice', 'lemon rice', 'primary'
FROM new_dish_3272449;

WITH new_dish_763570 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Jeera Rice', 'jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary'
FROM new_dish_763570;

WITH new_dish_55783747 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Plain Butter Rice', 'plain butter rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain butter rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Plain Butter Rice', 'plain butter rice', 'primary'
FROM new_dish_55783747;

WITH new_dish_37167486 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tandoori Roti', 'tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Roti', 'tandoori roti', 'primary'
FROM new_dish_37167486;

WITH new_dish_86656867 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Kamachi Roti', 'kamachi roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kamachi roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Kamachi Roti', 'kamachi roti', 'primary'
FROM new_dish_86656867;

WITH new_dish_641738 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Butter Roti', 'butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Butter Roti', 'butter roti', 'primary'
FROM new_dish_641738;

WITH new_dish_36101560 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Butter Naan', 'butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary'
FROM new_dish_36101560;

WITH new_dish_34013102 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lachha Paratha', 'lachha paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lachha paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lachha Paratha', 'lachha paratha', 'primary'
FROM new_dish_34013102;

WITH new_dish_86334847 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Garlic Naan', 'garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Garlic Naan', 'garlic naan', 'primary'
FROM new_dish_86334847;

WITH new_dish_6841641 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Butter Garlic Naan', 'butter garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Butter Garlic Naan', 'butter garlic naan', 'primary'
FROM new_dish_6841641;

WITH new_dish_61320840 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Biryani', 'mutton biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Biryani', 'mutton biryani', 'primary'
FROM new_dish_61320840;

WITH new_dish_59786547 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Pulao', 'mutton pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Pulao', 'mutton pulao', 'primary'
FROM new_dish_59786547;

WITH new_dish_46198088 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Malai Biryani', 'mutton malai biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton malai biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Malai Biryani', 'mutton malai biryani', 'primary'
FROM new_dish_46198088;

WITH new_dish_70321918 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Biryani', 'chicken biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani', 'chicken biryani', 'primary'
FROM new_dish_70321918;

WITH new_dish_36023153 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Tikka Biryani', 'chicken tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Biryani', 'chicken tikka biryani', 'primary'
FROM new_dish_36023153;

WITH new_dish_14341449 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Seekh Biryani', 'chicken seekh biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken seekh biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Seekh Biryani', 'chicken seekh biryani', 'primary'
FROM new_dish_14341449;

WITH new_dish_4684059 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Malai Tikka Biryani', 'chicken malai tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Malai Tikka Biryani', 'chicken malai tikka biryani', 'primary'
FROM new_dish_4684059;

WITH new_dish_92916221 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Pulao', 'chicken pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Pulao', 'chicken pulao', 'primary'
FROM new_dish_92916221;

WITH new_dish_4820475 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Malai Seekh Biryani', 'chicken malai seekh biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai seekh biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Malai Seekh Biryani', 'chicken malai seekh biryani', 'primary'
FROM new_dish_4820475;

WITH new_dish_67747097 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Cheese Seekh Biryani', 'chicken cheese seekh biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken cheese seekh biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Cheese Seekh Biryani', 'chicken cheese seekh biryani', 'primary'
FROM new_dish_67747097;

WITH new_dish_29227131 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Malai Cheese Seekh Biryani', 'chicken malai cheese seekh biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai cheese seekh biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Malai Cheese Seekh Biryani', 'chicken malai cheese seekh biryani', 'primary'
FROM new_dish_29227131;

WITH new_dish_90599582 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Egg Biryani', 'egg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Egg Biryani', 'egg biryani', 'primary'
FROM new_dish_90599582;

WITH new_dish_26349267 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Biryani', 'prawns biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Biryani', 'prawns biryani', 'primary'
FROM new_dish_26349267;

WITH new_dish_73642458 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Pulao', 'prawns pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Pulao', 'prawns pulao', 'primary'
FROM new_dish_73642458;

WITH new_dish_38717597 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Fish Biryani', 'fish biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Fish Biryani', 'fish biryani', 'primary'
FROM new_dish_38717597;

WITH new_dish_38217108 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Biryani', 'paneer biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Biryani', 'paneer biryani', 'primary'
FROM new_dish_38217108;

WITH new_dish_88090596 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Pulao', 'paneer pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Pulao', 'paneer pulao', 'primary'
FROM new_dish_88090596;

WITH new_dish_96160973 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tandoori Khepsa', 'tandoori khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Khepsa', 'tandoori khepsa', 'primary'
FROM new_dish_96160973;

WITH new_dish_65436077 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Arabian Khepsa', 'arabian khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Arabian Khepsa', 'arabian khepsa', 'primary'
FROM new_dish_65436077;

WITH new_dish_62354394 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Special Khepsa', 'rangoon special khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon special khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Special Khepsa', 'rangoon special khepsa', 'primary'
FROM new_dish_62354394;

WITH new_dish_26357118 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Crispy Dry', 'prawns crispy dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns crispy dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Crispy Dry', 'prawns crispy dry', 'primary'
FROM new_dish_26357118;

WITH new_dish_28285722 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Chilly Dry', 'prawns chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Chilly Dry', 'prawns chilly dry', 'primary'
FROM new_dish_28285722;

WITH new_dish_69480600 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns 65 Dry', 'prawns 65 dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns 65 dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns 65 Dry', 'prawns 65 dry', 'primary'
FROM new_dish_69480600;

WITH new_dish_75625903 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Koliwada Oil Fry', 'prawns koliwada oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Koliwada Oil Fry', 'prawns koliwada oil fry', 'primary'
FROM new_dish_75625903;

WITH new_dish_39965483 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Koliwada Dry', 'prawns koliwada dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Koliwada Dry', 'prawns koliwada dry', 'primary'
FROM new_dish_39965483;

WITH new_dish_82537633 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Periperi Dry', 'prawns periperi dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns periperi dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Periperi Dry', 'prawns periperi dry', 'primary'
FROM new_dish_82537633;

WITH new_dish_17712457 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Tomato Dry', 'prawns tomato dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns tomato dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Tomato Dry', 'prawns tomato dry', 'primary'
FROM new_dish_17712457;

WITH new_dish_34066940 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rawas Oil Fry', 'rawas oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rawas Oil Fry', 'rawas oil fry', 'primary'
FROM new_dish_34066940;

WITH new_dish_14883977 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rawas Tikka', 'rawas tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rawas Tikka', 'rawas tikka', 'primary'
FROM new_dish_14883977;

WITH new_dish_80377440 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rawas Butter Tawa', 'rawas butter tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas butter tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rawas Butter Tawa', 'rawas butter tawa', 'primary'
FROM new_dish_80377440;

WITH new_dish_22438271 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rawas Changezi', 'rawas changezi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas changezi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rawas Changezi', 'rawas changezi', 'primary'
FROM new_dish_22438271;

WITH new_dish_62345025 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Butter Tawa', 'prawns butter tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns butter tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Butter Tawa', 'prawns butter tawa', 'primary'
FROM new_dish_62345025;

WITH new_dish_37432699 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Changezi', 'prawns changezi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns changezi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Changezi', 'prawns changezi', 'primary'
FROM new_dish_37432699;

WITH new_dish_98862937 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Spl Prawns Tawa', 'rangoon spl prawns tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon spl prawns tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Spl Prawns Tawa', 'rangoon spl prawns tawa', 'primary'
FROM new_dish_98862937;

WITH new_dish_7745733 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Spl Rawas Tawa', 'rangoon spl rawas tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon spl rawas tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Spl Rawas Tawa', 'rangoon spl rawas tawa', 'primary'
FROM new_dish_7745733;

WITH new_dish_72520705 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Manchow Soup', 'manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Manchow Soup', 'manchow soup', 'primary'
FROM new_dish_72520705;

WITH new_dish_20088489 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Hot & Sour Soup', 'hot & sour soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot & sour soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Hot & Sour Soup', 'hot & sour soup', 'primary'
FROM new_dish_20088489;

WITH new_dish_88481222 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Clear Soup', 'clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Clear Soup', 'clear soup', 'primary'
FROM new_dish_88481222;

WITH new_dish_39334335 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Noodles Soup', 'noodles soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'noodles soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Noodles Soup', 'noodles soup', 'primary'
FROM new_dish_39334335;

WITH new_dish_2563725 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Sweet Corn Soup', 'sweet corn soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet corn soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Sweet Corn Soup', 'sweet corn soup', 'primary'
FROM new_dish_2563725;

WITH new_dish_80686353 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Kasoori Soup', 'kasoori soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kasoori soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Kasoori Soup', 'kasoori soup', 'primary'
FROM new_dish_80686353;

WITH new_dish_49525316 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Soup', 'mutton soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Soup', 'mutton soup', 'primary'
FROM new_dish_49525316;

WITH new_dish_30794892 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Spl Soup', 'rangoon spl soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon spl soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Spl Soup', 'rangoon spl soup', 'primary'
FROM new_dish_30794892;

WITH new_dish_84344119 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Oil Fry', 'lollipop oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Oil Fry', 'lollipop oil fry', 'primary'
FROM new_dish_84344119;

WITH new_dish_37679243 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Egg Fry', 'lollipop egg fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop egg fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Egg Fry', 'lollipop egg fry', 'primary'
FROM new_dish_37679243;

WITH new_dish_22460525 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Masala Dry', 'lollipop masala dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop masala dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Masala Dry', 'lollipop masala dry', 'primary'
FROM new_dish_22460525;

WITH new_dish_86999712 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Chilly Dry', 'chicken chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly Dry', 'chicken chilly dry', 'primary'
FROM new_dish_86999712;

WITH new_dish_39723814 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Hunan Dry', 'hunan dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hunan dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Hunan Dry', 'hunan dry', 'primary'
FROM new_dish_39723814;

WITH new_dish_24491625 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Crispy Dry', 'chicken crispy dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken crispy dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Crispy Dry', 'chicken crispy dry', 'primary'
FROM new_dish_24491625;

WITH new_dish_42210312 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken 65 Dry', 'chicken 65 dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65 dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken 65 Dry', 'chicken 65 dry', 'primary'
FROM new_dish_42210312;

WITH new_dish_95724157 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Black Bean Dry', 'black bean dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black bean dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Black Bean Dry', 'black bean dry', 'primary'
FROM new_dish_95724157;

WITH new_dish_97809108 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Black Pepper Dry', 'black pepper dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black pepper dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Black Pepper Dry', 'black pepper dry', 'primary'
FROM new_dish_97809108;

WITH new_dish_99218047 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mongolian Dry', 'mongolian dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mongolian dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mongolian Dry', 'mongolian dry', 'primary'
FROM new_dish_99218047;

WITH new_dish_28647120 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken Dragon Dry', 'chicken dragon dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken dragon dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken Dragon Dry', 'chicken dragon dry', 'primary'
FROM new_dish_28647120;

WITH new_dish_14682264 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Turkey Dry', 'turkey dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'turkey dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Turkey Dry', 'turkey dry', 'primary'
FROM new_dish_14682264;

WITH new_dish_83226921 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Shanghai Dry', 'shanghai dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shanghai dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Shanghai Dry', 'shanghai dry', 'primary'
FROM new_dish_83226921;

WITH new_dish_88181816 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Thai Chilly Dry', 'thai chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Thai Chilly Dry', 'thai chilly dry', 'primary'
FROM new_dish_88181816;

WITH new_dish_357955 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Cheese Dry', 'cheese dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Cheese Dry', 'cheese dry', 'primary'
FROM new_dish_357955;

WITH new_dish_79443020 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken White Butter Sauce', 'chicken white butter sauce'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken white butter sauce')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken White Butter Sauce', 'chicken white butter sauce', 'primary'
FROM new_dish_79443020;

WITH new_dish_16266152 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Pulpy Dry', 'pulpy dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pulpy dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Pulpy Dry', 'pulpy dry', 'primary'
FROM new_dish_16266152;

WITH new_dish_67770061 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Peri Peri Chicken', 'peri peri chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Chicken', 'peri peri chicken', 'primary'
FROM new_dish_67770061;

WITH new_dish_62614265 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Karachi Chicken Dry', 'karachi chicken dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'karachi chicken dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Karachi Chicken Dry', 'karachi chicken dry', 'primary'
FROM new_dish_62614265;

WITH new_dish_92677529 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lahori Chicken Dry (Bl)', 'lahori chicken dry (bl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lahori chicken dry (bl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lahori Chicken Dry (Bl)', 'lahori chicken dry (bl)', 'primary'
FROM new_dish_92677529;

WITH new_dish_10899812 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Plum Chicken Dry (Bl)', 'plum chicken dry (bl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plum chicken dry (bl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Plum Chicken Dry (Bl)', 'plum chicken dry (bl)', 'primary'
FROM new_dish_10899812;

WITH new_dish_45507586 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tomato Chicken Dry (Bl)', 'tomato chicken dry (bl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato chicken dry (bl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tomato Chicken Dry (Bl)', 'tomato chicken dry (bl)', 'primary'
FROM new_dish_45507586;

WITH new_dish_12959047 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Spl Dry (Bl & Fingers)', 'rangoon spl dry (bl & fingers)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon spl dry (bl & fingers)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Spl Dry (Bl & Fingers)', 'rangoon spl dry (bl & fingers)', 'primary'
FROM new_dish_12959047;

WITH new_dish_93519136 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Malai Chicken Dry (Bl)', 'malai chicken dry (bl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai chicken dry (bl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Malai Chicken Dry (Bl)', 'malai chicken dry (bl)', 'primary'
FROM new_dish_93519136;

WITH new_dish_62141816 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Nawabsahab (Roll)', 'nawabsahab (roll)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nawabsahab (roll)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Nawabsahab (Roll)', 'nawabsahab (roll)', 'primary'
FROM new_dish_62141816;

WITH new_dish_17972287 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chk Cheese Roll Masala Dry', 'chk cheese roll masala dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chk cheese roll masala dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chk Cheese Roll Masala Dry', 'chk cheese roll masala dry', 'primary'
FROM new_dish_17972287;

WITH new_dish_70924562 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chilly Rice', 'chilly rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chilly Rice', 'chilly rice', 'primary'
FROM new_dish_70924562;

WITH new_dish_2016131 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Crispy Rice', 'crispy rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Crispy Rice', 'crispy rice', 'primary'
FROM new_dish_2016131;

WITH new_dish_24109993 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Korean Rice', 'korean rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Korean Rice', 'korean rice', 'primary'
FROM new_dish_24109993;

WITH new_dish_93427526 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dragon Rice', 'dragon rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dragon rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dragon Rice', 'dragon rice', 'primary'
FROM new_dish_93427526;

WITH new_dish_50263109 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Barista Rice', 'barista rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'barista rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Barista Rice', 'barista rice', 'primary'
FROM new_dish_50263109;

WITH new_dish_72961063 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Black Bean Rice', 'black bean rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black bean rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Black Bean Rice', 'black bean rice', 'primary'
FROM new_dish_72961063;

WITH new_dish_53722713 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chopper Rice', 'chopper rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chopper rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chopper Rice', 'chopper rice', 'primary'
FROM new_dish_53722713;

WITH new_dish_87126852 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Packing Rice', 'packing rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'packing rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Packing Rice', 'packing rice', 'primary'
FROM new_dish_87126852;

WITH new_dish_29136494 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Masala Rice', 'lollipop masala rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop masala rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Masala Rice', 'lollipop masala rice', 'primary'
FROM new_dish_29136494;

WITH new_dish_92594950 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Manchurian Rice', 'manchurian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'manchurian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Manchurian Rice', 'manchurian rice', 'primary'
FROM new_dish_92594950;

WITH new_dish_69956496 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Koliwada Rice', 'koliwada rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'koliwada rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Koliwada Rice', 'koliwada rice', 'primary'
FROM new_dish_69956496;

WITH new_dish_65533466 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Cheese Rice', 'cheese rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Cheese Rice', 'cheese rice', 'primary'
FROM new_dish_65533466;

WITH new_dish_15384 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'White Butter Sauce Rice', 'white butter sauce rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'white butter sauce rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'White Butter Sauce Rice', 'white butter sauce rice', 'primary'
FROM new_dish_15384;

WITH new_dish_67973987 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Palpi Rice', 'palpi rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palpi rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Palpi Rice', 'palpi rice', 'primary'
FROM new_dish_67973987;

WITH new_dish_92512280 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rangoon Spl Rice', 'rangoon spl rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rangoon spl rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rangoon Spl Rice', 'rangoon spl rice', 'primary'
FROM new_dish_92512280;

WITH new_dish_19462543 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Malaysian Rice', 'malaysian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malaysian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Malaysian Rice', 'malaysian rice', 'primary'
FROM new_dish_19462543;

WITH new_dish_69222211 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Crispy Rice', 'prawns crispy rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns crispy rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Crispy Rice', 'prawns crispy rice', 'primary'
FROM new_dish_69222211;

WITH new_dish_29550364 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Chilly Rice', 'prawns chilly rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Chilly Rice', 'prawns chilly rice', 'primary'
FROM new_dish_29550364;

WITH new_dish_93319566 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Koliwada Rice', 'prawns koliwada rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Koliwada Rice', 'prawns koliwada rice', 'primary'
FROM new_dish_93319566;

WITH new_dish_31832777 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Rangoon Spl Rice', 'prawns rangoon spl rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns rangoon spl rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Rangoon Spl Rice', 'prawns rangoon spl rice', 'primary'
FROM new_dish_31832777;

WITH new_dish_39840490 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Chilly Rice', 'paneer chilly rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Chilly Rice', 'paneer chilly rice', 'primary'
FROM new_dish_39840490;

WITH new_dish_60760307 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Crispy Rice', 'paneer crispy rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer crispy rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Crispy Rice', 'paneer crispy rice', 'primary'
FROM new_dish_60760307;

WITH new_dish_889755 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Khepsa', 'lollipop khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Khepsa', 'lollipop khepsa', 'primary'
FROM new_dish_889755;

WITH new_dish_85116462 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tandoori Khepsa (Chinese)', 'tandoori khepsa (chinese)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori khepsa (chinese)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Khepsa (Chinese)', 'tandoori khepsa (chinese)', 'primary'
FROM new_dish_85116462;

WITH new_dish_36417900 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Boneless Khepsa', 'boneless khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boneless khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Boneless Khepsa', 'boneless khepsa', 'primary'
FROM new_dish_36417900;

WITH new_dish_84561936 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chilly Khepsa', 'chilly khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chilly Khepsa', 'chilly khepsa', 'primary'
FROM new_dish_84561936;

WITH new_dish_70188946 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dry Fruit Khepsa', 'dry fruit khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Khepsa', 'dry fruit khepsa', 'primary'
FROM new_dish_70188946;

WITH new_dish_41734223 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Khepsa', 'prawns khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Khepsa', 'prawns khepsa', 'primary'
FROM new_dish_41734223;

WITH new_dish_41011951 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mutton Khepsa', 'mutton khepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton khepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mutton Khepsa', 'mutton khepsa', 'primary'
FROM new_dish_41011951;

WITH new_dish_3131005 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chinese Biryani', 'chinese biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chinese Biryani', 'chinese biryani', 'primary'
FROM new_dish_3131005;

WITH new_dish_43334451 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Korean Biryani', 'korean biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Korean Biryani', 'korean biryani', 'primary'
FROM new_dish_43334451;

WITH new_dish_42026136 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Dragon Biryani', 'dragon biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dragon biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Dragon Biryani', 'dragon biryani', 'primary'
FROM new_dish_42026136;

WITH new_dish_57988179 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chicken 65 Biryani', 'chicken 65 biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65 biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chicken 65 Biryani', 'chicken 65 biryani', 'primary'
FROM new_dish_57988179;

WITH new_dish_93597317 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Chilly Gravy', 'chilly gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Chilly Gravy', 'chilly gravy', 'primary'
FROM new_dish_93597317;

WITH new_dish_4327359 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Lollipop Gravy', 'lollipop gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollipop gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Lollipop Gravy', 'lollipop gravy', 'primary'
FROM new_dish_4327359;

WITH new_dish_57472164 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), '65 Gravy', '65 gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = '65 gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', '65 Gravy', '65 gravy', 'primary'
FROM new_dish_57472164;

WITH new_dish_79889815 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Fried Rice', 'fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Fried Rice', 'fried rice', 'primary'
FROM new_dish_79889815;

WITH new_dish_87288863 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Schezwan Fried Rice', 'schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Schezwan Fried Rice', 'schezwan fried rice', 'primary'
FROM new_dish_87288863;

WITH new_dish_43734020 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Korean Fried Rice', 'korean fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Korean Fried Rice', 'korean fried rice', 'primary'
FROM new_dish_43734020;

WITH new_dish_82604940 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Hong Kong Fried Rice', 'hong kong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hong kong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Hong Kong Fried Rice', 'hong kong fried rice', 'primary'
FROM new_dish_82604940;

WITH new_dish_84293895 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Singapore Fried Rice', 'singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Singapore Fried Rice', 'singapore fried rice', 'primary'
FROM new_dish_84293895;

WITH new_dish_39838591 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Triple Rice', 'triple rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'triple rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Triple Rice', 'triple rice', 'primary'
FROM new_dish_39838591;

WITH new_dish_87620353 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tikka Fried Rice', 'tikka fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tikka fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tikka Fried Rice', 'tikka fried rice', 'primary'
FROM new_dish_87620353;

WITH new_dish_99344821 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tikka Schezwan Fried Rice', 'tikka schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tikka schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tikka Schezwan Fried Rice', 'tikka schezwan fried rice', 'primary'
FROM new_dish_99344821;

WITH new_dish_60595924 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Tandoori Fried Rice', 'tandoori fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Fried Rice', 'tandoori fried rice', 'primary'
FROM new_dish_60595924;

WITH new_dish_44115826 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Mix Fried Rice (Prawns/Chicken)', 'mix fried rice (prawns/chicken)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix fried rice (prawns/chicken)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Mix Fried Rice (Prawns/Chicken)', 'mix fried rice (prawns/chicken)', 'primary'
FROM new_dish_44115826;

WITH new_dish_98189177 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Egg Fried Rice', 'egg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Egg Fried Rice', 'egg fried rice', 'primary'
FROM new_dish_98189177;

WITH new_dish_59258786 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Egg Schezwan Fried Rice', 'egg schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'primary'
FROM new_dish_59258786;

WITH new_dish_47895529 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Fried Rice', 'prawns fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Fried Rice', 'prawns fried rice', 'primary'
FROM new_dish_47895529;

WITH new_dish_89288694 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 'primary'
FROM new_dish_89288694;

WITH new_dish_96996673 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Fried Rice', 'paneer fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Fried Rice', 'paneer fried rice', 'primary'
FROM new_dish_96996673;

WITH new_dish_68195043 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Schezwan F Rice', 'paneer schezwan f rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan f rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Schezwan F Rice', 'paneer schezwan f rice', 'primary'
FROM new_dish_68195043;

WITH new_dish_91789569 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Korean Fr Rice', 'paneer korean fr rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer korean fr rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Korean Fr Rice', 'paneer korean fr rice', 'primary'
FROM new_dish_91789569;

WITH new_dish_5937846 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Hongkong Fr Rice', 'paneer hongkong fr rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hongkong fr rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Hongkong Fr Rice', 'paneer hongkong fr rice', 'primary'
FROM new_dish_5937846;

WITH new_dish_19732268 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Paneer Triple Rice', 'paneer triple rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer triple rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Paneer Triple Rice', 'paneer triple rice', 'primary'
FROM new_dish_19732268;

WITH new_dish_39039438 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Hakka Noodles', 'hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Hakka Noodles', 'hakka noodles', 'primary'
FROM new_dish_39039438;

WITH new_dish_37421536 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Schezwan Noodles', 'schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Schezwan Noodles', 'schezwan noodles', 'primary'
FROM new_dish_37421536;

WITH new_dish_80507725 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Singapore Noodles', 'singapore noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Singapore Noodles', 'singapore noodles', 'primary'
FROM new_dish_80507725;

WITH new_dish_57360833 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Hongkong Noodles', 'hongkong noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hongkong noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Hongkong Noodles', 'hongkong noodles', 'primary'
FROM new_dish_57360833;

WITH new_dish_91458167 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Korean Noodles', 'korean noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'korean noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Korean Noodles', 'korean noodles', 'primary'
FROM new_dish_91458167;

WITH new_dish_52208487 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Triple Noodles', 'triple noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'triple noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Triple Noodles', 'triple noodles', 'primary'
FROM new_dish_52208487;

WITH new_dish_60692494 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Caramal Custurd', 'caramal custurd'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'caramal custurd')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Caramal Custurd', 'caramal custurd', 'primary'
FROM new_dish_60692494;

WITH new_dish_68882807 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Rabdi', 'rabdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rabdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Rabdi', 'rabdi', 'primary'
FROM new_dish_68882807;

WITH new_dish_43421237 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Arabian Pudding', 'arabian pudding'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian pudding')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Arabian Pudding', 'arabian pudding', 'primary'
FROM new_dish_43421237;

WITH new_dish_22770668 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rangoon_other_id_seq'), 'Sitafal Cream', 'sitafal cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sitafal cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rangoon_other_id_seq'), canonical_dish_id, 'en', 'Sitafal Cream', 'sitafal cream', 'primary'
FROM new_dish_22770668;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007001, 400070007, cd.canonical_dish_id, 'Chicken Tikka (6 Pcs)', 'chicken tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007001, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007001, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007001, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007002, 400070007, cd.canonical_dish_id, 'Malai Tikka (6 Pcs)', 'malai tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007002, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007002, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007002, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007003, 400070007, cd.canonical_dish_id, 'Pahadi Tikka (6 Pcs)', 'pahadi tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pahadi tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007003, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007003, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007003, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007004, 400070007, cd.canonical_dish_id, 'Peshawari / Reshmi Tikka (6 Pcs)', 'peshawari / reshmi tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peshawari / reshmi tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007004, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007004, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007004, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007005, 400070007, cd.canonical_dish_id, 'Kalimiri Tikka (6 Pcs)', 'kalimiri tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kalimiri tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007005, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007005, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007005, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007006, 400070007, cd.canonical_dish_id, 'Amul Dahi Tikka (6 Pcs)', 'amul dahi tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'amul dahi tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007006, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007006, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007006, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007007, 400070007, cd.canonical_dish_id, 'Banjara Tikka (6 Pcs)', 'banjara tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'banjara tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007007, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007007, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007007, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007008, 400070007, cd.canonical_dish_id, 'Garlic Tikka (6 Pcs)', 'garlic tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007008, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007008, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007008, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007009, 400070007, cd.canonical_dish_id, 'Achari Tikka (6 Pcs)', 'achari tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'achari tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007009, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007009, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007009, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007010, 400070007, cd.canonical_dish_id, 'Italian Tikka (6 Pcs)', 'italian tikka (6 pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'italian tikka (6 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007010, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007010, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007010, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007011, 400070007, cd.canonical_dish_id, 'Chk Seekh (3Pcs/6Pcs)', 'chk seekh (3pcs/6pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chk seekh (3pcs/6pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007011, menu_item_id, 'Half(3Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007011, variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007012, menu_item_id, 'Full(6Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007012, variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007011, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007012, 400070007, cd.canonical_dish_id, 'Chk Cheese Seekh (3Pcs/6Pcs)', 'chk cheese seekh (3pcs/6pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chk cheese seekh (3pcs/6pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007013, menu_item_id, 'Half(3Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007013, variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007014, menu_item_id, 'Full(6Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007014, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007012, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "B.L Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007013, 400070007, cd.canonical_dish_id, 'Malai Seekh Barrah (3Pcs/6Pcs)', 'malai seekh barrah (3pcs/6pcs)', 'B.L Tandoori Starter', 400070007001, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai seekh barrah (3pcs/6pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007015, menu_item_id, 'Half(3Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007015, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007016, menu_item_id, 'Full(6Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007016, variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007013, 400070007, 400070007001, menu_item_id, 400070007001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007014, 400070007, cd.canonical_dish_id, 'Chicken Tandoori', 'chicken tandoori', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007017, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007017, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007018, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007018, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007014, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007015, 400070007, cd.canonical_dish_id, 'Chicken Tandoori Butter', 'chicken tandoori butter', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori butter'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007019, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007019, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007020, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007020, variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007015, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007016, 400070007, cd.canonical_dish_id, 'Chicken Tandoori Schezwan', 'chicken tandoori schezwan', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007021, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007021, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007022, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007022, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007016, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007017, 400070007, cd.canonical_dish_id, 'Chicken Kalimiri Tandoori', 'chicken kalimiri tandoori', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kalimiri tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007023, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007023, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007024, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007024, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007017, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007018, 400070007, cd.canonical_dish_id, 'Chicken Tandoori Lemon', 'chicken tandoori lemon', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori lemon'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007025, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007025, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007026, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007026, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007018, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007019, 400070007, cd.canonical_dish_id, 'Chicken Afghani Tandoori', 'chicken afghani tandoori', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken afghani tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007027, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007027, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007028, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007028, variant_id, 560.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007019, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007020, 400070007, cd.canonical_dish_id, 'Chicken Banjara Tandoori', 'chicken banjara tandoori', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken banjara tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007029, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007029, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007030, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007030, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007020, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007021, 400070007, cd.canonical_dish_id, 'Chicken Tandoor Barrah', 'chicken tandoor barrah', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoor barrah'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007031, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007031, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007032, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007032, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007021, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007022, 400070007, cd.canonical_dish_id, 'Chicken Peshawari Tandoori', 'chicken peshawari tandoori', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken peshawari tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007033, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007033, variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007034, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007034, variant_id, 720.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007022, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007023, 400070007, cd.canonical_dish_id, 'Chk Tandoori Cream Barra', 'chk tandoori cream barra', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chk tandoori cream barra'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007035, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007035, variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007036, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007036, variant_id, 760.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007023, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007024, 400070007, cd.canonical_dish_id, 'Lollipop Tandoori (8 Pcs)', 'lollipop tandoori (8 pcs)', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop tandoori (8 pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007037, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007037, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007024, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007025, 400070007, cd.canonical_dish_id, 'Tandoori Leg / Breast', 'tandoori leg / breast', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori leg / breast'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007038, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007038, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007025, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Tandoori Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007026, 400070007, cd.canonical_dish_id, 'Rangoon Spl Platters', 'rangoon spl platters', 'Tandoori Starter', 400070007002, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon spl platters'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007039, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007039, variant_id, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007040, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007040, variant_id, 1800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007026, 400070007, 400070007001, menu_item_id, 400070007002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007027, 400070007, cd.canonical_dish_id, 'Chicken Do Pyaza', 'chicken do pyaza', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken do pyaza'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007041, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007041, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007042, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007042, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007027, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007028, 400070007, cd.canonical_dish_id, 'Chicken Korma', 'chicken korma', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken korma'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007043, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007043, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007044, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007044, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007028, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007029, 400070007, cd.canonical_dish_id, 'Chicken Akbari', 'chicken akbari', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken akbari'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007045, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007045, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007046, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007046, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007029, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007030, 400070007, cd.canonical_dish_id, 'Chicken Kofta', 'chicken kofta', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kofta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007047, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007047, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007048, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007048, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007030, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007031, 400070007, cd.canonical_dish_id, 'Chicken Cream Tawa', 'chicken cream tawa', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken cream tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007049, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007049, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007050, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007050, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007031, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007032, 400070007, cd.canonical_dish_id, 'Chicken White Korma', 'chicken white korma', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken white korma'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007051, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007051, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007052, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007052, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007032, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007033, 400070007, cd.canonical_dish_id, 'Chicken Afghani', 'chicken afghani', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken afghani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007053, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007053, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007054, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007054, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007033, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007034, 400070007, cd.canonical_dish_id, 'Chicken Lahori', 'chicken lahori', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lahori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007055, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007055, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007056, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007056, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007034, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007035, 400070007, cd.canonical_dish_id, 'Chicken Kashmiri', 'chicken kashmiri', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kashmiri'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007057, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007057, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007058, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007058, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007035, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007036, 400070007, cd.canonical_dish_id, 'Chicken Patiala', 'chicken patiala', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken patiala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007059, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007059, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007060, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007060, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007036, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007037, 400070007, cd.canonical_dish_id, 'Chicken Laziz', 'chicken laziz', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken laziz'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007061, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007061, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007062, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007062, variant_id, 520.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007037, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007038, 400070007, cd.canonical_dish_id, 'Chicken Lajawab', 'chicken lajawab', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lajawab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007063, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007063, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007064, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007064, variant_id, 560.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007038, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007039, 400070007, cd.canonical_dish_id, 'Chicken Malai Kofta', 'chicken malai kofta', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken malai kofta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007065, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007065, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007066, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007066, variant_id, 560.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007039, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007040, 400070007, cd.canonical_dish_id, 'Chicken Angara', 'chicken angara', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken angara'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007067, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007067, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007068, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007068, variant_id, 560.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007040, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007041, 400070007, cd.canonical_dish_id, 'Chicken Aflatoon', 'chicken aflatoon', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken aflatoon'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007069, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007069, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007070, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007070, variant_id, 640.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007041, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007042, 400070007, cd.canonical_dish_id, 'Murg Musallam', 'murg musallam', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'murg musallam'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007071, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007071, variant_id, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007072, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007072, variant_id, 1000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007042, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007043, 400070007, cd.canonical_dish_id, 'Chicken Handi', 'chicken handi', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007073, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007073, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007074, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007074, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007043, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007044, 400070007, cd.canonical_dish_id, 'Chicken Bhuna', 'chicken bhuna', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken bhuna'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007075, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007075, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007076, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007076, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007044, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007045, 400070007, cd.canonical_dish_id, 'Chicken Kadai', 'chicken kadai', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kadai'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007077, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007077, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007078, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007078, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007045, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007046, 400070007, cd.canonical_dish_id, 'Chicken Masala', 'chicken masala', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007079, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007079, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007080, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007080, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007046, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007047, 400070007, cd.canonical_dish_id, 'Butter Chicken', 'butter chicken', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter chicken'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007081, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007081, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007082, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007082, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007047, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Chicken Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007048, 400070007, cd.canonical_dish_id, 'Chicken Changezi', 'chicken changezi', 'Chicken Gravy', 400070007003, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken changezi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007083, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007083, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007084, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007084, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007048, 400070007, 400070007001, menu_item_id, 400070007003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007049, 400070007, cd.canonical_dish_id, 'Mutton Dal Gosht', 'mutton dal gosht', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton dal gosht'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007085, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007085, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007086, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007086, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007049, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007050, 400070007, cd.canonical_dish_id, 'Mutton Handi', 'mutton handi', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007087, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007087, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007088, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007088, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007050, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007051, 400070007, cd.canonical_dish_id, 'Mutton Bhuna', 'mutton bhuna', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton bhuna'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007089, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007089, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007090, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007090, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007051, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007052, 400070007, cd.canonical_dish_id, 'Mutton Kadai', 'mutton kadai', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton kadai'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007091, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007091, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007092, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007092, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007052, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007053, 400070007, cd.canonical_dish_id, 'Mutton Masala', 'mutton masala', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007093, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007093, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007094, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007094, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007053, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007054, 400070007, cd.canonical_dish_id, 'Mutton Changezi', 'mutton changezi', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton changezi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007095, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007095, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007096, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007096, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007054, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007055, 400070007, cd.canonical_dish_id, 'Mutton Do Pyaza', 'mutton do pyaza', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton do pyaza'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007097, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007097, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007098, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007098, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007055, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007056, 400070007, cd.canonical_dish_id, 'Mutton Korma', 'mutton korma', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton korma'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007099, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007099, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007100, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007100, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007056, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007057, 400070007, cd.canonical_dish_id, 'Mutton Akbari', 'mutton akbari', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton akbari'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007101, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007101, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007102, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007102, variant_id, 540.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007057, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007058, 400070007, cd.canonical_dish_id, 'Mutton Cream Tawa', 'mutton cream tawa', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton cream tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007103, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007103, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007104, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007104, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007058, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007059, 400070007, cd.canonical_dish_id, 'Mutton Afghani', 'mutton afghani', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton afghani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007105, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007105, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007106, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007106, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007059, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007060, 400070007, cd.canonical_dish_id, 'Mutton Lahori', 'mutton lahori', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton lahori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007107, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007107, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007108, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007108, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007060, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007061, 400070007, cd.canonical_dish_id, 'Mutton Kashmiri', 'mutton kashmiri', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton kashmiri'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007109, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007109, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007110, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007110, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007061, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007062, 400070007, cd.canonical_dish_id, 'Mutton Patiala', 'mutton patiala', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton patiala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007111, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007111, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007112, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007112, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007062, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007063, 400070007, cd.canonical_dish_id, 'Mutton Laziz', 'mutton laziz', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton laziz'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007113, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007113, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007114, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007114, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007063, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007064, 400070007, cd.canonical_dish_id, 'Mutton Shahi Korma', 'mutton shahi korma', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton shahi korma'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007115, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007115, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007116, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007116, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007064, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007065, 400070007, cd.canonical_dish_id, 'Mutton Lajawab', 'mutton lajawab', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton lajawab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007117, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007117, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007118, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007118, variant_id, 640.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007065, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007066, 400070007, cd.canonical_dish_id, 'Mutton Malai Kofta', 'mutton malai kofta', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton malai kofta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007119, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007119, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007120, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007120, variant_id, 640.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007066, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007067, 400070007, cd.canonical_dish_id, 'Mutton Angara', 'mutton angara', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton angara'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007121, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007121, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007122, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007122, variant_id, 640.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007067, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007068, 400070007, cd.canonical_dish_id, 'Mutton Aflatoon', 'mutton aflatoon', 'Mutton Gravy', 400070007004, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton aflatoon'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007123, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007123, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007124, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007124, variant_id, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007068, 400070007, 400070007001, menu_item_id, 400070007004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007069, 400070007, cd.canonical_dish_id, 'Paneer Kadai', 'paneer kadai', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer kadai'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007125, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007125, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007126, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007126, variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007069, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007070, 400070007, cd.canonical_dish_id, 'Paneer Masala', 'paneer masala', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007127, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007127, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007128, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007128, variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007070, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007071, 400070007, cd.canonical_dish_id, 'Paneer Mutter', 'paneer mutter', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer mutter'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007129, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007129, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007130, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007130, variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007071, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007072, 400070007, cd.canonical_dish_id, 'Paneer Changezi', 'paneer changezi', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer changezi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007131, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007131, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007132, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007132, variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007072, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007073, 400070007, cd.canonical_dish_id, 'Paneer Makhamwala', 'paneer makhamwala', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer makhamwala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007133, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007133, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007134, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007134, variant_id, 510.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007073, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007074, 400070007, cd.canonical_dish_id, 'Paneer Do Pyaza', 'paneer do pyaza', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer do pyaza'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007135, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007135, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007136, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007136, variant_id, 510.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007074, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007075, 400070007, cd.canonical_dish_id, 'Paneer Cream Tawa', 'paneer cream tawa', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer cream tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007137, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007137, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007138, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007138, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007075, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007076, 400070007, cd.canonical_dish_id, 'Paneer Shahi Korma', 'paneer shahi korma', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer shahi korma'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007139, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007139, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007140, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007140, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007076, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007077, 400070007, cd.canonical_dish_id, 'Paneer Afghani', 'paneer afghani', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer afghani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007141, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007141, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007142, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007142, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007077, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Paneer Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007078, 400070007, cd.canonical_dish_id, 'Paneer Lajawab', 'paneer lajawab', 'Paneer Gravy', 400070007005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lajawab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007143, menu_item_id, 'Half', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007143, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007144, menu_item_id, 'Full', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007144, variant_id, 640.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007078, 400070007, 400070007001, menu_item_id, 400070007005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007079, 400070007, cd.canonical_dish_id, 'Mutton Barra (6Pcs/12Pcs)', 'mutton barra (6pcs/12pcs)', 'Mutton Tandoori Starters', 400070007006, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton barra (6pcs/12pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007145, menu_item_id, 'Half(6Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007145, variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007146, menu_item_id, 'Full(12Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007146, variant_id, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007079, 400070007, 400070007001, menu_item_id, 400070007006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007080, 400070007, cd.canonical_dish_id, 'Cream Barra (6Pcs/12Pcs)', 'cream barra (6pcs/12pcs)', 'Mutton Tandoori Starters', 400070007006, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream barra (6pcs/12pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007147, menu_item_id, 'Half(6Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007147, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007148, menu_item_id, 'Full(12Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007148, variant_id, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007080, 400070007, 400070007001, menu_item_id, 400070007006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Tawa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007081, 400070007, cd.canonical_dish_id, 'Mutton Tawa Dry (7Pcs/14Pcs)', 'mutton tawa dry (7pcs/14pcs)', 'Mutton Tawa', 400070007007, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton tawa dry (7pcs/14pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007149, menu_item_id, 'Half(7Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007149, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007150, menu_item_id, 'Full(14Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007150, variant_id, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007081, 400070007, 400070007001, menu_item_id, 400070007007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Tawa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007082, 400070007, cd.canonical_dish_id, 'Kalimiri Dry (7Pcs/14Pcs)', 'kalimiri dry (7pcs/14pcs)', 'Mutton Tawa', 400070007007, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kalimiri dry (7pcs/14pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007151, menu_item_id, 'Half(7Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007151, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007152, menu_item_id, 'Full(14Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007152, variant_id, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007082, 400070007, 400070007001, menu_item_id, 400070007007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Tawa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007083, 400070007, cd.canonical_dish_id, 'Tomato Onion Dry (7Pcs/14Pcs)', 'tomato onion dry (7pcs/14pcs)', 'Mutton Tawa', 400070007007, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tomato onion dry (7pcs/14pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007153, menu_item_id, 'Half(7Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007153, variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007154, menu_item_id, 'Full(14Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007154, variant_id, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007083, 400070007, 400070007001, menu_item_id, 400070007007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Mutton Tawa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007084, 400070007, cd.canonical_dish_id, 'Schezwan Dry (7Pcs/14Pcs)', 'schezwan dry (7pcs/14pcs)', 'Mutton Tawa', 400070007007, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan dry (7pcs/14pcs)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007155, menu_item_id, 'Half(7Pcs)', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007155, variant_id, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007156, menu_item_id, 'Full(14Pcs)', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007156, variant_id, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007084, 400070007, 400070007001, menu_item_id, 400070007007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
  UNION ALL SELECT price_id FROM new_price_2
) AS all_prices;

-- Source: JSON, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007085, 400070007, cd.canonical_dish_id, 'Dal Fry', 'dal fry', 'Dal', 400070007008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007157, variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007085, 400070007, 400070007001, menu_item_id, 400070007008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007086, 400070007, cd.canonical_dish_id, 'Dal Tadka', 'dal tadka', 'Dal', 400070007008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007158, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007086, 400070007, 400070007001, menu_item_id, 400070007008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007087, 400070007, cd.canonical_dish_id, 'Dal Khichdi', 'dal khichdi', 'Dal', 400070007008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007159, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007087, 400070007, 400070007001, menu_item_id, 400070007008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007088, 400070007, cd.canonical_dish_id, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'Dal', 400070007008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal khichdi tadka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007160, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007088, 400070007, 400070007001, menu_item_id, 400070007008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007089, 400070007, cd.canonical_dish_id, 'Plain Rice', 'plain rice', 'Rice', 400070007009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007161, variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007089, 400070007, 400070007001, menu_item_id, 400070007009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007090, 400070007, cd.canonical_dish_id, 'Lemon Rice', 'lemon rice', 'Rice', 400070007009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lemon rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007162, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007090, 400070007, 400070007001, menu_item_id, 400070007009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007091, 400070007, cd.canonical_dish_id, 'Jeera Rice', 'jeera rice', 'Rice', 400070007009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007163, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007091, 400070007, 400070007001, menu_item_id, 400070007009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007092, 400070007, cd.canonical_dish_id, 'Plain Butter Rice', 'plain butter rice', 'Rice', 400070007009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain butter rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007164, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007092, 400070007, 400070007001, menu_item_id, 400070007009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007093, 400070007, cd.canonical_dish_id, 'Tandoori Roti', 'tandoori roti', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori roti'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007165, variant_id, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007093, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007094, 400070007, cd.canonical_dish_id, 'Kamachi Roti', 'kamachi roti', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kamachi roti'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007166, variant_id, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007094, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007095, 400070007, cd.canonical_dish_id, 'Butter Roti', 'butter roti', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007167, variant_id, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007095, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007096, 400070007, cd.canonical_dish_id, 'Butter Naan', 'butter naan', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007168, variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007096, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007097, 400070007, cd.canonical_dish_id, 'Lachha Paratha', 'lachha paratha', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lachha paratha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007169, variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007097, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007098, 400070007, cd.canonical_dish_id, 'Garlic Naan', 'garlic naan', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007170, variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007098, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Roti" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007099, 400070007, cd.canonical_dish_id, 'Butter Garlic Naan', 'butter garlic naan', 'Roti', 400070007010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter garlic naan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007171, variant_id, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007099, 400070007, 400070007001, menu_item_id, 400070007010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Mutton Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007100, 400070007, cd.canonical_dish_id, 'Mutton Biryani', 'mutton biryani', 'Mutton Biryani', 400070007011, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007172, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007172, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007100, 400070007, 400070007001, menu_item_id, 400070007011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Mutton Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007101, 400070007, cd.canonical_dish_id, 'Mutton Pulao', 'mutton pulao', 'Mutton Biryani', 400070007011, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton pulao'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007173, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007173, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007101, 400070007, 400070007001, menu_item_id, 400070007011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Mutton Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007102, 400070007, cd.canonical_dish_id, 'Mutton Malai Biryani', 'mutton malai biryani', 'Mutton Biryani', 400070007011, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton malai biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007174, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007174, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007102, 400070007, 400070007001, menu_item_id, 400070007011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007103, 400070007, cd.canonical_dish_id, 'Chicken Biryani', 'chicken biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007175, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007175, variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007103, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007104, 400070007, cd.canonical_dish_id, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007176, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007176, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007104, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007105, 400070007, cd.canonical_dish_id, 'Chicken Seekh Biryani', 'chicken seekh biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken seekh biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007177, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007177, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007105, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007106, 400070007, cd.canonical_dish_id, 'Chicken Malai Tikka Biryani', 'chicken malai tikka biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken malai tikka biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007178, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007178, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007106, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007107, 400070007, cd.canonical_dish_id, 'Chicken Pulao', 'chicken pulao', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pulao'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007179, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007179, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007107, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007108, 400070007, cd.canonical_dish_id, 'Chicken Malai Seekh Biryani', 'chicken malai seekh biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken malai seekh biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007180, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007180, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007108, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007109, 400070007, cd.canonical_dish_id, 'Chicken Cheese Seekh Biryani', 'chicken cheese seekh biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken cheese seekh biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007181, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007181, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007109, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007110, 400070007, cd.canonical_dish_id, 'Chicken Malai Cheese Seekh Biryani', 'chicken malai cheese seekh biryani', 'Chicken Biryani', 400070007012, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken malai cheese seekh biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007182, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007182, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007110, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chicken Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007111, 400070007, cd.canonical_dish_id, 'Egg Biryani', 'egg biryani', 'Chicken Biryani', 400070007012, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007183, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007183, variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007111, 400070007, 400070007001, menu_item_id, 400070007012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007112, 400070007, cd.canonical_dish_id, 'Prawns Biryani', 'prawns biryani', 'Sea Food Biryani', 400070007013, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007184, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007184, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007112, 400070007, 400070007001, menu_item_id, 400070007013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007113, 400070007, cd.canonical_dish_id, 'Prawns Pulao', 'prawns pulao', 'Sea Food Biryani', 400070007013, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns pulao'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007185, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007185, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007113, 400070007, 400070007001, menu_item_id, 400070007013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007114, 400070007, cd.canonical_dish_id, 'Fish Biryani', 'fish biryani', 'Sea Food Biryani', 400070007013, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007186, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007186, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007114, 400070007, 400070007001, menu_item_id, 400070007013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Paneer Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007115, 400070007, cd.canonical_dish_id, 'Paneer Biryani', 'paneer biryani', 'Paneer Biryani', 400070007014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007187, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007187, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007115, 400070007, 400070007001, menu_item_id, 400070007014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Paneer Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007116, 400070007, cd.canonical_dish_id, 'Paneer Pulao', 'paneer pulao', 'Paneer Biryani', 400070007014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pulao'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007188, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007188, variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007116, 400070007, 400070007001, menu_item_id, 400070007014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Mughlai Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007117, 400070007, cd.canonical_dish_id, 'Tandoori Khepsa', 'tandoori khepsa', 'Mughlai Khepsa', 400070007015, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007189, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007189, variant_id, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007117, 400070007, 400070007001, menu_item_id, 400070007015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Mughlai Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007118, 400070007, cd.canonical_dish_id, 'Arabian Khepsa', 'arabian khepsa', 'Mughlai Khepsa', 400070007015, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'arabian khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007190, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007190, variant_id, 1050.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007118, 400070007, 400070007001, menu_item_id, 400070007015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Mughlai Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007119, 400070007, cd.canonical_dish_id, 'Rangoon Special Khepsa', 'rangoon special khepsa', 'Mughlai Khepsa', 400070007015, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon special khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007191, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007191, variant_id, 1250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007119, 400070007, 400070007001, menu_item_id, 400070007015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007120, 400070007, cd.canonical_dish_id, 'Prawns Crispy Dry', 'prawns crispy dry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns crispy dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007192, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007120, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007121, 400070007, cd.canonical_dish_id, 'Prawns Chilly Dry', 'prawns chilly dry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns chilly dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007193, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007121, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007122, 400070007, cd.canonical_dish_id, 'Prawns 65 Dry', 'prawns 65 dry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns 65 dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007194, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007122, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007123, 400070007, cd.canonical_dish_id, 'Prawns Koliwada Oil Fry', 'prawns koliwada oil fry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns koliwada oil fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007195, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007123, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007124, 400070007, cd.canonical_dish_id, 'Prawns Koliwada Dry', 'prawns koliwada dry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns koliwada dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007196, variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007124, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007125, 400070007, cd.canonical_dish_id, 'Prawns Periperi Dry', 'prawns periperi dry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns periperi dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007197, variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007125, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007126, 400070007, cd.canonical_dish_id, 'Prawns Tomato Dry', 'prawns tomato dry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns tomato dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007198, variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007126, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007127, 400070007, cd.canonical_dish_id, 'Rawas Oil Fry', 'rawas oil fry', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawas oil fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007199, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007127, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Sea Food Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007128, 400070007, cd.canonical_dish_id, 'Rawas Tikka', 'rawas tikka', 'Sea Food Starter', 400070007016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawas tikka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007200, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007128, 400070007, 400070007001, menu_item_id, 400070007016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Fish Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007129, 400070007, cd.canonical_dish_id, 'Rawas Butter Tawa', 'rawas butter tawa', 'Fish Gravy', 400070007017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawas butter tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007201, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007129, 400070007, 400070007001, menu_item_id, 400070007017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Fish Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007130, 400070007, cd.canonical_dish_id, 'Rawas Changezi', 'rawas changezi', 'Fish Gravy', 400070007017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawas changezi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007202, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007130, 400070007, 400070007001, menu_item_id, 400070007017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Fish Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007131, 400070007, cd.canonical_dish_id, 'Prawns Butter Tawa', 'prawns butter tawa', 'Fish Gravy', 400070007017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns butter tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007203, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007131, 400070007, 400070007001, menu_item_id, 400070007017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Fish Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007132, 400070007, cd.canonical_dish_id, 'Prawns Changezi', 'prawns changezi', 'Fish Gravy', 400070007017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns changezi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007204, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007132, 400070007, 400070007001, menu_item_id, 400070007017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Fish Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007133, 400070007, cd.canonical_dish_id, 'Rangoon Spl Prawns Tawa', 'rangoon spl prawns tawa', 'Fish Gravy', 400070007017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon spl prawns tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007205, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007133, 400070007, 400070007001, menu_item_id, 400070007017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Fish Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007134, 400070007, cd.canonical_dish_id, 'Rangoon Spl Rawas Tawa', 'rangoon spl rawas tawa', 'Fish Gravy', 400070007017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon spl rawas tawa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007206, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007134, 400070007, 400070007001, menu_item_id, 400070007017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007135, 400070007, cd.canonical_dish_id, 'Manchow Soup', 'manchow soup', 'Chinese Soup', 400070007018, 'veg', NULL, 'rangoon|manchow soup|chinese soup', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'manchow soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007207, variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007135, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007136, 400070007, cd.canonical_dish_id, 'Manchow Soup', 'manchow soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'rangoon|manchow soup|chinese soup', 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'manchow soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007208, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007136, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007137, 400070007, cd.canonical_dish_id, 'Hot & Sour Soup', 'hot & sour soup', 'Chinese Soup', 400070007018, 'veg', NULL, 'rangoon|hot & sour soup|chinese soup', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot & sour soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007209, variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007137, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007138, 400070007, cd.canonical_dish_id, 'Hot & Sour Soup', 'hot & sour soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'rangoon|hot & sour soup|chinese soup', 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot & sour soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007210, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007138, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007139, 400070007, cd.canonical_dish_id, 'Clear Soup', 'clear soup', 'Chinese Soup', 400070007018, 'veg', NULL, 'rangoon|clear soup|chinese soup', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'clear soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007211, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007139, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007140, 400070007, cd.canonical_dish_id, 'Clear Soup', 'clear soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'rangoon|clear soup|chinese soup', 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'clear soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007212, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007140, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007141, 400070007, cd.canonical_dish_id, 'Noodles Soup', 'noodles soup', 'Chinese Soup', 400070007018, 'veg', NULL, 'rangoon|noodles soup|chinese soup', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'noodles soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007213, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007141, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007142, 400070007, cd.canonical_dish_id, 'Noodles Soup', 'noodles soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'rangoon|noodles soup|chinese soup', 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'noodles soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007214, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007142, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007143, 400070007, cd.canonical_dish_id, 'Sweet Corn Soup', 'sweet corn soup', 'Chinese Soup', 400070007018, 'veg', NULL, 'rangoon|sweet corn soup|chinese soup', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sweet corn soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007215, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007143, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007144, 400070007, cd.canonical_dish_id, 'Sweet Corn Soup', 'sweet corn soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'rangoon|sweet corn soup|chinese soup', 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sweet corn soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007216, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007144, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007145, 400070007, cd.canonical_dish_id, 'Kasoori Soup', 'kasoori soup', 'Chinese Soup', 400070007018, 'veg', NULL, 'rangoon|kasoori soup|chinese soup', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kasoori soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007217, variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007145, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007146, 400070007, cd.canonical_dish_id, 'Kasoori Soup', 'kasoori soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'rangoon|kasoori soup|chinese soup', 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kasoori soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007218, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007146, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Veg. column is "-" (not offered) for this line.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007147, 400070007, cd.canonical_dish_id, 'Mutton Soup', 'mutton soup', 'Chinese Soup', 400070007018, 'non_veg', 900002, 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007219, variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007147, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Soup" section -- Veg. column is "-" (not offered). Protein not stated beyond "Non Veg."; inferred chicken, flagged.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007148, 400070007, cd.canonical_dish_id, 'Rangoon Spl Soup', 'rangoon spl soup', 'Chinese Soup', 400070007018, 'non_veg', 900001, 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon spl soup'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007220, variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007148, 400070007, 400070007001, menu_item_id, 400070007018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007149, 400070007, cd.canonical_dish_id, 'Lollipop Oil Fry', 'lollipop oil fry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop oil fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007221, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007149, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007150, 400070007, cd.canonical_dish_id, 'Lollipop Egg Fry', 'lollipop egg fry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop egg fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007222, variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007150, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007151, 400070007, cd.canonical_dish_id, 'Lollipop Masala Dry', 'lollipop masala dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop masala dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007223, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007151, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007152, 400070007, cd.canonical_dish_id, 'Chicken Chilly Dry', 'chicken chilly dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken chilly dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007224, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007152, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007153, 400070007, cd.canonical_dish_id, 'Hunan Dry', 'hunan dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hunan dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007225, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007153, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007154, 400070007, cd.canonical_dish_id, 'Chicken Crispy Dry', 'chicken crispy dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken crispy dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007226, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007154, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007155, 400070007, cd.canonical_dish_id, 'Chicken 65 Dry', 'chicken 65 dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken 65 dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007227, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007155, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007156, 400070007, cd.canonical_dish_id, 'Black Bean Dry', 'black bean dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'black bean dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007228, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007156, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007157, 400070007, cd.canonical_dish_id, 'Black Pepper Dry', 'black pepper dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'black pepper dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007229, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007157, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007158, 400070007, cd.canonical_dish_id, 'Mongolian Dry', 'mongolian dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mongolian dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007230, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007158, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007159, 400070007, cd.canonical_dish_id, 'Chicken Dragon Dry', 'chicken dragon dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken dragon dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007231, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007159, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007160, 400070007, cd.canonical_dish_id, 'Turkey Dry', 'turkey dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'turkey dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007232, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007160, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007161, 400070007, cd.canonical_dish_id, 'Shanghai Dry', 'shanghai dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'shanghai dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007233, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007161, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007162, 400070007, cd.canonical_dish_id, 'Thai Chilly Dry', 'thai chilly dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'thai chilly dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007234, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007162, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007163, 400070007, cd.canonical_dish_id, 'Cheese Dry', 'cheese dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007235, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007163, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007164, 400070007, cd.canonical_dish_id, 'Chicken White Butter Sauce', 'chicken white butter sauce', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken white butter sauce'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007236, variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007164, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007165, 400070007, cd.canonical_dish_id, 'Pulpy Dry', 'pulpy dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pulpy dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007237, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007165, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007166, 400070007, cd.canonical_dish_id, 'Peri Peri Chicken', 'peri peri chicken', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri chicken'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007238, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007166, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007167, 400070007, cd.canonical_dish_id, 'Karachi Chicken Dry', 'karachi chicken dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'karachi chicken dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007239, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007167, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007168, 400070007, cd.canonical_dish_id, 'Lahori Chicken Dry (Bl)', 'lahori chicken dry (bl)', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lahori chicken dry (bl)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007240, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007168, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007169, 400070007, cd.canonical_dish_id, 'Plum Chicken Dry (Bl)', 'plum chicken dry (bl)', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plum chicken dry (bl)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007241, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007169, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007170, 400070007, cd.canonical_dish_id, 'Tomato Chicken Dry (Bl)', 'tomato chicken dry (bl)', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tomato chicken dry (bl)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007242, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007170, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007171, 400070007, cd.canonical_dish_id, 'Rangoon Spl Dry (Bl & Fingers)', 'rangoon spl dry (bl & fingers)', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon spl dry (bl & fingers)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007243, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007171, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007172, 400070007, cd.canonical_dish_id, 'Malai Chicken Dry (Bl)', 'malai chicken dry (bl)', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai chicken dry (bl)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007244, variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007172, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007173, 400070007, cd.canonical_dish_id, 'Nawabsahab (Roll)', 'nawabsahab (roll)', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'nawabsahab (roll)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007245, variant_id, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007173, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Starter" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007174, 400070007, cd.canonical_dish_id, 'Chk Cheese Roll Masala Dry', 'chk cheese roll masala dry', 'Chinese Starter', 400070007019, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chk cheese roll masala dry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007246, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007174, 400070007, 400070007001, menu_item_id, 400070007019 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007175, 400070007, cd.canonical_dish_id, 'Chilly Rice', 'chilly rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilly rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007247, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007247, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007175, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007176, 400070007, cd.canonical_dish_id, 'Crispy Rice', 'crispy rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'crispy rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007248, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007248, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007176, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007177, 400070007, cd.canonical_dish_id, 'Korean Rice', 'korean rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'korean rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007249, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007249, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007177, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007178, 400070007, cd.canonical_dish_id, 'Dragon Rice', 'dragon rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dragon rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007250, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007250, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007178, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007179, 400070007, cd.canonical_dish_id, 'Barista Rice', 'barista rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'barista rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007251, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007251, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007179, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007180, 400070007, cd.canonical_dish_id, 'Black Bean Rice', 'black bean rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'black bean rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007252, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007252, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007180, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007181, 400070007, cd.canonical_dish_id, 'Chopper Rice', 'chopper rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chopper rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007253, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007253, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007181, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007182, 400070007, cd.canonical_dish_id, 'Packing Rice', 'packing rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'packing rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007254, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007254, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007182, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007183, 400070007, cd.canonical_dish_id, 'Lollipop Masala Rice', 'lollipop masala rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop masala rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007255, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007255, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007183, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007184, 400070007, cd.canonical_dish_id, 'Manchurian Rice', 'manchurian rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'manchurian rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007256, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007256, variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007184, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007185, 400070007, cd.canonical_dish_id, 'Koliwada Rice', 'koliwada rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'koliwada rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007257, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007257, variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007185, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007186, 400070007, cd.canonical_dish_id, 'Cheese Rice', 'cheese rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007258, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007258, variant_id, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007186, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007187, 400070007, cd.canonical_dish_id, 'White Butter Sauce Rice', 'white butter sauce rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'white butter sauce rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007259, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007259, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007187, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007188, 400070007, cd.canonical_dish_id, 'Palpi Rice', 'palpi rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'palpi rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007260, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007260, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007188, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007189, 400070007, cd.canonical_dish_id, 'Rangoon Spl Rice', 'rangoon spl rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rangoon spl rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007261, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007261, variant_id, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007189, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007190, 400070007, cd.canonical_dish_id, 'Malaysian Rice', 'malaysian rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malaysian rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007262, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007262, variant_id, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007190, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007191, 400070007, cd.canonical_dish_id, 'Prawns Crispy Rice', 'prawns crispy rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns crispy rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007263, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007263, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007191, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007192, 400070007, cd.canonical_dish_id, 'Prawns Chilly Rice', 'prawns chilly rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns chilly rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007264, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007264, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007192, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007193, 400070007, cd.canonical_dish_id, 'Prawns Koliwada Rice', 'prawns koliwada rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns koliwada rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007265, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007265, variant_id, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007193, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007194, 400070007, cd.canonical_dish_id, 'Prawns Rangoon Spl Rice', 'prawns rangoon spl rice', 'Chinese Rice With Masala', 400070007020, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns rangoon spl rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007266, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007266, variant_id, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007194, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007195, 400070007, cd.canonical_dish_id, 'Paneer Chilly Rice', 'paneer chilly rice', 'Chinese Rice With Masala', 400070007020, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer chilly rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007267, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007267, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007195, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice With Masala" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007196, 400070007, cd.canonical_dish_id, 'Paneer Crispy Rice', 'paneer crispy rice', 'Chinese Rice With Masala', 400070007020, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer crispy rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007268, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007268, variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007196, 400070007, 400070007001, menu_item_id, 400070007020 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007197, 400070007, cd.canonical_dish_id, 'Lollipop Khepsa', 'lollipop khepsa', 'Chinese Khepsa', 400070007021, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007269, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007269, variant_id, 570.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007197, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007198, 400070007, cd.canonical_dish_id, 'Tandoori Khepsa (Chinese)', 'tandoori khepsa (chinese)', 'Chinese Khepsa', 400070007021, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori khepsa (chinese)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007270, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007270, variant_id, 670.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007198, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007199, 400070007, cd.canonical_dish_id, 'Boneless Khepsa', 'boneless khepsa', 'Chinese Khepsa', 400070007021, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'boneless khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007271, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007271, variant_id, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007199, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007200, 400070007, cd.canonical_dish_id, 'Chilly Khepsa', 'chilly khepsa', 'Chinese Khepsa', 400070007021, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilly khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007272, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007272, variant_id, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007200, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007201, 400070007, cd.canonical_dish_id, 'Dry Fruit Khepsa', 'dry fruit khepsa', 'Chinese Khepsa', 400070007021, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dry fruit khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007273, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007273, variant_id, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007201, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007202, 400070007, cd.canonical_dish_id, 'Prawns Khepsa', 'prawns khepsa', 'Chinese Khepsa', 400070007021, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007274, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007274, variant_id, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007202, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Khepsa" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007203, 400070007, cd.canonical_dish_id, 'Mutton Khepsa', 'mutton khepsa', 'Chinese Khepsa', 400070007021, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton khepsa'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007275, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007275, variant_id, 1050.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007203, 400070007, 400070007001, menu_item_id, 400070007021 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007204, 400070007, cd.canonical_dish_id, 'Chinese Biryani', 'chinese biryani', 'Chinese Biryani', 400070007022, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chinese biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007276, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007276, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007204, 400070007, 400070007001, menu_item_id, 400070007022 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007205, 400070007, cd.canonical_dish_id, 'Korean Biryani', 'korean biryani', 'Chinese Biryani', 400070007022, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'korean biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007277, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007277, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007205, 400070007, 400070007001, menu_item_id, 400070007022 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007206, 400070007, cd.canonical_dish_id, 'Dragon Biryani', 'dragon biryani', 'Chinese Biryani', 400070007022, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dragon biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007278, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007278, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007206, 400070007, 400070007001, menu_item_id, 400070007022 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Biryani" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007207, 400070007, cd.canonical_dish_id, 'Chicken 65 Biryani', 'chicken 65 biryani', 'Chinese Biryani', 400070007022, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken 65 biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007279, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007279, variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007207, 400070007, 400070007001, menu_item_id, 400070007022 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007208, 400070007, cd.canonical_dish_id, 'Chilly Gravy', 'chilly gravy', 'Chinese Gravy', 400070007023, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilly gravy'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007280, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007280, variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007208, 400070007, 400070007001, menu_item_id, 400070007023 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007209, 400070007, cd.canonical_dish_id, 'Lollipop Gravy', 'lollipop gravy', 'Chinese Gravy', 400070007023, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lollipop gravy'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007281, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007281, variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007209, 400070007, 400070007001, menu_item_id, 400070007023 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Gravy" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007210, 400070007, cd.canonical_dish_id, '65 Gravy', '65 gravy', 'Chinese Gravy', 400070007023, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = '65 gravy'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007282, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007282, variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007210, 400070007, 400070007001, menu_item_id, 400070007023 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007211, 400070007, cd.canonical_dish_id, 'Fried Rice', 'fried rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'rangoon|fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007283, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007283, variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007211, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007212, 400070007, cd.canonical_dish_id, 'Fried Rice', 'fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'rangoon|fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007284, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007284, variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007212, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007213, 400070007, cd.canonical_dish_id, 'Schezwan Fried Rice', 'schezwan fried rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'rangoon|schezwan fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007285, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007285, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007213, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007214, 400070007, cd.canonical_dish_id, 'Schezwan Fried Rice', 'schezwan fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'rangoon|schezwan fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007286, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007286, variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007214, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007215, 400070007, cd.canonical_dish_id, 'Korean Fried Rice', 'korean fried rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'rangoon|korean fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'korean fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007287, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007287, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007215, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007216, 400070007, cd.canonical_dish_id, 'Korean Fried Rice', 'korean fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'rangoon|korean fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'korean fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007288, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007288, variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007216, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007217, 400070007, cd.canonical_dish_id, 'Hong Kong Fried Rice', 'hong kong fried rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'rangoon|hong kong fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hong kong fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007289, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007289, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007217, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007218, 400070007, cd.canonical_dish_id, 'Hong Kong Fried Rice', 'hong kong fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'rangoon|hong kong fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hong kong fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007290, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007290, variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007218, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007219, 400070007, cd.canonical_dish_id, 'Singapore Fried Rice', 'singapore fried rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'rangoon|singapore fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'singapore fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007291, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007291, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007219, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007220, 400070007, cd.canonical_dish_id, 'Singapore Fried Rice', 'singapore fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'rangoon|singapore fried rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'singapore fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007292, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007292, variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007220, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007221, 400070007, cd.canonical_dish_id, 'Triple Rice', 'triple rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'rangoon|triple rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'triple rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007293, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007293, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007221, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007222, 400070007, cd.canonical_dish_id, 'Triple Rice', 'triple rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'rangoon|triple rice|chinese rice', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'triple rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007294, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007294, variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007222, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section -- Veg. column is "-" (chicken/tandoori-tikka based, not offered veg).
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007223, 400070007, cd.canonical_dish_id, 'Tikka Fried Rice', 'tikka fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tikka fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007295, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007295, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007223, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section -- Veg. column is "-" (chicken/tandoori-tikka based, not offered veg).
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007224, 400070007, cd.canonical_dish_id, 'Tikka Schezwan Fried Rice', 'tikka schezwan fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tikka schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007296, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007296, variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007224, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section -- Veg. column is "-" (chicken/tandoori-tikka based, not offered veg).
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007225, 400070007, cd.canonical_dish_id, 'Tandoori Fried Rice', 'tandoori fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900001, 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007297, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007297, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007225, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section -- Printed as a single Prawns/Chicken mix, one price -- not split into separate protein rows since it's one combined dish, not a Veg/Non-veg alternative pair.
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007226, 400070007, cd.canonical_dish_id, 'Mix Fried Rice (Prawns/Chicken)', 'mix fried rice (prawns/chicken)', 'Chinese Rice', 400070007024, 'non_veg', 900003, 'needs_review'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mix fried rice (prawns/chicken)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007298, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007298, variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'needs_review' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007226, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.75, 'needs_review' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.75 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007227, 400070007, cd.canonical_dish_id, 'Egg Fried Rice', 'egg fried rice', 'Chinese Rice', 400070007024, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007299, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007299, variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007227, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007228, 400070007, cd.canonical_dish_id, 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'Chinese Rice', 400070007024, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007300, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007300, variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007228, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007229, 400070007, cd.canonical_dish_id, 'Prawns Fried Rice', 'prawns fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007301, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007301, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007229, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007230, 400070007, cd.canonical_dish_id, 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 'Chinese Rice', 400070007024, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007302, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007302, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007230, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007231, 400070007, cd.canonical_dish_id, 'Paneer Fried Rice', 'paneer fried rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007303, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007303, variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007231, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007232, 400070007, cd.canonical_dish_id, 'Paneer Schezwan F Rice', 'paneer schezwan f rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer schezwan f rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007304, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007304, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007232, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007233, 400070007, cd.canonical_dish_id, 'Paneer Korean Fr Rice', 'paneer korean fr rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer korean fr rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007305, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007305, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007233, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007234, 400070007, cd.canonical_dish_id, 'Paneer Hongkong Fr Rice', 'paneer hongkong fr rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hongkong fr rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007306, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007306, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007234, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Rice" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007235, 400070007, cd.canonical_dish_id, 'Paneer Triple Rice', 'paneer triple rice', 'Chinese Rice', 400070007024, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer triple rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007307, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007307, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007235, 400070007, 400070007001, menu_item_id, 400070007024 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007236, 400070007, cd.canonical_dish_id, 'Hakka Noodles', 'hakka noodles', 'Chinese Noodles', 400070007025, 'veg', NULL, 'rangoon|hakka noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hakka noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007308, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007308, variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007236, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007237, 400070007, cd.canonical_dish_id, 'Hakka Noodles', 'hakka noodles', 'Chinese Noodles', 400070007025, 'non_veg', 900001, 'rangoon|hakka noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hakka noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007309, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007309, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007237, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007238, 400070007, cd.canonical_dish_id, 'Schezwan Noodles', 'schezwan noodles', 'Chinese Noodles', 400070007025, 'veg', NULL, 'rangoon|schezwan noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007310, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007310, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007238, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007239, 400070007, cd.canonical_dish_id, 'Schezwan Noodles', 'schezwan noodles', 'Chinese Noodles', 400070007025, 'non_veg', 900001, 'rangoon|schezwan noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007311, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007311, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007239, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007240, 400070007, cd.canonical_dish_id, 'Singapore Noodles', 'singapore noodles', 'Chinese Noodles', 400070007025, 'veg', NULL, 'rangoon|singapore noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'singapore noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007312, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007312, variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007240, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007241, 400070007, cd.canonical_dish_id, 'Singapore Noodles', 'singapore noodles', 'Chinese Noodles', 400070007025, 'non_veg', 900001, 'rangoon|singapore noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'singapore noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007313, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007313, variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007241, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007242, 400070007, cd.canonical_dish_id, 'Hongkong Noodles', 'hongkong noodles', 'Chinese Noodles', 400070007025, 'veg', NULL, 'rangoon|hongkong noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hongkong noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007314, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007314, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007242, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007243, 400070007, cd.canonical_dish_id, 'Hongkong Noodles', 'hongkong noodles', 'Chinese Noodles', 400070007025, 'non_veg', 900001, 'rangoon|hongkong noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hongkong noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007315, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007315, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007243, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007244, 400070007, cd.canonical_dish_id, 'Korean Noodles', 'korean noodles', 'Chinese Noodles', 400070007025, 'veg', NULL, 'rangoon|korean noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'korean noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007316, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007316, variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007244, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007245, 400070007, cd.canonical_dish_id, 'Korean Noodles', 'korean noodles', 'Chinese Noodles', 400070007025, 'non_veg', 900001, 'rangoon|korean noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'korean noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007317, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007317, variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007245, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007246, 400070007, cd.canonical_dish_id, 'Triple Noodles', 'triple noodles', 'Chinese Noodles', 400070007025, 'veg', NULL, 'rangoon|triple noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'triple noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007318, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007318, variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007246, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Chinese Noodles" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, split_group_key, verification_status_code)
  SELECT 400070007247, 400070007, cd.canonical_dish_id, 'Triple Noodles', 'triple noodles', 'Chinese Noodles', 400070007025, 'non_veg', 900001, 'rangoon|triple noodles|chinese noodles', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'triple noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007319, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007319, variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007247, 400070007, 400070007001, menu_item_id, 400070007025 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dessert" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007248, 400070007, cd.canonical_dish_id, 'Caramal Custurd', 'caramal custurd', 'Dessert', 400070007026, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'caramal custurd'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007320, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007320, variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007248, 400070007, 400070007001, menu_item_id, 400070007026 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dessert" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007249, 400070007, cd.canonical_dish_id, 'Rabdi', 'rabdi', 'Dessert', 400070007026, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rabdi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007321, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007321, variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007249, 400070007, 400070007001, menu_item_id, 400070007026 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dessert" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007250, 400070007, cd.canonical_dish_id, 'Arabian Pudding', 'arabian pudding', 'Dessert', 400070007026, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'arabian pudding'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007322, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007322, variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007250, 400070007, 400070007001, menu_item_id, 400070007026 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

-- Source: JSON, "Dessert" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400070007251, 400070007, cd.canonical_dish_id, 'Sitafal Cream', 'sitafal cream', 'Dessert', 400070007026, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sitafal cream'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400070007323, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400070007323, variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070007, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 400070007251, 400070007, 400070007001, menu_item_id, 400070007026 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 400070007, 400070007500, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400070007, 400070007500, 0.95 FROM (
  SELECT price_id FROM new_price_1
) AS all_prices;

COMMIT;

-- NEEDS_REVIEW:
--  - menu_item 400070007136 "Manchow Soup": Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
--  - menu_item 400070007138 "Hot & Sour Soup": Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
--  - menu_item 400070007140 "Clear Soup": Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
--  - menu_item 400070007142 "Noodles Soup": Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
--  - menu_item 400070007144 "Sweet Corn Soup": Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
--  - menu_item 400070007146 "Kasoori Soup": Column header only says "Non Veg." -- protein inferred as chicken (no other protein stated for this pair); flagged, not asserted with full confidence.
--  - menu_item 400070007147 "Mutton Soup": Veg. column is "-" (not offered) for this line.
--  - menu_item 400070007148 "Rangoon Spl Soup": Veg. column is "-" (not offered). Protein not stated beyond "Non Veg."; inferred chicken, flagged.
--  - menu_item 400070007223 "Tikka Fried Rice": Veg. column is "-" (chicken/tandoori-tikka based, not offered veg).
--  - menu_item 400070007224 "Tikka Schezwan Fried Rice": Veg. column is "-" (chicken/tandoori-tikka based, not offered veg).
--  - menu_item 400070007225 "Tandoori Fried Rice": Veg. column is "-" (chicken/tandoori-tikka based, not offered veg).
--  - menu_item 400070007226 "Mix Fried Rice (Prawns/Chicken)": Printed as a single Prawns/Chicken mix, one price -- not split into separate protein rows since it's one combined dish, not a Veg/Non-veg alternative pair.

-- UNMAPPED (see also the header notes above):
--  - HALAL marking: no confirmed HALAL platform_tag row to match against
--    (lookup tables are read-only in this script) -- flagged rather than assumed.
--  - GST No. 27BMKPK2607N1ZP, FSSAI Lic No. 11518007000075, email
--    info@rangoonzaika.com, www.rangoonzaika.com, Instagram rangoon_zaika__70
--    -- no columns for any of these anywhere in the schema.
--  - No operating hours stated anywhere in the JSON -- restaurant_hours is empty.

-- Summary: 1 restaurant, 26 categories, 1 menu board, 251 menu items,
-- 323 variants, 323 prices, 233 canonical dishes,
-- 12 items flagged needs_review.