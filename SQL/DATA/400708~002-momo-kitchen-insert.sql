/* ============================================================================
   KHAUSTAN -- RESTAURANT ONBOARDING (JSON source): Momo Kitchen
   Source: momo_kitchen_menu_ocr.json
   Target: KhaustanRestaurantMenu database.
   ESTABLISHMENT_ID = 400708002 (given directly in the JSON's own restaurant block).

   Per the schema reference now on file (confirmed real DDL/lookup state):
   ck_menu_item_price_amount already compares is_market_price to TRUE/FALSE
   correctly in the current schema -- no workaround needed. No bar items on
   this menu, so bar_product_type is not touched.

   No \connect meta-command (psql-only, breaks pgAdmin4's Query Tool --
   confirmed earlier this session); connect the Query Tool directly instead.

   JSON-only sourcing: address and phone are both blank in the JSON's own
   restaurant block -- left NULL/not inserted rather than guessed. State
   defaults to 'Maharashtra' per this prompt's own stated default (no state
   given in the JSON).

   Two items ("Veg Schezwan Momo", "Veg Shanghai Momo" under STIR FRIED
   MOMO) are printed twice in the JSON -- once with a real price, once with
   price blank. Read as an OCR duplication artifact, not a second variant;
   the blank-price duplicate is dropped, not inserted as a second menu_item.

   The two combo offers (Veg Combo, Chicken Combo) list their components as
   sub-lines with no individual price and one combo_price for the set. Each
   is modeled as a single menu_item (name includes the component list) at
   the combo_price, the same pattern used for compound platters on earlier
   restaurants this session, rather than full bundle_component modeling --
   SOFT DRINK (SPRITE) isn't separately orderable elsewhere on this menu, so
   not every component has a standalone menu_item to link to anyway.
   ============================================================================ */

BEGIN;

DO $do$
DECLARE v_max BIGINT;
BEGIN
  SELECT GREATEST(
    COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
    COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0)
  ) INTO v_max;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS momo_other_id_seq START WITH %s', v_max + 1);
END $do$;

DO $do$
DECLARE v_already_done BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400708002
    AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'momo_kitchen_menu_ocr.json')
    AND status_code = 'completed') INTO v_already_done;
  IF v_already_done THEN RAISE EXCEPTION 'Already loaded for restaurant 400708002.'; END IF;
END $do$;

INSERT INTO establishment (establishment_id, name, normalized_name, locality, city, state, country_code, latitude, longitude)
VALUES (400708002, 'Momo Kitchen', 'momo kitchen', 'Airoli', 'Navi Mumbai', 'Maharashtra', 'IN', 19.15727931778224, 72.99849719188522);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, description, has_bar, bar_license_type)
VALUES (400708002, 400708002, 'Momo Kitchen', 'momo kitchen', 'Fast food, veg and non-veg momo specialist. Previously known as "House of Momo."', FALSE, 'none');

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400708002, 'ai_menu_extraction', 'momo_kitchen_menu_ocr.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
VALUES (400708002500, 400708002, 400708002, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, currency_code)
VALUES (400708002, TRUE, TRUE, 'INR');

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, notes)
VALUES (400708002, 3, NULL), (400708002, 4, 'Free home delivery stated; no named aggregator partner in the JSON');

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code) VALUES (400708002001, 400708002, 'Momo Kitchen Menu', 'a_la_carte');

INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence) VALUES
  (400708002001, 400708002, 'Steam Momo', 1),
  (400708002002, 400708002, 'Fried Momo', 2),
  (400708002003, 400708002, 'Our Speciality Momo > Tandoori Momo (6 Pcs.)', 3),
  (400708002004, 400708002, 'Our Speciality Momo > Creamy Tandoori Momo (6 Pcs.)', 4),
  (400708002005, 400708002, 'Stir Fried Momo (6 Pcs.)', 5),
  (400708002006, 400708002, 'Momozaa (6 Pcs.)', 6),
  (400708002007, 400708002, 'Soupy Meal Bowl (4 Pcs.)', 7),
  (400708002008, 400708002, 'Fries', 8),
  (400708002009, 400708002, 'Burger', 9),
  (400708002010, 400708002, 'Beverage', 10),
  (400708002011, 400708002, 'Shakes', 11),
  (400708002012, 400708002, 'Hot Beverage', 12),
  (400708002013, 400708002, 'Mojito', 13),
  (400708002014, 400708002, 'Special Combo Offer', 14);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
  (400708002, 400708002001, 400708002001, 1),
  (400708002, 400708002001, 400708002002, 2),
  (400708002, 400708002001, 400708002003, 3),
  (400708002, 400708002001, 400708002004, 4),
  (400708002, 400708002001, 400708002005, 5),
  (400708002, 400708002001, 400708002006, 6),
  (400708002, 400708002001, 400708002007, 7),
  (400708002, 400708002001, 400708002008, 8),
  (400708002, 400708002001, 400708002009, 9),
  (400708002, 400708002001, 400708002010, 10),
  (400708002, 400708002001, 400708002011, 11),
  (400708002, 400708002001, 400708002012, 12),
  (400708002, 400708002001, 400708002013, 13),
  (400708002, 400708002001, 400708002014, 14);

WITH nd_46399841 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Momo', 'veg momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Momo', 'veg momo', 'primary' FROM nd_46399841;

WITH nd_54419390 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Peri Peri Veg Momo', 'peri peri veg momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri veg momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Veg Momo', 'peri peri veg momo', 'primary' FROM nd_54419390;

WITH nd_91766191 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Paneer Momo', 'paneer momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Paneer Momo', 'paneer momo', 'primary' FROM nd_91766191;

WITH nd_49108243 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Peri Peri Paneer Momo', 'peri peri paneer momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri paneer momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Paneer Momo', 'peri peri paneer momo', 'primary' FROM nd_49108243;

WITH nd_3577198 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Achari Paneer Momo', 'achari paneer momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'achari paneer momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Achari Paneer Momo', 'achari paneer momo', 'primary' FROM nd_3577198;

WITH nd_31695692 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Paneer Tikka Momo', 'paneer tikka momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Momo', 'paneer tikka momo', 'primary' FROM nd_31695692;

WITH nd_14815298 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), '3C Momo', '3c momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = '3c momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', '3C Momo', '3c momo', 'primary' FROM nd_14815298;

WITH nd_47690654 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cheese Bomb Momo', 'cheese bomb momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese bomb momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cheese Bomb Momo', 'cheese bomb momo', 'primary' FROM nd_47690654;

WITH nd_87669710 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Momo', 'chicken momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Momo', 'chicken momo', 'primary' FROM nd_87669710;

WITH nd_35735115 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Peri Peri Chicken Momo', 'peri peri chicken momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri chicken momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Chicken Momo', 'peri peri chicken momo', 'primary' FROM nd_35735115;

WITH nd_37322878 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Tikka Momo', 'chicken tikka momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Momo', 'chicken tikka momo', 'primary' FROM nd_37322878;

WITH nd_54356509 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Achari Chicken Momo', 'achari chicken momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'achari chicken momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Achari Chicken Momo', 'achari chicken momo', 'primary' FROM nd_54356509;

WITH nd_87108685 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cheese Chicken Momo', 'cheese chicken momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chicken momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chicken Momo', 'cheese chicken momo', 'primary' FROM nd_87108685;

WITH nd_62158039 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Peri Peri Cheese Chicken Momo', 'peri peri cheese chicken momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri cheese chicken momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Cheese Chicken Momo', 'peri peri cheese chicken momo', 'primary' FROM nd_62158039;

WITH nd_51331279 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Tandoori Momo', 'veg tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Tandoori Momo', 'veg tandoori momo', 'primary' FROM nd_51331279;

WITH nd_5857296 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Paneer Tandoori Momo', 'paneer tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tandoori Momo', 'paneer tandoori momo', 'primary' FROM nd_5857296;

WITH nd_59467782 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), '3C Tandoori Momo', '3c tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = '3c tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', '3C Tandoori Momo', '3c tandoori momo', 'primary' FROM nd_59467782;

WITH nd_4796424 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Tandoori Momo', 'chicken tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Momo', 'chicken tandoori momo', 'primary' FROM nd_4796424;

WITH nd_85575655 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cheese Chicken Tandoori Momo', 'cheese chicken tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chicken tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chicken Tandoori Momo', 'cheese chicken tandoori momo', 'primary' FROM nd_85575655;

WITH nd_93965549 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Creamy Tandoori Momo', 'veg creamy tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg creamy tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Creamy Tandoori Momo', 'veg creamy tandoori momo', 'primary' FROM nd_93965549;

WITH nd_19443194 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Paneer Creamy Tandoori Momo', 'paneer creamy tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer creamy tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Paneer Creamy Tandoori Momo', 'paneer creamy tandoori momo', 'primary' FROM nd_19443194;

WITH nd_59528777 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), '3C Creamy Tandoori Momo', '3c creamy tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = '3c creamy tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', '3C Creamy Tandoori Momo', '3c creamy tandoori momo', 'primary' FROM nd_59528777;

WITH nd_43145476 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Creamy Tandoori Momo', 'chicken creamy tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken creamy tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Creamy Tandoori Momo', 'chicken creamy tandoori momo', 'primary' FROM nd_43145476;

WITH nd_11212183 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cheese Chicken Creamy Tandoori Momo', 'cheese chicken creamy tandoori momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chicken creamy tandoori momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chicken Creamy Tandoori Momo', 'cheese chicken creamy tandoori momo', 'primary' FROM nd_11212183;

WITH nd_45620602 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Schezwan Momo', 'veg schezwan momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Momo', 'veg schezwan momo', 'primary' FROM nd_45620602;

WITH nd_88732749 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Shanghai Momo', 'veg shanghai momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg shanghai momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Shanghai Momo', 'veg shanghai momo', 'primary' FROM nd_88732749;

WITH nd_83811760 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Paneer Schezwan Momo', 'paneer schezwan momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Paneer Schezwan Momo', 'paneer schezwan momo', 'primary' FROM nd_83811760;

WITH nd_52103633 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Paneer Shanghai Momo', 'paneer shanghai momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer shanghai momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Paneer Shanghai Momo', 'paneer shanghai momo', 'primary' FROM nd_52103633;

WITH nd_52514031 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Schezwan Momo', 'chicken schezwan momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Momo', 'chicken schezwan momo', 'primary' FROM nd_52514031;

WITH nd_25907272 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Shanghai Momo', 'chicken shanghai momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken shanghai momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Shanghai Momo', 'chicken shanghai momo', 'primary' FROM nd_25907272;

WITH nd_69613792 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cheese Chicken Schezwan Momo', 'cheese chicken schezwan momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chicken schezwan momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chicken Schezwan Momo', 'cheese chicken schezwan momo', 'primary' FROM nd_69613792;

WITH nd_4956813 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cheese Chicken Shanghai Momo', 'cheese chicken shanghai momo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chicken shanghai momo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chicken Shanghai Momo', 'cheese chicken shanghai momo', 'primary' FROM nd_4956813;

WITH nd_54162952 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), '3C Momozza', '3c momozza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = '3c momozza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', '3C Momozza', '3c momozza', 'primary' FROM nd_54162952;

WITH nd_6217323 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Momozza', 'chicken momozza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken momozza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Momozza', 'chicken momozza', 'primary' FROM nd_6217323;

WITH nd_46446575 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Momo Soupy Bowl', 'veg momo soupy bowl'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg momo soupy bowl')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Momo Soupy Bowl', 'veg momo soupy bowl', 'primary' FROM nd_46446575;

WITH nd_91639008 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Momo Soupy Bowl', 'chicken momo soupy bowl'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken momo soupy bowl')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Momo Soupy Bowl', 'chicken momo soupy bowl', 'primary' FROM nd_91639008;

WITH nd_1502012 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'French Fries', 'french fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'french fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'French Fries', 'french fries', 'primary' FROM nd_1502012;

WITH nd_65339823 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Peri Peri Fries', 'peri peri fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Fries', 'peri peri fries', 'primary' FROM nd_65339823;

WITH nd_9346319 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chilly Cheese Fries', 'chilly cheese fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly cheese fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chilly Cheese Fries', 'chilly cheese fries', 'primary' FROM nd_9346319;

WITH nd_33047876 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Peri Peri Cheese Fries', 'peri peri cheese fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri cheese fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri Cheese Fries', 'peri peri cheese fries', 'primary' FROM nd_33047876;

WITH nd_42602316 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Veg Burger', 'veg burger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg burger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Veg Burger', 'veg burger', 'primary' FROM nd_42602316;

WITH nd_86587574 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Chicken Burger', 'chicken burger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken burger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Chicken Burger', 'chicken burger', 'primary' FROM nd_86587574;

WITH nd_43833360 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Banta Soda', 'banta soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'banta soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Banta Soda', 'banta soda', 'primary' FROM nd_43833360;

WITH nd_33043684 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Lemon Ice Tea', 'lemon ice tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon ice tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Lemon Ice Tea', 'lemon ice tea', 'primary' FROM nd_33043684;

WITH nd_19575865 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Cold Coffee', 'cold coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cold coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Cold Coffee', 'cold coffee', 'primary' FROM nd_19575865;

WITH nd_20900476 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Oreo Shake', 'oreo shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'oreo shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Oreo Shake', 'oreo shake', 'primary' FROM nd_20900476;

WITH nd_22578127 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Hot Coffee', 'hot coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Hot Coffee', 'hot coffee', 'primary' FROM nd_22578127;

WITH nd_38074823 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Hot Chocolate', 'hot chocolate'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot chocolate')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Hot Chocolate', 'hot chocolate', 'primary' FROM nd_38074823;

WITH nd_54362850 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Green Mint', 'green mint'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green mint')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Green Mint', 'green mint', 'primary' FROM nd_54362850;

WITH nd_22552908 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Blue Caraveo', 'blue caraveo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'blue caraveo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Blue Caraveo', 'blue caraveo', 'primary' FROM nd_22552908;

WITH nd_97756511 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Combo 1 - Veg Combo (Veg Burger + 4 Pcs Veg Momos + Soft Drink (Sprite))', 'combo 1 - veg combo (veg burger 4 pcs veg momos soft drink (sprite))'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'combo 1 - veg combo (veg burger 4 pcs veg momos soft drink (sprite))')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Combo 1 - Veg Combo (Veg Burger + 4 Pcs Veg Momos + Soft Drink (Sprite))', 'combo 1 - veg combo (veg burger 4 pcs veg momos soft drink (sprite))', 'primary' FROM nd_97756511;

WITH nd_58932621 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('momo_other_id_seq'), 'Combo 2 - Chicken Combo (Chicken Burger + 4 Pcs Chicken Momos + Soft Drink (Sprite))', 'combo 2 - chicken combo (chicken burger 4 pcs chicken momos soft drink (sprite))'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'combo 2 - chicken combo (chicken burger 4 pcs chicken momos soft drink (sprite))')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('momo_other_id_seq'), canonical_dish_id, 'en', 'Combo 2 - Chicken Combo (Chicken Burger + 4 Pcs Chicken Momos + Soft Drink (Sprite))', 'combo 2 - chicken combo (chicken burger 4 pcs chicken momos soft drink (sprite))', 'primary' FROM nd_58932621;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002001, 400708002, cd.canonical_dish_id, 'Veg Momo', 'veg momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002001, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002001, variant_id, 69, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002002, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002002, variant_id, 119, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002001, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002002, 400708002, cd.canonical_dish_id, 'Peri Peri Veg Momo', 'peri peri veg momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri veg momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002003, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002003, variant_id, 75, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002004, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002004, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002002, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002003, 400708002, cd.canonical_dish_id, 'Paneer Momo', 'paneer momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002005, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002005, variant_id, 79, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002006, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002006, variant_id, 145, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002003, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002004, 400708002, cd.canonical_dish_id, 'Peri Peri Paneer Momo', 'peri peri paneer momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri paneer momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002007, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002007, variant_id, 85, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002008, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002008, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002004, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002005, 400708002, cd.canonical_dish_id, 'Achari Paneer Momo', 'achari paneer momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'achari paneer momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002009, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002009, variant_id, 85, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002010, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002010, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002005, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002006, 400708002, cd.canonical_dish_id, 'Paneer Tikka Momo', 'paneer tikka momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002011, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002011, variant_id, 85, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002012, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002012, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002006, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002007, 400708002, cd.canonical_dish_id, '3C Momo', '3c momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = '3c momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002013, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002013, variant_id, 129, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002014, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002014, variant_id, 229, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002007, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002008, 400708002, cd.canonical_dish_id, 'Cheese Bomb Momo', 'cheese bomb momo', 'STEAM MOMO', 400708002001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese bomb momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002015, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002015, variant_id, 129, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002016, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002016, variant_id, 229, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002008, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002009, 400708002, cd.canonical_dish_id, 'Chicken Momo', 'chicken momo', 'STEAM MOMO', 400708002001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002017, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002017, variant_id, 79, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002018, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002018, variant_id, 145, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002009, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002010, 400708002, cd.canonical_dish_id, 'Peri Peri Chicken Momo', 'peri peri chicken momo', 'STEAM MOMO', 400708002001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002019, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002019, variant_id, 85, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002020, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002020, variant_id, 159, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002010, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002011, 400708002, cd.canonical_dish_id, 'Chicken Tikka Momo', 'chicken tikka momo', 'STEAM MOMO', 400708002001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002021, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002021, variant_id, 85, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002022, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002022, variant_id, 159, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002011, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002012, 400708002, cd.canonical_dish_id, 'Achari Chicken Momo', 'achari chicken momo', 'STEAM MOMO', 400708002001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'achari chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002023, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002023, variant_id, 85, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002024, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002024, variant_id, 159, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002012, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002013, 400708002, cd.canonical_dish_id, 'Cheese Chicken Momo', 'cheese chicken momo', 'STEAM MOMO', 400708002001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002025, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002025, variant_id, 119, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002026, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002026, variant_id, 219, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002013, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "STEAM MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002014, 400708002, cd.canonical_dish_id, 'Peri Peri Cheese Chicken Momo', 'peri peri cheese chicken momo', 'STEAM MOMO', 400708002001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri cheese chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002027, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002027, variant_id, 125, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002028, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002028, variant_id, 229, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002014, 400708002, 400708002001, menu_item_id, 400708002001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002015, 400708002, cd.canonical_dish_id, 'Veg Momo', 'veg momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002029, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002029, variant_id, 72, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002030, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002030, variant_id, 125, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002015, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002016, 400708002, cd.canonical_dish_id, 'Peri Peri Veg Momo', 'peri peri veg momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri veg momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002031, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002031, variant_id, 79, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002032, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002032, variant_id, 139, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002016, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002017, 400708002, cd.canonical_dish_id, 'Paneer Momo', 'paneer momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002033, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002033, variant_id, 82, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002034, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002034, variant_id, 152, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002017, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002018, 400708002, cd.canonical_dish_id, 'Peri Peri Paneer Momo', 'peri peri paneer momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri paneer momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002035, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002035, variant_id, 89, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002036, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002036, variant_id, 162, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002018, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002019, 400708002, cd.canonical_dish_id, 'Achari Paneer Momo', 'achari paneer momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'achari paneer momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002037, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002037, variant_id, 89, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002038, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002038, variant_id, 162, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002019, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002020, 400708002, cd.canonical_dish_id, 'Paneer Tikka Momo', 'paneer tikka momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002039, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002039, variant_id, 89, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002040, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002040, variant_id, 165, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002020, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002021, 400708002, cd.canonical_dish_id, '3C Momo', '3c momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = '3c momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002041, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002041, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002042, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002042, variant_id, 239, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002021, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002022, 400708002, cd.canonical_dish_id, 'Cheese Bomb Momo', 'cheese bomb momo', 'FRIED MOMO', 400708002002, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese bomb momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002043, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002043, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002044, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002044, variant_id, 239, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002022, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002023, 400708002, cd.canonical_dish_id, 'Chicken Momo', 'chicken momo', 'FRIED MOMO', 400708002002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002045, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002045, variant_id, 82, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002046, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002046, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002023, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002024, 400708002, cd.canonical_dish_id, 'Peri Peri Chicken Momo', 'peri peri chicken momo', 'FRIED MOMO', 400708002002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002047, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002047, variant_id, 89, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002048, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002048, variant_id, 169, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002024, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002025, 400708002, cd.canonical_dish_id, 'Chicken Tikka Momo', 'chicken tikka momo', 'FRIED MOMO', 400708002002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002049, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002049, variant_id, 89, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002050, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002050, variant_id, 169, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002025, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002026, 400708002, cd.canonical_dish_id, 'Achari Chicken Momo', 'achari chicken momo', 'FRIED MOMO', 400708002002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'achari chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002051, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002051, variant_id, 89, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002052, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002052, variant_id, 169, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002026, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002027, 400708002, cd.canonical_dish_id, 'Cheese Chicken Momo', 'cheese chicken momo', 'FRIED MOMO', 400708002002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002053, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002053, variant_id, 125, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002054, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002054, variant_id, 229, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002027, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "FRIED MOMO" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002028, 400708002, cd.canonical_dish_id, 'Peri Peri Cheese Chicken Momo', 'peri peri cheese chicken momo', 'FRIED MOMO', 400708002002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri cheese chicken momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002055, menu_item_id, 'Mini (4 Pcs)', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002055, variant_id, 129, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nv_2 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002056, menu_item_id, 'Regular (8 Pcs)', 'fixed', FALSE FROM new_item RETURNING variant_id),
np_2 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002056, variant_id, 239, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_2 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002028, 400708002, 400708002001, menu_item_id, 400708002002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1
  UNION ALL SELECT price_id FROM np_2) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002029, 400708002, cd.canonical_dish_id, 'Veg Tandoori Momo', 'veg tandoori momo', 'OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)', 400708002003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002057, variant_id, 145, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002029, 400708002, 400708002001, menu_item_id, 400708002003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002030, 400708002, cd.canonical_dish_id, 'Paneer Tandoori Momo', 'paneer tandoori momo', 'OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)', 400708002003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002058, variant_id, 169, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002030, 400708002, 400708002001, menu_item_id, 400708002003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002031, 400708002, cd.canonical_dish_id, '3C Tandoori Momo', '3c tandoori momo', 'OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)', 400708002003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = '3c tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002059, variant_id, 199, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002031, 400708002, 400708002001, menu_item_id, 400708002003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002032, 400708002, cd.canonical_dish_id, 'Chicken Tandoori Momo', 'chicken tandoori momo', 'OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)', 400708002003, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002060, variant_id, 169, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002032, 400708002, 400708002001, menu_item_id, 400708002003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002033, 400708002, cd.canonical_dish_id, 'Cheese Chicken Tandoori Momo', 'cheese chicken tandoori momo', 'OUR SPECIALITY MOMO > TANDOORI MOMO (6 Pcs.)', 400708002003, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chicken tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002061, variant_id, 199, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002033, 400708002, 400708002001, menu_item_id, 400708002003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002034, 400708002, cd.canonical_dish_id, 'Veg Creamy Tandoori Momo', 'veg creamy tandoori momo', 'OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)', 400708002004, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg creamy tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002062, variant_id, 175, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002034, 400708002, 400708002001, menu_item_id, 400708002004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002035, 400708002, cd.canonical_dish_id, 'Paneer Creamy Tandoori Momo', 'paneer creamy tandoori momo', 'OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)', 400708002004, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer creamy tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002063, variant_id, 199, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002035, 400708002, 400708002001, menu_item_id, 400708002004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002036, 400708002, cd.canonical_dish_id, '3C Creamy Tandoori Momo', '3c creamy tandoori momo', 'OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)', 400708002004, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = '3c creamy tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002064, variant_id, 229, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002036, 400708002, 400708002001, menu_item_id, 400708002004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002037, 400708002, cd.canonical_dish_id, 'Chicken Creamy Tandoori Momo', 'chicken creamy tandoori momo', 'OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)', 400708002004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken creamy tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002065, variant_id, 199, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002037, 400708002, 400708002001, menu_item_id, 400708002004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002038, 400708002, cd.canonical_dish_id, 'Cheese Chicken Creamy Tandoori Momo', 'cheese chicken creamy tandoori momo', 'OUR SPECIALITY MOMO > CREAMY TANDOORI MOMO (6 Pcs.)', 400708002004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chicken creamy tandoori momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002066, variant_id, 229, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002038, 400708002, 400708002001, menu_item_id, 400708002004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002039, 400708002, cd.canonical_dish_id, 'Veg Schezwan Momo', 'veg schezwan momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002067, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002039, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002040, 400708002, cd.canonical_dish_id, 'Veg Shanghai Momo', 'veg shanghai momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg shanghai momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002068, variant_id, 165, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002040, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002041, 400708002, cd.canonical_dish_id, 'Paneer Schezwan Momo', 'paneer schezwan momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer schezwan momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002069, variant_id, 179, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002041, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002042, 400708002, cd.canonical_dish_id, 'Paneer Shanghai Momo', 'paneer shanghai momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer shanghai momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002070, variant_id, 189, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002042, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002043, 400708002, cd.canonical_dish_id, 'Chicken Schezwan Momo', 'chicken schezwan momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken schezwan momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002071, variant_id, 179, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002043, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002044, 400708002, cd.canonical_dish_id, 'Chicken Shanghai Momo', 'chicken shanghai momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken shanghai momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002072, variant_id, 189, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002044, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002045, 400708002, cd.canonical_dish_id, 'Cheese Chicken Schezwan Momo', 'cheese chicken schezwan momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chicken schezwan momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002073, variant_id, 209, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002045, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "STIR FRIED MOMO (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002046, 400708002, cd.canonical_dish_id, 'Cheese Chicken Shanghai Momo', 'cheese chicken shanghai momo', 'STIR FRIED MOMO (6 Pcs.)', 400708002005, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chicken shanghai momo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002074, variant_id, 219, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002046, 400708002, 400708002001, menu_item_id, 400708002005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOMOZAA (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002047, 400708002, cd.canonical_dish_id, '3C Momozza', '3c momozza', 'MOMOZAA (6 Pcs.)', 400708002006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = '3c momozza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002075, variant_id, 249, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002047, 400708002, 400708002001, menu_item_id, 400708002006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOMOZAA (6 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002048, 400708002, cd.canonical_dish_id, 'Chicken Momozza', 'chicken momozza', 'MOMOZAA (6 Pcs.)', 400708002006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken momozza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002076, variant_id, 249, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002048, 400708002, 400708002001, menu_item_id, 400708002006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUPY MEAL BOWL (4 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002049, 400708002, cd.canonical_dish_id, 'Veg Momo Soupy Bowl', 'veg momo soupy bowl', 'SOUPY MEAL BOWL (4 Pcs.)', 400708002007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg momo soupy bowl'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002077, variant_id, 169, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002049, 400708002, 400708002001, menu_item_id, 400708002007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUPY MEAL BOWL (4 Pcs.)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002050, 400708002, cd.canonical_dish_id, 'Chicken Momo Soupy Bowl', 'chicken momo soupy bowl', 'SOUPY MEAL BOWL (4 Pcs.)', 400708002007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken momo soupy bowl'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002078, variant_id, 179, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002050, 400708002, 400708002001, menu_item_id, 400708002007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FRIES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002051, 400708002, cd.canonical_dish_id, 'French Fries', 'french fries', 'FRIES', 400708002008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'french fries'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002079, variant_id, 089, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002051, 400708002, 400708002001, menu_item_id, 400708002008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FRIES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002052, 400708002, cd.canonical_dish_id, 'Peri Peri Fries', 'peri peri fries', 'FRIES', 400708002008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri fries'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002080, variant_id, 105, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002052, 400708002, 400708002001, menu_item_id, 400708002008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FRIES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002053, 400708002, cd.canonical_dish_id, 'Chilly Cheese Fries', 'chilly cheese fries', 'FRIES', 400708002008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilly cheese fries'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002081, variant_id, 119, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002053, 400708002, 400708002001, menu_item_id, 400708002008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FRIES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002054, 400708002, cd.canonical_dish_id, 'Peri Peri Cheese Fries', 'peri peri cheese fries', 'FRIES', 400708002008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri cheese fries'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002082, variant_id, 119, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002054, 400708002, 400708002001, menu_item_id, 400708002008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BURGER" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002055, 400708002, cd.canonical_dish_id, 'Veg Burger', 'veg burger', 'BURGER', 400708002009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg burger'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002083, variant_id, 75, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002055, 400708002, 400708002001, menu_item_id, 400708002009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BURGER" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002056, 400708002, cd.canonical_dish_id, 'Chicken Burger', 'chicken burger', 'BURGER', 400708002009, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken burger'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002084, variant_id, 99, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002056, 400708002, 400708002001, menu_item_id, 400708002009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BEVERAGE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002057, 400708002, cd.canonical_dish_id, 'Banta Soda', 'banta soda', 'BEVERAGE', 400708002010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'banta soda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002085, variant_id, 59, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002057, 400708002, 400708002001, menu_item_id, 400708002010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BEVERAGE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002058, 400708002, cd.canonical_dish_id, 'Lemon Ice Tea', 'lemon ice tea', 'BEVERAGE', 400708002010, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lemon ice tea'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002086, variant_id, 69, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002058, 400708002, 400708002001, menu_item_id, 400708002010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002059, 400708002, cd.canonical_dish_id, 'Cold Coffee', 'cold coffee', 'SHAKES', 400708002011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cold coffee'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002087, variant_id, 119, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002059, 400708002, 400708002001, menu_item_id, 400708002011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002060, 400708002, cd.canonical_dish_id, 'Oreo Shake', 'oreo shake', 'SHAKES', 400708002011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'oreo shake'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002088, variant_id, 129, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002060, 400708002, 400708002001, menu_item_id, 400708002011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "HOT BEVERAGE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002061, 400708002, cd.canonical_dish_id, 'Hot Coffee', 'hot coffee', 'HOT BEVERAGE', 400708002012, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot coffee'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002089, variant_id, 99, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002061, 400708002, 400708002001, menu_item_id, 400708002012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "HOT BEVERAGE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002062, 400708002, cd.canonical_dish_id, 'Hot Chocolate', 'hot chocolate', 'HOT BEVERAGE', 400708002012, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot chocolate'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002090, variant_id, 99, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002062, 400708002, 400708002001, menu_item_id, 400708002012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "Mojito" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002063, 400708002, cd.canonical_dish_id, 'Green Mint', 'green mint', 'Mojito', 400708002013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'green mint'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002091, variant_id, 99, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002063, 400708002, 400708002001, menu_item_id, 400708002013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "Mojito" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002064, 400708002, cd.canonical_dish_id, 'Blue Caraveo', 'blue caraveo', 'Mojito', 400708002013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'blue caraveo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002092, variant_id, 99, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002064, 400708002, 400708002001, menu_item_id, 400708002013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SPECIAL COMBO OFFER" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002065, 400708002, cd.canonical_dish_id, 'Combo 1 - Veg Combo (Veg Burger + 4 Pcs Veg Momos + Soft Drink (Sprite))', 'combo 1 - veg combo (veg burger 4 pcs veg momos soft drink (sprite))', 'SPECIAL COMBO OFFER', 400708002014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'combo 1 - veg combo (veg burger 4 pcs veg momos soft drink (sprite))'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002093, variant_id, 129, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002065, 400708002, 400708002001, menu_item_id, 400708002014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SPECIAL COMBO OFFER" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400708002066, 400708002, cd.canonical_dish_id, 'Combo 2 - Chicken Combo (Chicken Burger + 4 Pcs Chicken Momos + Soft Drink (Sprite))', 'combo 2 - chicken combo (chicken burger 4 pcs chicken momos soft drink (sprite))', 'SPECIAL COMBO OFFER', 400708002014, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'combo 2 - chicken combo (chicken burger 4 pcs chicken momos soft drink (sprite))'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400708002094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400708002094, variant_id, 159, (clock_timestamp() AT TIME ZONE 'UTC'), 400708002, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400708002066, 400708002, 400708002001, menu_item_id, 400708002014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400708002, 400708002500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400708002, 400708002500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

COMMIT;

-- UNMAPPED: no address/phone in the JSON (both blank); brand/website/email
-- also blank; Instagram handle 'momokitchenairoli' has no schema column.
-- Summary: 1 restaurant, 14 categories, 66 menu items, 52 canonical dishes.