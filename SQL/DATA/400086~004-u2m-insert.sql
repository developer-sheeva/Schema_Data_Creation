/* ============================================================================
   KHAUSTAN -- RESTAURANT ONBOARDING (JSON source): UDUPI TO MUMBAI
   Source: U2M_Restaurant_Menu_OCR.json
   Target: KhaustanRestaurantMenu database.
   ESTABLISHMENT_ID = 400086004 (given directly in the JSON's own restaurant block).

   Pure veg ("veg_non_veg": "Pure Veg" stated directly) -- every item is
   food_classification_code = 'veg', protein_type_id NULL throughout.

   No \connect meta-command (psql-only, confirmed to break pgAdmin4's Query
   Tool earlier this session); connect the Query Tool directly instead.
   ============================================================================ */

BEGIN;

DO $do$
DECLARE v_max BIGINT:=400086004000;
BEGIN
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS u2m_other_id_seq START WITH %s', v_max + 1);
END $do$;

DO $do$
DECLARE v_already_done BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400086004
    AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'U2M_Restaurant_Menu_OCR.json')
    AND status_code = 'completed') INTO v_already_done;
  IF v_already_done THEN RAISE EXCEPTION 'Already loaded for restaurant 400086004.'; END IF;
END $do$;

INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, city, state, country_code, postal_code, latitude, longitude)
VALUES (400086004, 'UDUPI TO MUMBAI', 'udupi to mumbai', 'Shop No. 6, Neelkanth Corporate Park, Premier Road, Vidyavihar (W), Mumbai - 86.', 'Vidyavihar (West)', 'Mumbai', 'Maharashtra', 'IN', '400086', 19.082420231045198, 72.8958033536002);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, veg_nonveg_status, has_bar, bar_license_type)
VALUES (400086004, 400086004, 'UDUPI TO MUMBAI', 'udupi to mumbai', 'pure_veg', FALSE, 'none');

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400086004, 'ai_menu_extraction', 'U2M_Restaurant_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
VALUES (400086004500, 400086004, 400086004, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary, is_personal_number) VALUES
  (nextval('u2m_other_id_seq'), 400086004, '74 2929 9393', TRUE, FALSE),
  (nextval('u2m_other_id_seq'), 400086004, '74 2929 9494', FALSE, FALSE),
  (nextval('u2m_other_id_seq'), 400086004, '74 2929 9595', FALSE, FALSE);

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, currency_code)
VALUES (400086004, TRUE, TRUE, 'INR');

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, notes)
VALUES (400086004, 1, 'Dine-in inferred: sit-down multicuisine menu structure'), (400086004, 3, NULL), (400086004, 4, 'Free home delivery stated; no named aggregator partner in the JSON');

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code) VALUES (400086004001, 400086004, 'UDUPI TO MUMBAI Menu', 'a_la_carte');

INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence) VALUES
  (400086004001, 400086004, 'South Indian Snacks', 1),
  (400086004002, 400086004, 'Dosa & More', 2),
  (400086004003, 400086004, 'Upvas', 3),
  (400086004004, 400086004, 'Pav Bhaji', 4),
  (400086004005, 400086004, 'Chaat', 5),
  (400086004006, 400086004, 'Bread Rolls', 6),
  (400086004007, 400086004, 'Sandwichs', 7),
  (400086004008, 400086004, 'Grill Sandwiches', 8),
  (400086004009, 400086004, 'Indian Pizza (6 Inch)', 9),
  (400086004010, 400086004, 'Continental Pizza (10 Inch)', 10),
  (400086004011, 400086004, 'Pasta', 11),
  (400086004012, 400086004, 'Continental & Mexican Rice', 12),
  (400086004013, 400086004, 'Continental Soup', 13),
  (400086004014, 400086004, 'Chinese Soup', 14),
  (400086004015, 400086004, 'Chef Special Soup', 15),
  (400086004016, 400086004, 'Continental Starters', 16),
  (400086004017, 400086004, 'Chef Spl Continental Starters', 17),
  (400086004018, 400086004, 'Indian Tandoor', 18),
  (400086004019, 400086004, 'Chef Spl Indian Tandoor', 19),
  (400086004020, 400086004, 'Chinese Starters', 20),
  (400086004021, 400086004, 'Chef Spl Chinese Starters', 21),
  (400086004022, 400086004, 'Main Course', 22),
  (400086004023, 400086004, 'Chef Spl Indian Main Course', 23),
  (400086004024, 400086004, 'Indian Breads', 24),
  (400086004025, 400086004, 'Dal', 25),
  (400086004026, 400086004, 'Rice', 26),
  (400086004027, 400086004, 'Salad, Raita & Papad', 27),
  (400086004028, 400086004, 'Chinese Main Course', 28),
  (400086004029, 400086004, 'Chef Spl Chinese Main Course', 29),
  (400086004030, 400086004, 'Rice & Noodles', 30),
  (400086004031, 400086004, 'Juices', 31),
  (400086004032, 400086004, 'Blossoms', 32),
  (400086004033, 400086004, 'Mocktails', 33),
  (400086004034, 400086004, 'Milk Shakes', 34),
  (400086004035, 400086004, 'Dry Fruits Milk Shakes', 35),
  (400086004036, 400086004, 'Cold Beverages', 36),
  (400086004037, 400086004, 'Falooda', 37),
  (400086004038, 400086004, 'Desserts', 38);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
  (400086004, 400086004001, 400086004001, 1),
  (400086004, 400086004001, 400086004002, 2),
  (400086004, 400086004001, 400086004003, 3),
  (400086004, 400086004001, 400086004004, 4),
  (400086004, 400086004001, 400086004005, 5),
  (400086004, 400086004001, 400086004006, 6),
  (400086004, 400086004001, 400086004007, 7),
  (400086004, 400086004001, 400086004008, 8),
  (400086004, 400086004001, 400086004009, 9),
  (400086004, 400086004001, 400086004010, 10),
  (400086004, 400086004001, 400086004011, 11),
  (400086004, 400086004001, 400086004012, 12),
  (400086004, 400086004001, 400086004013, 13),
  (400086004, 400086004001, 400086004014, 14),
  (400086004, 400086004001, 400086004015, 15),
  (400086004, 400086004001, 400086004016, 16),
  (400086004, 400086004001, 400086004017, 17),
  (400086004, 400086004001, 400086004018, 18),
  (400086004, 400086004001, 400086004019, 19),
  (400086004, 400086004001, 400086004020, 20),
  (400086004, 400086004001, 400086004021, 21),
  (400086004, 400086004001, 400086004022, 22),
  (400086004, 400086004001, 400086004023, 23),
  (400086004, 400086004001, 400086004024, 24),
  (400086004, 400086004001, 400086004025, 25),
  (400086004, 400086004001, 400086004026, 26),
  (400086004, 400086004001, 400086004027, 27),
  (400086004, 400086004001, 400086004028, 28),
  (400086004, 400086004001, 400086004029, 29),
  (400086004, 400086004001, 400086004030, 30),
  (400086004, 400086004001, 400086004031, 31),
  (400086004, 400086004001, 400086004032, 32),
  (400086004, 400086004001, 400086004033, 33),
  (400086004, 400086004001, 400086004034, 34),
  (400086004, 400086004001, 400086004035, 35),
  (400086004, 400086004001, 400086004036, 36),
  (400086004, 400086004001, 400086004037, 37),
  (400086004, 400086004001, 400086004038, 38);

WITH nd_47694351 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Steam Idli', 'steam idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Steam Idli', 'steam idli', 'primary' FROM nd_47694351;

WITH nd_10541584 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Udupi Idli', 'udupi idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'udupi idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Udupi Idli', 'udupi idli', 'primary' FROM nd_10541584;

WITH nd_45550628 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'That Idli', 'that idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'that idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'That Idli', 'that idli', 'primary' FROM nd_45550628;

WITH nd_85309207 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Idli', 'butter idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Idli', 'butter idli', 'primary' FROM nd_85309207;

WITH nd_56470283 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tawa Masala Idli', 'tawa masala idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tawa masala idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tawa Masala Idli', 'tawa masala idli', 'primary' FROM nd_56470283;

WITH nd_20394242 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dahi Idli', 'dahi idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dahi Idli', 'dahi idli', 'primary' FROM nd_20394242;

WITH nd_41024243 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fry Idli', 'fry idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fry idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fry Idli', 'fry idli', 'primary' FROM nd_41024243;

WITH nd_73421963 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Medu Wada', 'medu wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'medu wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Medu Wada', 'medu wada', 'primary' FROM nd_73421963;

WITH nd_37418147 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Idli Wada', 'idli wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Idli Wada', 'idli wada', 'primary' FROM nd_37418147;

WITH nd_81907142 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Rasam Wada', 'rasam wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rasam wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Rasam Wada', 'rasam wada', 'primary' FROM nd_81907142;

WITH nd_96754869 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dahi Wada', 'dahi wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dahi Wada', 'dahi wada', 'primary' FROM nd_96754869;

WITH nd_70371843 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sada Dosa', 'sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sada Dosa', 'sada dosa', 'primary' FROM nd_70371843;

WITH nd_23863613 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Sada Dosa', 'cheese sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Sada Dosa', 'cheese sada dosa', 'primary' FROM nd_23863613;

WITH nd_47136937 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ghee Roast Sada Dosa', 'ghee roast sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee roast sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ghee Roast Sada Dosa', 'ghee roast sada dosa', 'primary' FROM nd_47136937;

WITH nd_79965284 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mysore Sada Dosa', 'mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mysore Sada Dosa', 'mysore sada dosa', 'primary' FROM nd_79965284;

WITH nd_28379018 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Rawa Sada Dosa', 'rawa sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawa sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Rawa Sada Dosa', 'rawa sada dosa', 'primary' FROM nd_28379018;

WITH nd_13655885 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ghee Rawa Sada Dosa', 'ghee rawa sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee rawa sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ghee Rawa Sada Dosa', 'ghee rawa sada dosa', 'primary' FROM nd_13655885;

WITH nd_1084730 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Onion Rawa Sada Dosa', 'onion rawa sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rawa sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Onion Rawa Sada Dosa', 'onion rawa sada dosa', 'primary' FROM nd_1084730;

WITH nd_20043370 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Sada Dosa', 'butter sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Sada Dosa', 'butter sada dosa', 'primary' FROM nd_20043370;

WITH nd_73654278 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Dosa', 'masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Dosa', 'masala dosa', 'primary' FROM nd_73654278;

WITH nd_36130170 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ghee Roast Masala Dosa', 'ghee roast masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee roast masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ghee Roast Masala Dosa', 'ghee roast masala dosa', 'primary' FROM nd_36130170;

WITH nd_70535978 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mysore Masala Dosa', 'mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mysore Masala Dosa', 'mysore masala dosa', 'primary' FROM nd_70535978;

WITH nd_86153261 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Rawa Masala Dosa', 'rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Rawa Masala Dosa', 'rawa masala dosa', 'primary' FROM nd_86153261;

WITH nd_58034067 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ghee Rawa Masala Dosa', 'ghee rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ghee Rawa Masala Dosa', 'ghee rawa masala dosa', 'primary' FROM nd_58034067;

WITH nd_55136840 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Onion Rawa Masala Dosa', 'onion rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Onion Rawa Masala Dosa', 'onion rawa masala dosa', 'primary' FROM nd_55136840;

WITH nd_16130279 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ragi Dosa', 'ragi dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ragi dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ragi Dosa', 'ragi dosa', 'primary' FROM nd_16130279;

WITH nd_8550948 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ragi Masala Dosa', 'ragi masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ragi masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ragi Masala Dosa', 'ragi masala dosa', 'primary' FROM nd_8550948;

WITH nd_42020982 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Moong Dosa', 'moong dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'moong dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Moong Dosa', 'moong dosa', 'primary' FROM nd_42020982;

WITH nd_37668206 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Malgudi Dosa', 'malgudi dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malgudi dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Malgudi Dosa', 'malgudi dosa', 'primary' FROM nd_37668206;

WITH nd_55811399 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Set Dosa', 'set dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'set dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Set Dosa', 'set dosa', 'primary' FROM nd_55811399;

WITH nd_81135816 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Crispy Schezwan Dosa', 'crispy schezwan dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy schezwan dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Crispy Schezwan Dosa', 'crispy schezwan dosa', 'primary' FROM nd_81135816;

WITH nd_37409850 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Spl Mysore Masala (Soft)', 'spl mysore masala (soft)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl mysore masala (soft)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Spl Mysore Masala (Soft)', 'spl mysore masala (soft)', 'primary' FROM nd_37409850;

WITH nd_99909956 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Udupi Benne Dosa', 'udupi benne dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'udupi benne dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Udupi Benne Dosa', 'udupi benne dosa', 'primary' FROM nd_99909956;

WITH nd_24221823 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Plain Uttapam', 'plain uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Plain Uttapam', 'plain uttapam', 'primary' FROM nd_24221823;

WITH nd_78032383 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Onion Uttappam', 'onion uttappam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion uttappam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Onion Uttappam', 'onion uttappam', 'primary' FROM nd_78032383;

WITH nd_30132905 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tomato Uttappam', 'tomato uttappam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato uttappam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tomato Uttappam', 'tomato uttappam', 'primary' FROM nd_30132905;

WITH nd_2639459 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Uttappam', 'masala uttappam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala uttappam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Uttappam', 'masala uttappam', 'primary' FROM nd_2639459;

WITH nd_57357945 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mix Uttappam (Onion, Tomato, Masala)', 'mix uttappam (onion tomato masala)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix uttappam (onion tomato masala)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mix Uttappam (Onion, Tomato, Masala)', 'mix uttappam (onion tomato masala)', 'primary' FROM nd_57357945;

WITH nd_81362765 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tomato Omlet', 'tomato omlet'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato omlet')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tomato Omlet', 'tomato omlet', 'primary' FROM nd_81362765;

WITH nd_35907686 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Spring Dosa', 'spring dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spring dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Spring Dosa', 'spring dosa', 'primary' FROM nd_35907686;

WITH nd_92270256 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'All Dosa With Butter', 'all dosa with butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'all dosa with butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'All Dosa With Butter', 'all dosa with butter', 'primary' FROM nd_92270256;

WITH nd_91788461 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'All Dosa With Cheese', 'all dosa with cheese'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'all dosa with cheese')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'All Dosa With Cheese', 'all dosa with cheese', 'primary' FROM nd_91788461;

WITH nd_50824726 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sabudana Wada', 'sabudana wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabudana wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sabudana Wada', 'sabudana wada', 'primary' FROM nd_50824726;

WITH nd_24192875 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sabudana Khichdi', 'sabudana khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabudana khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sabudana Khichdi', 'sabudana khichdi', 'primary' FROM nd_24192875;

WITH nd_58805274 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Pav Bhaji', 'pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Pav Bhaji', 'pav bhaji', 'primary' FROM nd_58805274;

WITH nd_42381319 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Jain Pav Bhaji', 'jain pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Jain Pav Bhaji', 'jain pav bhaji', 'primary' FROM nd_42381319;

WITH nd_45962309 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Khada Pav Bhaji', 'khada pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'khada pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Khada Pav Bhaji', 'khada pav bhaji', 'primary' FROM nd_45962309;

WITH nd_10311022 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Pav Bhaji', 'masala pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Pav Bhaji', 'masala pav bhaji', 'primary' FROM nd_10311022;

WITH nd_47233256 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Pav Bhaji', 'cheese pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Pav Bhaji', 'cheese pav bhaji', 'primary' FROM nd_47233256;

WITH nd_35518830 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'U2M Special Pav Bhaji', 'u2m special pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'u2m special pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'U2M Special Pav Bhaji', 'u2m special pav bhaji', 'primary' FROM nd_35518830;

WITH nd_27666375 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chutney Masala Pav (2 Pcs)', 'chutney masala pav (2 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chutney masala pav (2 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chutney Masala Pav (2 Pcs)', 'chutney masala pav (2 pcs)', 'primary' FROM nd_27666375;

WITH nd_64676387 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Spl Pav Sandwich', 'spl pav sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl pav sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Spl Pav Sandwich', 'spl pav sandwich', 'primary' FROM nd_64676387;

WITH nd_10280844 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Pav Sandwich', 'cheese pav sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pav sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Pav Sandwich', 'cheese pav sandwich', 'primary' FROM nd_10280844;

WITH nd_10086592 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Pav (2 Pcs)', 'masala pav (2 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala pav (2 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Pav (2 Pcs)', 'masala pav (2 pcs)', 'primary' FROM nd_10086592;

WITH nd_56273689 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tawa Pulao', 'tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tawa Pulao', 'tawa pulao', 'primary' FROM nd_56273689;

WITH nd_80554006 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Tawa Pulao', 'cheese tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Tawa Pulao', 'cheese tawa pulao', 'primary' FROM nd_80554006;

WITH nd_54228425 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sada Pav', 'sada pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sada Pav', 'sada pav', 'primary' FROM nd_54228425;

WITH nd_41546698 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kadak Sada Pav', 'kadak sada pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kadak sada pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kadak Sada Pav', 'kadak sada pav', 'primary' FROM nd_41546698;

WITH nd_98753874 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Extra Butter Pav (Single)', 'extra butter pav (single)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra butter pav (single)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Extra Butter Pav (Single)', 'extra butter pav (single)', 'primary' FROM nd_98753874;

WITH nd_27477678 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Kadak Sada Pav (Single)', 'butter kadak sada pav (single)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter kadak sada pav (single)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Kadak Sada Pav (Single)', 'butter kadak sada pav (single)', 'primary' FROM nd_27477678;

WITH nd_19067517 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Pani Puri', 'pani puri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pani puri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Pani Puri', 'pani puri', 'primary' FROM nd_19067517;

WITH nd_50019541 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Puneri Bhel', 'puneri bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puneri bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Puneri Bhel', 'puneri bhel', 'primary' FROM nd_50019541;

WITH nd_22947488 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kolhapuri Bhel', 'kolhapuri bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kolhapuri bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kolhapuri Bhel', 'kolhapuri bhel', 'primary' FROM nd_22947488;

WITH nd_57543740 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sev Puri', 'sev puri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sev puri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sev Puri', 'sev puri', 'primary' FROM nd_57543740;

WITH nd_17535446 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dahi Batata Puri', 'dahi batata puri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi batata puri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dahi Batata Puri', 'dahi batata puri', 'primary' FROM nd_17535446;

WITH nd_39581762 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ragda Pattice', 'ragda pattice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ragda pattice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ragda Pattice', 'ragda pattice', 'primary' FROM nd_39581762;

WITH nd_34054606 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Samosa Chaat', 'samosa chaat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'samosa chaat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Samosa Chaat', 'samosa chaat', 'primary' FROM nd_34054606;

WITH nd_89931688 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Rajkachori Chaat', 'rajkachori chaat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rajkachori chaat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Rajkachori Chaat', 'rajkachori chaat', 'primary' FROM nd_89931688;

WITH nd_68097152 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Burger', 'vegetable burger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable burger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Burger', 'vegetable burger', 'primary' FROM nd_68097152;

WITH nd_57976834 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Burger', 'cheese burger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese burger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Burger', 'cheese burger', 'primary' FROM nd_57976834;

WITH nd_78807337 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Hot Dog', 'vegetable hot dog'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable hot dog')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Hot Dog', 'vegetable hot dog', 'primary' FROM nd_78807337;

WITH nd_2743601 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Hot Dog', 'cheese hot dog'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese hot dog')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Hot Dog', 'cheese hot dog', 'primary' FROM nd_2743601;

WITH nd_20651285 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Chilly Toast', 'cheese chilly toast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly toast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chilly Toast', 'cheese chilly toast', 'primary' FROM nd_20651285;

WITH nd_56659512 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Garlic Roll', 'garlic roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Garlic Roll', 'garlic roll', 'primary' FROM nd_56659512;

WITH nd_37199521 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Garlic Cheese Roll', 'garlic cheese roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic cheese roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Garlic Cheese Roll', 'garlic cheese roll', 'primary' FROM nd_37199521;

WITH nd_73099228 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Roll', 'cheese roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Roll', 'cheese roll', 'primary' FROM nd_73099228;

WITH nd_36241582 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Family Garlic Cheese Roll', 'family garlic cheese roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'family garlic cheese roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Family Garlic Cheese Roll', 'family garlic cheese roll', 'primary' FROM nd_36241582;

WITH nd_29206670 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Sandwich', 'vegetable sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Sandwich', 'vegetable sandwich', 'primary' FROM nd_29206670;

WITH nd_80365159 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Cheese Sandwich', 'vegetable cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Cheese Sandwich', 'vegetable cheese sandwich', 'primary' FROM nd_80365159;

WITH nd_44332819 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Only Cheese Sandwich', 'only cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Only Cheese Sandwich', 'only cheese sandwich', 'primary' FROM nd_44332819;

WITH nd_75002717 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Toast Sandwich', 'vegetable toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Toast Sandwich', 'vegetable toast sandwich', 'primary' FROM nd_75002717;

WITH nd_72795330 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Toast Sandwich', 'cheese toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Toast Sandwich', 'cheese toast sandwich', 'primary' FROM nd_72795330;

WITH nd_35740534 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Toast Sandwich', 'masala toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Toast Sandwich', 'masala toast sandwich', 'primary' FROM nd_35740534;

WITH nd_96748872 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Masala Toast Sandwich', 'cheese masala toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Masala Toast Sandwich', 'cheese masala toast sandwich', 'primary' FROM nd_96748872;

WITH nd_94672313 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Club Sandwich', 'club sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'club sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Club Sandwich', 'club sandwich', 'primary' FROM nd_94672313;

WITH nd_38262401 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Bread Butter', 'bread butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bread butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Bread Butter', 'bread butter', 'primary' FROM nd_38262401;

WITH nd_71189542 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Toast Butter', 'toast butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'toast butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Toast Butter', 'toast butter', 'primary' FROM nd_71189542;

WITH nd_92707246 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Jam Bread Butter', 'jam bread butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jam bread butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Jam Bread Butter', 'jam bread butter', 'primary' FROM nd_92707246;

WITH nd_94372837 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chutney Sandwich', 'chutney sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chutney sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chutney Sandwich', 'chutney sandwich', 'primary' FROM nd_94372837;

WITH nd_76196965 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Grill Sandwich', 'vegetable grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Grill Sandwich', 'vegetable grill sandwich', 'primary' FROM nd_76196965;

WITH nd_75101753 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Cheese Grill Sandwich', 'vegetable cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Cheese Grill Sandwich', 'vegetable cheese grill sandwich', 'primary' FROM nd_75101753;

WITH nd_1556085 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Only Cheese Grill Sandwich', 'only cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Only Cheese Grill Sandwich', 'only cheese grill sandwich', 'primary' FROM nd_1556085;

WITH nd_34532887 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Grill Sandwich', 'masala grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Grill Sandwich', 'masala grill sandwich', 'primary' FROM nd_34532887;

WITH nd_31216064 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Garlic Cheese Grill Sandwich', 'garlic cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Garlic Cheese Grill Sandwich', 'garlic cheese grill sandwich', 'primary' FROM nd_31216064;

WITH nd_73828016 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Corn Capsicum Grill Sandwich', 'corn capsicum grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'corn capsicum grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Corn Capsicum Grill Sandwich', 'corn capsicum grill sandwich', 'primary' FROM nd_73828016;

WITH nd_1121865 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Cheese Grill Sandwich', 'mushroom cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Cheese Grill Sandwich', 'mushroom cheese grill sandwich', 'primary' FROM nd_1121865;

WITH nd_33644016 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Cheese Grill Sandwich', 'masala cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Cheese Grill Sandwich', 'masala cheese grill sandwich', 'primary' FROM nd_33644016;

WITH nd_24326022 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Cheese Pizza', 'vegetable cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Cheese Pizza', 'vegetable cheese pizza', 'primary' FROM nd_24326022;

WITH nd_11255869 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Only Cheese Pizza', 'only cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Only Cheese Pizza', 'only cheese pizza', 'primary' FROM nd_11255869;

WITH nd_60849813 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Crispy Schezwan Pizza', 'crispy schezwan pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy schezwan pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Crispy Schezwan Pizza', 'crispy schezwan pizza', 'primary' FROM nd_60849813;

WITH nd_33317953 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Corn Cheese Pizza', 'corn cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'corn cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Corn Cheese Pizza', 'corn cheese pizza', 'primary' FROM nd_33317953;

WITH nd_14553637 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Pizza', 'mushroom pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Pizza', 'mushroom pizza', 'primary' FROM nd_14553637;

WITH nd_31551360 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Margherita', 'margherita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'margherita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Margherita', 'margherita', 'primary' FROM nd_31551360;

WITH nd_35273262 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Tikka Pizza', 'paneer tikka pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Pizza', 'paneer tikka pizza', 'primary' FROM nd_35273262;

WITH nd_34665101 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Perika Pizza', 'paneer perika pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer perika pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Perika Pizza', 'paneer perika pizza', 'primary' FROM nd_34665101;

WITH nd_33184836 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Americano', 'americano'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'americano')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Americano', 'americano', 'primary' FROM nd_33184836;

WITH nd_81811371 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fresh Farmhouse Pizza', 'fresh farmhouse pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh farmhouse pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fresh Farmhouse Pizza', 'fresh farmhouse pizza', 'primary' FROM nd_81811371;

WITH nd_42833864 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Arrabiata Pasta', 'arrabiata pasta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arrabiata pasta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Arrabiata Pasta', 'arrabiata pasta', 'primary' FROM nd_42833864;

WITH nd_69708927 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Alfredo Pasta', 'alfredo pasta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alfredo pasta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Alfredo Pasta', 'alfredo pasta', 'primary' FROM nd_69708927;

WITH nd_73278863 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Green Pesto Pasta', 'green pesto pasta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green pesto pasta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Green Pesto Pasta', 'green pesto pasta', 'primary' FROM nd_73278863;

WITH nd_98052603 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Handmade Ravoli Pasta', 'handmade ravoli pasta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'handmade ravoli pasta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Handmade Ravoli Pasta', 'handmade ravoli pasta', 'primary' FROM nd_98052603;

WITH nd_25776725 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Spaghetti Aglio E Olio', 'spaghetti aglio e olio'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spaghetti aglio e olio')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Spaghetti Aglio E Olio', 'spaghetti aglio e olio', 'primary' FROM nd_25776725;

WITH nd_94319202 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Lasagna', 'lasagna'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lasagna')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Lasagna', 'lasagna', 'primary' FROM nd_94319202;

WITH nd_8566798 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mexican Tit Bit Rice', 'mexican tit bit rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mexican tit bit rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mexican Tit Bit Rice', 'mexican tit bit rice', 'primary' FROM nd_8566798;

WITH nd_73107227 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Risotto', 'risotto'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'risotto')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Risotto', 'risotto', 'primary' FROM nd_73107227;

WITH nd_51903546 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cream Of Broccoli Soup', 'cream of broccoli soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream of broccoli soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cream Of Broccoli Soup', 'cream of broccoli soup', 'primary' FROM nd_51903546;

WITH nd_11704032 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cream Of Tomato Soup', 'cream of tomato soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream of tomato soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cream Of Tomato Soup', 'cream of tomato soup', 'primary' FROM nd_11704032;

WITH nd_38469736 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cream Of Mushroom', 'cream of mushroom'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream of mushroom')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cream Of Mushroom', 'cream of mushroom', 'primary' FROM nd_38469736;

WITH nd_17649463 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tomato Basil Soup', 'tomato basil soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato basil soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tomato Basil Soup', 'tomato basil soup', 'primary' FROM nd_17649463;

WITH nd_49036520 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Manchow Soup', 'manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Manchow Soup', 'manchow soup', 'primary' FROM nd_49036520;

WITH nd_89615167 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Hot & Sour Soup', 'hot & sour soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot & sour soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Hot & Sour Soup', 'hot & sour soup', 'primary' FROM nd_89615167;

WITH nd_38813542 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sweet Corn Soup', 'sweet corn soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet corn soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sweet Corn Soup', 'sweet corn soup', 'primary' FROM nd_38813542;

WITH nd_61655521 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Clear Soup', 'vegetable clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Clear Soup', 'vegetable clear soup', 'primary' FROM nd_61655521;

WITH nd_53170576 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Lemon Coriander Soup', 'lemon coriander soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon coriander soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Lemon Coriander Soup', 'lemon coriander soup', 'primary' FROM nd_53170576;

WITH nd_76109741 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Soup', 'mushroom soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Soup', 'mushroom soup', 'primary' FROM nd_76109741;

WITH nd_19926877 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Burnt Garlic Soup', 'vegetable burnt garlic soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable burnt garlic soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Burnt Garlic Soup', 'vegetable burnt garlic soup', 'primary' FROM nd_19926877;

WITH nd_83083746 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Hot Garlic Noodle Soup', 'hot garlic noodle soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot garlic noodle soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Hot Garlic Noodle Soup', 'hot garlic noodle soup', 'primary' FROM nd_83083746;

WITH nd_62078823 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Thai Vegetable Soup (Red/Green)', 'thai vegetable soup (red/green)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai vegetable soup (red/green)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Thai Vegetable Soup (Red/Green)', 'thai vegetable soup (red/green)', 'primary' FROM nd_62078823;

WITH nd_50469133 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheesling Rice Soup', 'cheesling rice soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheesling rice soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheesling Rice Soup', 'cheesling rice soup', 'primary' FROM nd_50469133;

WITH nd_72424127 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Corn Balls', 'cheese corn balls'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese corn balls')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Corn Balls', 'cheese corn balls', 'primary' FROM nd_72424127;

WITH nd_53962260 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Garlic Bread', 'garlic bread'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic bread')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Garlic Bread', 'garlic bread', 'primary' FROM nd_53962260;

WITH nd_90189377 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Garlic Bread', 'cheese garlic bread'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese garlic bread')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Garlic Bread', 'cheese garlic bread', 'primary' FROM nd_90189377;

WITH nd_84797460 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Nachos With Cheese & Salsa Dip', 'nachos with cheese & salsa dip'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nachos with cheese & salsa dip')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Nachos With Cheese & Salsa Dip', 'nachos with cheese & salsa dip', 'primary' FROM nd_84797460;

WITH nd_38656106 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Stir Fried Exotic Vegetables', 'stir fried exotic vegetables'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'stir fried exotic vegetables')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Stir Fried Exotic Vegetables', 'stir fried exotic vegetables', 'primary' FROM nd_38656106;

WITH nd_79490074 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Bruschetta', 'bruschetta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bruschetta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Bruschetta', 'bruschetta', 'primary' FROM nd_79490074;

WITH nd_59134938 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'French Fries', 'french fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'french fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'French Fries', 'french fries', 'primary' FROM nd_59134938;

WITH nd_58009691 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Peri Peri French Fries', 'peri peri french fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peri peri french fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Peri Peri French Fries', 'peri peri french fries', 'primary' FROM nd_58009691;

WITH nd_51060415 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Grill Chipotle Paneer', 'grill chipotle paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'grill chipotle paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Grill Chipotle Paneer', 'grill chipotle paneer', 'primary' FROM nd_51060415;

WITH nd_13691150 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Malaysian Paneer', 'malaysian paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malaysian paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Malaysian Paneer', 'malaysian paneer', 'primary' FROM nd_13691150;

WITH nd_85391474 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Volcano Balls', 'cheese volcano balls'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese volcano balls')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Volcano Balls', 'cheese volcano balls', 'primary' FROM nd_85391474;

WITH nd_22617727 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Hara Bara Kebab', 'hara bara kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hara bara kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Hara Bara Kebab', 'hara bara kebab', 'primary' FROM nd_22617727;

WITH nd_34031865 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Seekh Kebab', 'vegetable seekh kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable seekh kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Seekh Kebab', 'vegetable seekh kebab', 'primary' FROM nd_34031865;

WITH nd_2995597 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Chilly Kebab', 'cheese chilly kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chilly Kebab', 'cheese chilly kebab', 'primary' FROM nd_2995597;

WITH nd_56168929 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Aloo Angare', 'aloo angare'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo angare')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Aloo Angare', 'aloo angare', 'primary' FROM nd_56168929;

WITH nd_44617388 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Tikka', 'paneer tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka', 'paneer tikka', 'primary' FROM nd_44617388;

WITH nd_42698873 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Pahadi Tikka', 'paneer pahadi tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pahadi tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Pahadi Tikka', 'paneer pahadi tikka', 'primary' FROM nd_42698873;

WITH nd_65066371 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Kalimiri Tikka', 'paneer kalimiri tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kalimiri tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Kalimiri Tikka', 'paneer kalimiri tikka', 'primary' FROM nd_65066371;

WITH nd_91605139 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Malai Tikka', 'paneer malai tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer malai tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Malai Tikka', 'paneer malai tikka', 'primary' FROM nd_91605139;

WITH nd_63108651 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Pudina Tikka', 'paneer pudina tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pudina tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Pudina Tikka', 'paneer pudina tikka', 'primary' FROM nd_63108651;

WITH nd_84646907 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Lasooni Tikka', 'paneer lasooni tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lasooni tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Lasooni Tikka', 'paneer lasooni tikka', 'primary' FROM nd_84646907;

WITH nd_4084562 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Achari Tikka', 'paneer achari tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer achari tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Achari Tikka', 'paneer achari tikka', 'primary' FROM nd_4084562;

WITH nd_70572890 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tandoori Malai Broccoli', 'tandoori malai broccoli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori malai broccoli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Malai Broccoli', 'tandoori malai broccoli', 'primary' FROM nd_70572890;

WITH nd_7839207 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Achari Tikka', 'mushroom achari tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom achari tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Achari Tikka', 'mushroom achari tikka', 'primary' FROM nd_7839207;

WITH nd_54070851 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Makhmali Roll', 'paneer makhmali roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhmali roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Makhmali Roll', 'paneer makhmali roll', 'primary' FROM nd_54070851;

WITH nd_76002646 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Ghee Roast Tikka', 'paneer ghee roast tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer ghee roast tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Ghee Roast Tikka', 'paneer ghee roast tikka', 'primary' FROM nd_76002646;

WITH nd_997317 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Hadippa Tikka', 'paneer hadippa tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hadippa tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Hadippa Tikka', 'paneer hadippa tikka', 'primary' FROM nd_997317;

WITH nd_46243523 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Bharwan Aloo', 'bharwan aloo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bharwan aloo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Bharwan Aloo', 'bharwan aloo', 'primary' FROM nd_46243523;

WITH nd_20411158 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kasthuri Paneer Tikka', 'kasthuri paneer tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kasthuri paneer tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kasthuri Paneer Tikka', 'kasthuri paneer tikka', 'primary' FROM nd_20411158;

WITH nd_28362822 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Peri-Peri Tikka', 'paneer peri-peri tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer peri-peri tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Peri-Peri Tikka', 'paneer peri-peri tikka', 'primary' FROM nd_28362822;

WITH nd_60516836 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Soya Chaap Tikka', 'soya chaap tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soya chaap tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Soya Chaap Tikka', 'soya chaap tikka', 'primary' FROM nd_60516836;

WITH nd_11419049 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Khaas Seekh Kebab', 'khaas seekh kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'khaas seekh kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Khaas Seekh Kebab', 'khaas seekh kebab', 'primary' FROM nd_11419049;

WITH nd_45353244 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Angara Tikka', 'paneer angara tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer angara tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Angara Tikka', 'paneer angara tikka', 'primary' FROM nd_45353244;

WITH nd_11561795 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Basil Garlic Paneer Tikka', 'basil garlic paneer tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'basil garlic paneer tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Basil Garlic Paneer Tikka', 'basil garlic paneer tikka', 'primary' FROM nd_11561795;

WITH nd_73129936 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Hilltop Tikka', 'paneer hilltop tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hilltop tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Hilltop Tikka', 'paneer hilltop tikka', 'primary' FROM nd_73129936;

WITH nd_73959253 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Manchurian Dry', 'vegetable manchurian dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable manchurian dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Manchurian Dry', 'vegetable manchurian dry', 'primary' FROM nd_73959253;

WITH nd_94396730 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Schezwan Dry', 'vegetable schezwan dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable schezwan dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Schezwan Dry', 'vegetable schezwan dry', 'primary' FROM nd_94396730;

WITH nd_43243253 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable 65', 'vegetable 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable 65', 'vegetable 65', 'primary' FROM nd_43243253;

WITH nd_52994399 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Balls Hot Garlic Dry', 'vegetable balls hot garlic dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable balls hot garlic dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Balls Hot Garlic Dry', 'vegetable balls hot garlic dry', 'primary' FROM nd_52994399;

WITH nd_60719990 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Crispy Vegetable', 'crispy vegetable'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy vegetable')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Crispy Vegetable', 'crispy vegetable', 'primary' FROM nd_60719990;

WITH nd_92314825 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Spring Roll', 'spring roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spring roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Spring Roll', 'spring roll', 'primary' FROM nd_92314825;

WITH nd_79922285 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Burnt Garlic', 'mushroom burnt garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom burnt garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Burnt Garlic', 'mushroom burnt garlic', 'primary' FROM nd_79922285;

WITH nd_90878799 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Chilly Dry', 'paneer chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Chilly Dry', 'paneer chilly dry', 'primary' FROM nd_90878799;

WITH nd_74765484 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Black Pepper', 'paneer black pepper'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer black pepper')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Black Pepper', 'paneer black pepper', 'primary' FROM nd_74765484;

WITH nd_22202926 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Schezwan Dry', 'paneer schezwan dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Schezwan Dry', 'paneer schezwan dry', 'primary' FROM nd_22202926;

WITH nd_42325683 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer 65', 'paneer 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer 65', 'paneer 65', 'primary' FROM nd_42325683;

WITH nd_6159794 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Crispy Paneer', 'crispy paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'crispy paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Crispy Paneer', 'crispy paneer', 'primary' FROM nd_6159794;

WITH nd_48940391 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kungpao Potato', 'kungpao potato'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kungpao potato')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kungpao Potato', 'kungpao potato', 'primary' FROM nd_48940391;

WITH nd_6747282 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Hot Basil', 'mushroom hot basil'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom hot basil')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Hot Basil', 'mushroom hot basil', 'primary' FROM nd_6747282;

WITH nd_33721012 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Thai Chilly', 'paneer thai chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer thai chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Thai Chilly', 'paneer thai chilly', 'primary' FROM nd_33721012;

WITH nd_568665 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Hot Pan', 'paneer hot pan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hot pan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Hot Pan', 'paneer hot pan', 'primary' FROM nd_568665;

WITH nd_87429436 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Burnt Garlic', 'paneer burnt garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer burnt garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Burnt Garlic', 'paneer burnt garlic', 'primary' FROM nd_87429436;

WITH nd_96407105 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Black Bean', 'paneer black bean'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer black bean')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Black Bean', 'paneer black bean', 'primary' FROM nd_96407105;

WITH nd_31794686 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Hot Basil', 'paneer hot basil'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hot basil')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Hot Basil', 'paneer hot basil', 'primary' FROM nd_31794686;

WITH nd_61588376 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Shanghai', 'paneer shanghai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer shanghai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Shanghai', 'paneer shanghai', 'primary' FROM nd_61588376;

WITH nd_74478761 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chilly Garlic Patrani Dry', 'chilly garlic patrani dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly garlic patrani dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chilly Garlic Patrani Dry', 'chilly garlic patrani dry', 'primary' FROM nd_74478761;

WITH nd_88158439 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Korma', 'vegetable korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Korma', 'vegetable korma', 'primary' FROM nd_88158439;

WITH nd_4072131 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Kadai/ Handi', 'vegetable kadai/ handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable kadai/ handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Kadai/ Handi', 'vegetable kadai/ handi', 'primary' FROM nd_4072131;

WITH nd_53853346 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Makhanwala', 'vegetable makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Makhanwala', 'vegetable makhanwala', 'primary' FROM nd_53853346;

WITH nd_51659535 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tawa Vegetable', 'tawa vegetable'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tawa vegetable')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tawa Vegetable', 'tawa vegetable', 'primary' FROM nd_51659535;

WITH nd_38098780 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Baby Corn Mushroom Masala', 'baby corn mushroom masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baby corn mushroom masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Baby Corn Mushroom Masala', 'baby corn mushroom masala', 'primary' FROM nd_38098780;

WITH nd_87250436 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Maharaja', 'vegetable maharaja'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable maharaja')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Maharaja', 'vegetable maharaja', 'primary' FROM nd_87250436;

WITH nd_4516691 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Chilly Milli', 'vegetable chilly milli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable chilly milli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Chilly Milli', 'vegetable chilly milli', 'primary' FROM nd_4516691;

WITH nd_21090461 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Seekh Kebab Masala', 'vegetable seekh kebab masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable seekh kebab masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Seekh Kebab Masala', 'vegetable seekh kebab masala', 'primary' FROM nd_21090461;

WITH nd_30148318 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Lohori Kofta', 'vegetable lohori kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable lohori kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Lohori Kofta', 'vegetable lohori kofta', 'primary' FROM nd_30148318;

WITH nd_33074510 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Makhmali', 'vegetable makhmali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable makhmali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Makhmali', 'vegetable makhmali', 'primary' FROM nd_33074510;

WITH nd_6949612 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Methi Mutter', 'mushroom methi mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom methi mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Methi Mutter', 'mushroom methi mutter', 'primary' FROM nd_6949612;

WITH nd_36282407 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Kofta', 'vegetable kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Kofta', 'vegetable kofta', 'primary' FROM nd_36282407;

WITH nd_61922388 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chole Bhature', 'chole bhature'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chole bhature')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chole Bhature', 'chole bhature', 'primary' FROM nd_61922388;

WITH nd_60495353 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kadai Paneer', 'kadai paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kadai paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kadai Paneer', 'kadai paneer', 'primary' FROM nd_60495353;

WITH nd_37021640 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Makai', 'paneer makai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Makai', 'paneer makai', 'primary' FROM nd_37021640;

WITH nd_86390005 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Tawa', 'mushroom tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Tawa', 'mushroom tawa', 'primary' FROM nd_86390005;

WITH nd_88175756 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Bhuna Ball Masala', 'vegetable bhuna ball masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable bhuna ball masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Bhuna Ball Masala', 'vegetable bhuna ball masala', 'primary' FROM nd_88175756;

WITH nd_20895160 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kaju Curry / Masala', 'kaju curry / masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju curry / masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kaju Curry / Masala', 'kaju curry / masala', 'primary' FROM nd_20895160;

WITH nd_40866104 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kaju Paneer Masala', 'kaju paneer masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju paneer masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kaju Paneer Masala', 'kaju paneer masala', 'primary' FROM nd_40866104;

WITH nd_85476258 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Methi Chaman', 'paneer methi chaman'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer methi chaman')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Methi Chaman', 'paneer methi chaman', 'primary' FROM nd_85476258;

WITH nd_19822943 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Tikka Masala', 'paneer tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Masala', 'paneer tikka masala', 'primary' FROM nd_19822943;

WITH nd_30530027 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Tawa', 'paneer tawa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tawa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tawa', 'paneer tawa', 'primary' FROM nd_30530027;

WITH nd_84181757 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Palak Paneer', 'palak paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Palak Paneer', 'palak paneer', 'primary' FROM nd_84181757;

WITH nd_72706751 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Lohori', 'paneer lohori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lohori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Lohori', 'paneer lohori', 'primary' FROM nd_72706751;

WITH nd_89185388 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Butter Masala', 'paneer butter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer butter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Butter Masala', 'paneer butter masala', 'primary' FROM nd_89185388;

WITH nd_90765380 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Kolhapuri', 'paneer kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Kolhapuri', 'paneer kolhapuri', 'primary' FROM nd_90765380;

WITH nd_54034078 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Peshawari', 'paneer peshawari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer peshawari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Peshawari', 'paneer peshawari', 'primary' FROM nd_54034078;

WITH nd_68711257 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Malai Methi Mutter', 'malai methi mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai methi mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Malai Methi Mutter', 'malai methi mutter', 'primary' FROM nd_68711257;

WITH nd_78192351 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Navratan Korma', 'navratan korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'navratan korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Navratan Korma', 'navratan korma', 'primary' FROM nd_78192351;

WITH nd_46176371 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Malai Kofta', 'malai kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Malai Kofta', 'malai kofta', 'primary' FROM nd_46176371;

WITH nd_49543840 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Chop Masala', 'vegetable chop masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable chop masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Chop Masala', 'vegetable chop masala', 'primary' FROM nd_49543840;

WITH nd_84063172 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Koliwada Masala', 'vegetable koliwada masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable koliwada masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Koliwada Masala', 'vegetable koliwada masala', 'primary' FROM nd_84063172;

WITH nd_69351091 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Hydrabadi', 'vegetable hydrabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable hydrabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Hydrabadi', 'vegetable hydrabadi', 'primary' FROM nd_69351091;

WITH nd_64546711 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dum Aloo Punjabi', 'dum aloo punjabi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dum aloo punjabi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dum Aloo Punjabi', 'dum aloo punjabi', 'primary' FROM nd_64546711;

WITH nd_71462187 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Bhindi Dahiwali', 'bhindi dahiwali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhindi dahiwali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Bhindi Dahiwali', 'bhindi dahiwali', 'primary' FROM nd_71462187;

WITH nd_30894568 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chole Delhiwale', 'chole delhiwale'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chole delhiwale')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chole Delhiwale', 'chole delhiwale', 'primary' FROM nd_30894568;

WITH nd_17169286 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Cheese Kofta', 'paneer cheese kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer cheese kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Cheese Kofta', 'paneer cheese kofta', 'primary' FROM nd_17169286;

WITH nd_79580572 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Alu Gobi Hariyali', 'alu gobi hariyali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu gobi hariyali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Alu Gobi Hariyali', 'alu gobi hariyali', 'primary' FROM nd_79580572;

WITH nd_84945105 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Diwani Handi', 'vegetable diwani handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable diwani handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Diwani Handi', 'vegetable diwani handi', 'primary' FROM nd_84945105;

WITH nd_20369591 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Malwani Aloo', 'malwani aloo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malwani aloo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Malwani Aloo', 'malwani aloo', 'primary' FROM nd_20369591;

WITH nd_87569201 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Lasooni Paneer', 'lasooni paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lasooni paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Lasooni Paneer', 'lasooni paneer', 'primary' FROM nd_87569201;

WITH nd_85231462 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Lasooni Palak', 'lasooni palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lasooni palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Lasooni Palak', 'lasooni palak', 'primary' FROM nd_85231462;

WITH nd_34983904 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vilayati Sabzi', 'vilayati sabzi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vilayati sabzi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vilayati Sabzi', 'vilayati sabzi', 'primary' FROM nd_34983904;

WITH nd_21057940 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Multani Paneer Tikka Masala', 'multani paneer tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'multani paneer tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Multani Paneer Tikka Masala', 'multani paneer tikka masala', 'primary' FROM nd_21057940;

WITH nd_4332638 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Char Minar', 'paneer char minar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer char minar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Char Minar', 'paneer char minar', 'primary' FROM nd_4332638;

WITH nd_31712395 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Broccoli Kofta Hariyali', 'broccoli kofta hariyali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'broccoli kofta hariyali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Broccoli Kofta Hariyali', 'broccoli kofta hariyali', 'primary' FROM nd_31712395;

WITH nd_66363111 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Kofta Karishma', 'vegetable kofta karishma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable kofta karishma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Kofta Karishma', 'vegetable kofta karishma', 'primary' FROM nd_66363111;

WITH nd_93520134 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Zafrani Paneer Tikka Lazeez', 'zafrani paneer tikka lazeez'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'zafrani paneer tikka lazeez')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Zafrani Paneer Tikka Lazeez', 'zafrani paneer tikka lazeez', 'primary' FROM nd_93520134;

WITH nd_83647379 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Khurchan', 'paneer khurchan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer khurchan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Khurchan', 'paneer khurchan', 'primary' FROM nd_83647379;

WITH nd_72610637 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Dhuladi', 'paneer dhuladi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer dhuladi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Dhuladi', 'paneer dhuladi', 'primary' FROM nd_72610637;

WITH nd_84514349 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Haveli', 'vegetable haveli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable haveli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Haveli', 'vegetable haveli', 'primary' FROM nd_84514349;

WITH nd_49953601 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Chilly Kebab Masala', 'cheese chilly kebab masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly kebab masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Chilly Kebab Masala', 'cheese chilly kebab masala', 'primary' FROM nd_49953601;

WITH nd_83756549 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Lababdar', 'paneer lababdar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lababdar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Lababdar', 'paneer lababdar', 'primary' FROM nd_83756549;

WITH nd_65141961 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Koliwada Masala', 'paneer koliwada masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer koliwada masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Koliwada Masala', 'paneer koliwada masala', 'primary' FROM nd_65141961;

WITH nd_38014310 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Anglo Indian Bahar', 'anglo indian bahar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'anglo indian bahar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Anglo Indian Bahar', 'anglo indian bahar', 'primary' FROM nd_38014310;

WITH nd_2474047 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Lajawab', 'paneer lajawab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lajawab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Lajawab', 'paneer lajawab', 'primary' FROM nd_2474047;

WITH nd_82044037 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Soya Chaap Tikka Masala', 'soya chaap tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soya chaap tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Soya Chaap Tikka Masala', 'soya chaap tikka masala', 'primary' FROM nd_82044037;

WITH nd_87598560 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Veg Rajdhani', 'veg rajdhani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg rajdhani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Veg Rajdhani', 'veg rajdhani', 'primary' FROM nd_87598560;

WITH nd_61752335 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sabzi Uttaranchali', 'sabzi uttaranchali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabzi uttaranchali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sabzi Uttaranchali', 'sabzi uttaranchali', 'primary' FROM nd_61752335;

WITH nd_35181326 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Tandoori Roti', 'tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Roti', 'tandoori roti', 'primary' FROM nd_35181326;

WITH nd_94256209 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Roti', 'butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Roti', 'butter roti', 'primary' FROM nd_94256209;

WITH nd_1756790 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Lachewala Paratha', 'lachewala paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lachewala paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Lachewala Paratha', 'lachewala paratha', 'primary' FROM nd_1756790;

WITH nd_50903462 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Lachewala Paratha', 'butter lachewala paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter lachewala paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Lachewala Paratha', 'butter lachewala paratha', 'primary' FROM nd_50903462;

WITH nd_12982712 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kulcha', 'kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kulcha', 'kulcha', 'primary' FROM nd_12982712;

WITH nd_60601994 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Kulcha', 'butter kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Kulcha', 'butter kulcha', 'primary' FROM nd_60601994;

WITH nd_29916768 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Naan', 'naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Naan', 'naan', 'primary' FROM nd_29916768;

WITH nd_92643944 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Naan', 'butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary' FROM nd_92643944;

WITH nd_43657288 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Garlic Naan', 'butter garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Garlic Naan', 'butter garlic naan', 'primary' FROM nd_43657288;

WITH nd_73180569 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Cheese Naan', 'butter cheese naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter cheese naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Cheese Naan', 'butter cheese naan', 'primary' FROM nd_73180569;

WITH nd_2968554 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Cheese Garlic Naan', 'butter cheese garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter cheese garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Cheese Garlic Naan', 'butter cheese garlic naan', 'primary' FROM nd_2968554;

WITH nd_23661867 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Aloo Paratha', 'butter aloo paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter aloo paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Aloo Paratha', 'butter aloo paratha', 'primary' FROM nd_23661867;

WITH nd_49216632 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Stuffed Paratha', 'butter stuffed paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter stuffed paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Stuffed Paratha', 'butter stuffed paratha', 'primary' FROM nd_49216632;

WITH nd_11838988 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Onion Kulcha', 'butter onion kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter onion kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Onion Kulcha', 'butter onion kulcha', 'primary' FROM nd_11838988;

WITH nd_71838844 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter With Breads Extra', 'butter with breads extra'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter with breads extra')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter With Breads Extra', 'butter with breads extra', 'primary' FROM nd_71838844;

WITH nd_13204991 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese With Breads Extra', 'cheese with breads extra'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese with breads extra')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese With Breads Extra', 'cheese with breads extra', 'primary' FROM nd_13204991;

WITH nd_795571 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Fry', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary' FROM nd_795571;

WITH nd_48704014 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Tadka', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary' FROM nd_48704014;

WITH nd_62743405 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Kolhapuri', 'dal kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Kolhapuri', 'dal kolhapuri', 'primary' FROM nd_62743405;

WITH nd_4360659 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Palak', 'dal palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Palak', 'dal palak', 'primary' FROM nd_4360659;

WITH nd_35133462 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Makhani', 'dal makhani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal makhani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Makhani', 'dal makhani', 'primary' FROM nd_35133462;

WITH nd_88895589 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Steam Rice', 'steam rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Steam Rice', 'steam rice', 'primary' FROM nd_88895589;

WITH nd_45706449 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Jeera Rice', 'jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary' FROM nd_45706449;

WITH nd_31585412 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Khichdi', 'dal khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi', 'dal khichdi', 'primary' FROM nd_31585412;

WITH nd_95926605 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dal Khichdi Tadka', 'dal khichdi tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi Tadka', 'dal khichdi tadka', 'primary' FROM nd_95926605;

WITH nd_55346051 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Palak Khichdi', 'palak khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Palak Khichdi', 'palak khichdi', 'primary' FROM nd_55346051;

WITH nd_84819693 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Curd Rice', 'curd rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Curd Rice', 'curd rice', 'primary' FROM nd_84819693;

WITH nd_42727272 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Pulao', 'vegetable pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Pulao', 'vegetable pulao', 'primary' FROM nd_42727272;

WITH nd_8714054 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kashmiri Pulao', 'kashmiri pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kashmiri pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kashmiri Pulao', 'kashmiri pulao', 'primary' FROM nd_8714054;

WITH nd_11535211 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Corn Pulao', 'corn pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'corn pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Corn Pulao', 'corn pulao', 'primary' FROM nd_11535211;

WITH nd_65408062 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Pulao', 'cheese pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Pulao', 'cheese pulao', 'primary' FROM nd_65408062;

WITH nd_11032999 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Pulao', 'paneer pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Pulao', 'paneer pulao', 'primary' FROM nd_11032999;

WITH nd_25681116 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Biryani', 'vegetable biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Biryani', 'vegetable biryani', 'primary' FROM nd_25681116;

WITH nd_9416787 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Hydrabadi Biryani', 'vegetable hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Hydrabadi Biryani', 'vegetable hydrabadi biryani', 'primary' FROM nd_9416787;

WITH nd_79025337 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer Tikka Biryani', 'paneer tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Biryani', 'paneer tikka biryani', 'primary' FROM nd_79025337;

WITH nd_67649352 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom Tikka Biryani', 'mushroom tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Tikka Biryani', 'mushroom tikka biryani', 'primary' FROM nd_67649352;

WITH nd_42278069 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable & Paneer Handi Biryani', 'vegetable & paneer handi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable & paneer handi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable & Paneer Handi Biryani', 'vegetable & paneer handi biryani', 'primary' FROM nd_42278069;

WITH nd_20275120 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Green Salad', 'green salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Green Salad', 'green salad', 'primary' FROM nd_20275120;

WITH nd_87470712 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Raita (Vegetable/ Boondi/Pineapple/Mint)', 'raita (vegetable/ boondi/pineapple/mint)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raita (vegetable/ boondi/pineapple/mint)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Raita (Vegetable/ Boondi/Pineapple/Mint)', 'raita (vegetable/ boondi/pineapple/mint)', 'primary' FROM nd_87470712;

WITH nd_97632940 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fruit & Dry Fruit Raita', 'fruit & dry fruit raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit & dry fruit raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fruit & Dry Fruit Raita', 'fruit & dry fruit raita', 'primary' FROM nd_97632940;

WITH nd_62139160 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Plain Curd', 'plain curd'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain curd')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Plain Curd', 'plain curd', 'primary' FROM nd_62139160;

WITH nd_68085723 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Roasted/ Fried Papad', 'roasted/ fried papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roasted/ fried papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Roasted/ Fried Papad', 'roasted/ fried papad', 'primary' FROM nd_68085723;

WITH nd_48765192 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Papad', 'masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary' FROM nd_48765192;

WITH nd_14830864 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Masala Khichiya Papad', 'masala khichiya papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala khichiya papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Masala Khichiya Papad', 'masala khichiya papad', 'primary' FROM nd_14830864;

WITH nd_25354197 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Khichiya Masala Papad With Cheese', 'khichiya masala papad with cheese'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'khichiya masala papad with cheese')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Khichiya Masala Papad With Cheese', 'khichiya masala papad with cheese', 'primary' FROM nd_25354197;

WITH nd_46476290 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cheese Grilled Papad', 'cheese grilled papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese grilled papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cheese Grilled Papad', 'cheese grilled papad', 'primary' FROM nd_46476290;

WITH nd_45607954 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable In Manchurian Gravy', 'vegetable in manchurian gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable in manchurian gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable In Manchurian Gravy', 'vegetable in manchurian gravy', 'primary' FROM nd_45607954;

WITH nd_42188564 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable In Hot Garlic Gravy', 'vegetable in hot garlic gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable in hot garlic gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable In Hot Garlic Gravy', 'vegetable in hot garlic gravy', 'primary' FROM nd_42188564;

WITH nd_24315388 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer In Hot Garlic Gravy', 'paneer in hot garlic gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer in hot garlic gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer In Hot Garlic Gravy', 'paneer in hot garlic gravy', 'primary' FROM nd_24315388;

WITH nd_95581720 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer In Manchurian Gravy', 'paneer in manchurian gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer in manchurian gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer In Manchurian Gravy', 'paneer in manchurian gravy', 'primary' FROM nd_95581720;

WITH nd_83970422 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer In Schezwan Gravy', 'paneer in schezwan gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer in schezwan gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer In Schezwan Gravy', 'paneer in schezwan gravy', 'primary' FROM nd_83970422;

WITH nd_53547244 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom In Manchurian Gravy', 'mushroom in manchurian gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom in manchurian gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom In Manchurian Gravy', 'mushroom in manchurian gravy', 'primary' FROM nd_53547244;

WITH nd_82580055 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable In Black Bean Gravy', 'vegetable in black bean gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable in black bean gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable In Black Bean Gravy', 'vegetable in black bean gravy', 'primary' FROM nd_82580055;

WITH nd_9067488 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mushroom In Hotpan Gravy', 'mushroom in hotpan gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom in hotpan gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mushroom In Hotpan Gravy', 'mushroom in hotpan gravy', 'primary' FROM nd_9067488;

WITH nd_19238754 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer In Oyster Gravy', 'paneer in oyster gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer in oyster gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer In Oyster Gravy', 'paneer in oyster gravy', 'primary' FROM nd_19238754;

WITH nd_19431440 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Paneer In Hot Basil Gravy', 'paneer in hot basil gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer in hot basil gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Paneer In Hot Basil Gravy', 'paneer in hot basil gravy', 'primary' FROM nd_19431440;

WITH nd_86947291 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Fried Rice', 'vegetable fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Fried Rice', 'vegetable fried rice', 'primary' FROM nd_86947291;

WITH nd_23490479 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Schezwan Fried Rice', 'vegetable schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Schezwan Fried Rice', 'vegetable schezwan fried rice', 'primary' FROM nd_23490479;

WITH nd_48637632 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Hong Kong Fried Rice', 'hong kong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hong kong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Hong Kong Fried Rice', 'hong kong fried rice', 'primary' FROM nd_48637632;

WITH nd_15569191 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Burnt Garlic Fried Rice', 'burnt garlic fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'burnt garlic fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'primary' FROM nd_15569191;

WITH nd_18890985 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Triple Schezwan Rice', 'vegetable triple schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable triple schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Triple Schezwan Rice', 'vegetable triple schezwan rice', 'primary' FROM nd_18890985;

WITH nd_72493132 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Combination Rice', 'vegetable combination rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable combination rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Combination Rice', 'vegetable combination rice', 'primary' FROM nd_72493132;

WITH nd_37753149 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Exotic Pot Rice', 'exotic pot rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'exotic pot rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Exotic Pot Rice', 'exotic pot rice', 'primary' FROM nd_37753149;

WITH nd_43478469 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Thai Curry With Steam Rice', 'thai curry with steam rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thai curry with steam rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Thai Curry With Steam Rice', 'thai curry with steam rice', 'primary' FROM nd_43478469;

WITH nd_15839049 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Hakka Noodles', 'vegetable hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Hakka Noodles', 'vegetable hakka noodles', 'primary' FROM nd_15839049;

WITH nd_52493440 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Schezwan Hakka Noodles', 'vegetable schezwan hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable schezwan hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Schezwan Hakka Noodles', 'vegetable schezwan hakka noodles', 'primary' FROM nd_52493440;

WITH nd_67954344 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'American Choupsey', 'american choupsey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'american choupsey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'American Choupsey', 'american choupsey', 'primary' FROM nd_67954344;

WITH nd_60582116 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chinese Choupsey', 'chinese choupsey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese choupsey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chinese Choupsey', 'chinese choupsey', 'primary' FROM nd_60582116;

WITH nd_17986002 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chilli Garlic Noodles', 'chilli garlic noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli garlic noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chilli Garlic Noodles', 'chilli garlic noodles', 'primary' FROM nd_17986002;

WITH nd_40012061 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Singapore Noodles', 'vegetable singapore noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable singapore noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Singapore Noodles', 'vegetable singapore noodles', 'primary' FROM nd_40012061;

WITH nd_83181340 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Vegetable Malaysian Pot Rice', 'vegetable malaysian pot rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable malaysian pot rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Vegetable Malaysian Pot Rice', 'vegetable malaysian pot rice', 'primary' FROM nd_83181340;

WITH nd_41362862 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mosambi', 'mosambi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mosambi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mosambi', 'mosambi', 'primary' FROM nd_41362862;

WITH nd_59884914 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Orange', 'orange'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'orange')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Orange', 'orange', 'primary' FROM nd_59884914;

WITH nd_44052601 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ganga Jamuna', 'ganga jamuna'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ganga jamuna')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ganga Jamuna', 'ganga jamuna', 'primary' FROM nd_44052601;

WITH nd_29008247 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mara Mari', 'mara mari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mara mari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mara Mari', 'mara mari', 'primary' FROM nd_29008247;

WITH nd_81909013 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ganga Jamuna Saraswati', 'ganga jamuna saraswati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ganga jamuna saraswati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ganga Jamuna Saraswati', 'ganga jamuna saraswati', 'primary' FROM nd_81909013;

WITH nd_96882004 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Pineapple', 'pineapple'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Pineapple', 'pineapple', 'primary' FROM nd_96882004;

WITH nd_11717474 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Apple', 'apple'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'apple')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Apple', 'apple', 'primary' FROM nd_11717474;

WITH nd_38920846 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Grapes', 'grapes'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'grapes')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Grapes', 'grapes', 'primary' FROM nd_38920846;

WITH nd_36176645 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Water Melon', 'water melon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'water melon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Water Melon', 'water melon', 'primary' FROM nd_36176645;

WITH nd_5938440 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Anar', 'anar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'anar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Anar', 'anar', 'primary' FROM nd_5938440;

WITH nd_54788867 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fresh Lime Juice', 'fresh lime juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh lime juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fresh Lime Juice', 'fresh lime juice', 'primary' FROM nd_54788867;

WITH nd_10993664 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fresh Lime Soda', 'fresh lime soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh lime soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fresh Lime Soda', 'fresh lime soda', 'primary' FROM nd_10993664;

WITH nd_71233484 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Ginger Lemon Soda', 'ginger lemon soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ginger lemon soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Ginger Lemon Soda', 'ginger lemon soda', 'primary' FROM nd_71233484;

WITH nd_21697887 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Watermelon Blossom', 'watermelon blossom'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'watermelon blossom')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Watermelon Blossom', 'watermelon blossom', 'primary' FROM nd_21697887;

WITH nd_62781343 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Pineapple Blossom', 'pineapple blossom'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple blossom')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Pineapple Blossom', 'pineapple blossom', 'primary' FROM nd_62781343;

WITH nd_54427773 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Orange Blossom', 'orange blossom'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'orange blossom')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Orange Blossom', 'orange blossom', 'primary' FROM nd_54427773;

WITH nd_39939663 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cocktail', 'cocktail'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cocktail')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cocktail', 'cocktail', 'primary' FROM nd_39939663;

WITH nd_26549350 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Black Currant', 'black currant'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black currant')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Black Currant', 'black currant', 'primary' FROM nd_26549350;

WITH nd_92882448 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Special Grape', 'special grape'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special grape')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Special Grape', 'special grape', 'primary' FROM nd_92882448;

WITH nd_89920703 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Thandai Milk Shake', 'thandai milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thandai milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Thandai Milk Shake', 'thandai milk shake', 'primary' FROM nd_89920703;

WITH nd_12058829 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mint Mojito', 'mint mojito'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mint mojito')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mint Mojito', 'mint mojito', 'primary' FROM nd_12058829;

WITH nd_87775395 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Blue Heaven', 'blue heaven'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'blue heaven')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Blue Heaven', 'blue heaven', 'primary' FROM nd_87775395;

WITH nd_90113589 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mango Delight', 'mango delight'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango delight')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mango Delight', 'mango delight', 'primary' FROM nd_90113589;

WITH nd_35377989 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kiwi Mojito', 'kiwi mojito'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kiwi mojito')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kiwi Mojito', 'kiwi mojito', 'primary' FROM nd_35377989;

WITH nd_69938587 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Litchi Grasshopper', 'litchi grasshopper'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'litchi grasshopper')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Litchi Grasshopper', 'litchi grasshopper', 'primary' FROM nd_69938587;

WITH nd_51957586 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kiwi High', 'kiwi high'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kiwi high')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kiwi High', 'kiwi high', 'primary' FROM nd_51957586;

WITH nd_72076939 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Golden Glow', 'golden glow'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'golden glow')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Golden Glow', 'golden glow', 'primary' FROM nd_72076939;

WITH nd_279006 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Blue Berry', 'blue berry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'blue berry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Blue Berry', 'blue berry', 'primary' FROM nd_279006;

WITH nd_7503146 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Pinacolada', 'pinacolada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pinacolada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Pinacolada', 'pinacolada', 'primary' FROM nd_7503146;

WITH nd_42642388 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fruit Punch', 'fruit punch'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit punch')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fruit Punch', 'fruit punch', 'primary' FROM nd_42642388;

WITH nd_4597712 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Litchi Mojito', 'litchi mojito'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'litchi mojito')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Litchi Mojito', 'litchi mojito', 'primary' FROM nd_4597712;

WITH nd_79348339 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Lemon Ice Tea', 'lemon ice tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon ice tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Lemon Ice Tea', 'lemon ice tea', 'primary' FROM nd_79348339;

WITH nd_87688234 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Peach Ice Tea', 'peach ice tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'peach ice tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Peach Ice Tea', 'peach ice tea', 'primary' FROM nd_87688234;

WITH nd_32666768 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chikku', 'chikku'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chikku')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chikku', 'chikku', 'primary' FROM nd_32666768;

WITH nd_93817243 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chikku Chocolate', 'chikku chocolate'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chikku chocolate')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chikku Chocolate', 'chikku chocolate', 'primary' FROM nd_93817243;

WITH nd_96960449 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chocolate / Vanilla', 'chocolate / vanilla'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chocolate / vanilla')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chocolate / Vanilla', 'chocolate / vanilla', 'primary' FROM nd_96960449;

WITH nd_52384193 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cold Coffee', 'cold coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cold coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cold Coffee', 'cold coffee', 'primary' FROM nd_52384193;

WITH nd_54169182 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butterscotch', 'butterscotch'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butterscotch')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butterscotch', 'butterscotch', 'primary' FROM nd_54169182;

WITH nd_55181798 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Brownie', 'brownie'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'brownie')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Brownie', 'brownie', 'primary' FROM nd_55181798;

WITH nd_77591164 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Oreo / Kitkat', 'oreo / kitkat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'oreo / kitkat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Oreo / Kitkat', 'oreo / kitkat', 'primary' FROM nd_77591164;

WITH nd_17424416 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sitafal / Mango / Strawberry (Seasonal)', 'sitafal / mango / strawberry (seasonal)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sitafal / mango / strawberry (seasonal)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sitafal / Mango / Strawberry (Seasonal)', 'sitafal / mango / strawberry (seasonal)', 'primary' FROM nd_17424416;

WITH nd_55589676 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Extra Scoops With Ice Cream', 'extra scoops with ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra scoops with ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Extra Scoops With Ice Cream', 'extra scoops with ice cream', 'primary' FROM nd_55589676;

WITH nd_27258908 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chocolate With Nuts', 'chocolate with nuts'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chocolate with nuts')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chocolate With Nuts', 'chocolate with nuts', 'primary' FROM nd_27258908;

WITH nd_1757043 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kaju Milk Shake', 'kaju milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kaju Milk Shake', 'kaju milk shake', 'primary' FROM nd_1757043;

WITH nd_51790826 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Date & Kaju', 'date & kaju'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'date & kaju')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Date & Kaju', 'date & kaju', 'primary' FROM nd_51790826;

WITH nd_89034483 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kaju Anjeer', 'kaju anjeer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju anjeer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kaju Anjeer', 'kaju anjeer', 'primary' FROM nd_89034483;

WITH nd_73525012 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Badam Pista', 'badam pista'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'badam pista')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Badam Pista', 'badam pista', 'primary' FROM nd_73525012;

WITH nd_94567899 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chikku Chocolate With Nuts', 'chikku chocolate with nuts'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chikku chocolate with nuts')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chikku Chocolate With Nuts', 'chikku chocolate with nuts', 'primary' FROM nd_94567899;

WITH nd_43838430 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Anjeer', 'anjeer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'anjeer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Anjeer', 'anjeer', 'primary' FROM nd_43838430;

WITH nd_21497837 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dry Fruit Mix', 'dry fruit mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Mix', 'dry fruit mix', 'primary' FROM nd_21497837;

WITH nd_10948376 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Beverages', 'beverages'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'beverages')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Beverages', 'beverages', 'primary' FROM nd_10948376;

WITH nd_6603347 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Butter Milk', 'butter milk'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter milk')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Butter Milk', 'butter milk', 'primary' FROM nd_6603347;

WITH nd_6876542 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Sweet Lassi', 'sweet lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Sweet Lassi', 'sweet lassi', 'primary' FROM nd_6876542;

WITH nd_66828372 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kesar Lassi', 'kesar lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kesar Lassi', 'kesar lassi', 'primary' FROM nd_66828372;

WITH nd_78578300 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Strawberry Lassi', 'strawberry lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'strawberry lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Strawberry Lassi', 'strawberry lassi', 'primary' FROM nd_78578300;

WITH nd_32475601 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Mango Lassi', 'mango lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Mango Lassi', 'mango lassi', 'primary' FROM nd_32475601;

WITH nd_80793226 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Dry Fruit Lassi', 'dry fruit lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Lassi', 'dry fruit lassi', 'primary' FROM nd_80793226;

WITH nd_38769630 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Royal Falooda', 'royal falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'royal falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Royal Falooda', 'royal falooda', 'primary' FROM nd_38769630;

WITH nd_68511637 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kesar Falooda', 'kesar falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kesar Falooda', 'kesar falooda', 'primary' FROM nd_68511637;

WITH nd_59609311 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Chocolate Falooda', 'chocolate falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chocolate falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Chocolate Falooda', 'chocolate falooda', 'primary' FROM nd_59609311;

WITH nd_57540798 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kulfi Falooda', 'kulfi falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulfi falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kulfi Falooda', 'kulfi falooda', 'primary' FROM nd_57540798;

WITH nd_96168838 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Special Dry Fruit Falooda', 'special dry fruit falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special dry fruit falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Special Dry Fruit Falooda', 'special dry fruit falooda', 'primary' FROM nd_96168838;

WITH nd_78091317 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Plain Jelly', 'plain jelly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain jelly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Plain Jelly', 'plain jelly', 'primary' FROM nd_78091317;

WITH nd_13563314 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Jelly With Ice Cream', 'jelly with ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jelly with ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Jelly With Ice Cream', 'jelly with ice cream', 'primary' FROM nd_13563314;

WITH nd_9882198 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fruit Salad', 'fruit salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fruit Salad', 'fruit salad', 'primary' FROM nd_9882198;

WITH nd_11582499 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fruit Salad With Jelly', 'fruit salad with jelly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad with jelly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fruit Salad With Jelly', 'fruit salad with jelly', 'primary' FROM nd_11582499;

WITH nd_40586528 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fruit Salad With Ice Cream', 'fruit salad with ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad with ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fruit Salad With Ice Cream', 'fruit salad with ice cream', 'primary' FROM nd_40586528;

WITH nd_23173473 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Fruit Salad With Jelly & Ice Cream', 'fruit salad with jelly & ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad with jelly & ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Fruit Salad With Jelly & Ice Cream', 'fruit salad with jelly & ice cream', 'primary' FROM nd_23173473;

WITH nd_96710364 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Brownie With Ice Cream', 'brownie with ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'brownie with ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Brownie With Ice Cream', 'brownie with ice cream', 'primary' FROM nd_96710364;

WITH nd_17042501 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Hot Gulab Jamun', 'hot gulab jamun'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot gulab jamun')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Hot Gulab Jamun', 'hot gulab jamun', 'primary' FROM nd_17042501;

WITH nd_42602777 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Gulab Jamun With Vanilla Ice Cream', 'gulab jamun with vanilla ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gulab jamun with vanilla ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Gulab Jamun With Vanilla Ice Cream', 'gulab jamun with vanilla ice cream', 'primary' FROM nd_42602777;

WITH nd_10474887 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Gulab Jamun With Rabdi', 'gulab jamun with rabdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gulab jamun with rabdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Gulab Jamun With Rabdi', 'gulab jamun with rabdi', 'primary' FROM nd_10474887;

WITH nd_28601547 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Rabdi', 'rabdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rabdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Rabdi', 'rabdi', 'primary' FROM nd_28601547;

WITH nd_79721688 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Gadbad Ice Cream', 'gadbad ice cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gadbad ice cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Gadbad Ice Cream', 'gadbad ice cream', 'primary' FROM nd_79721688;

WITH nd_38755901 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Malai Kulfi', 'malai kulfi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai kulfi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Malai Kulfi', 'malai kulfi', 'primary' FROM nd_38755901;

WITH nd_97293776 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Kesar Pista Kulfi', 'kesar pista kulfi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar pista kulfi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Kesar Pista Kulfi', 'kesar pista kulfi', 'primary' FROM nd_97293776;

WITH nd_58624823 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Cool Scoops', 'cool scoops'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cool scoops')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Cool Scoops', 'cool scoops', 'primary' FROM nd_58624823;

WITH nd_18108286 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('u2m_other_id_seq'), 'Premium Scoops', 'premium scoops'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'premium scoops')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('u2m_other_id_seq'), canonical_dish_id, 'en', 'Premium Scoops', 'premium scoops', 'primary' FROM nd_18108286;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004001, 400086004, cd.canonical_dish_id, 'Steam Idli', 'steam idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'steam idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004001, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004001, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004002, 400086004, cd.canonical_dish_id, 'Udupi Idli', 'udupi idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'udupi idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004002, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004002, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004003, 400086004, cd.canonical_dish_id, 'That Idli', 'that idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'that idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004003, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004003, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004004, 400086004, cd.canonical_dish_id, 'Butter Idli', 'butter idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004004, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004004, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004005, 400086004, cd.canonical_dish_id, 'Tawa Masala Idli', 'tawa masala idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tawa masala idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004005, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004005, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004006, 400086004, cd.canonical_dish_id, 'Dahi Idli', 'dahi idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dahi idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004006, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004006, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004007, 400086004, cd.canonical_dish_id, 'Fry Idli', 'fry idli', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fry idli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004007, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004007, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004008, 400086004, cd.canonical_dish_id, 'Medu Wada', 'medu wada', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'medu wada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004008, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004008, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004009, 400086004, cd.canonical_dish_id, 'Idli Wada', 'idli wada', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'idli wada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004009, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004009, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004010, 400086004, cd.canonical_dish_id, 'Rasam Wada', 'rasam wada', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rasam wada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004010, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004010, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SOUTH INDIAN SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004011, 400086004, cd.canonical_dish_id, 'Dahi Wada', 'dahi wada', 'SOUTH INDIAN SNACKS', 400086004001, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dahi wada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004011, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004011, 400086004, 400086004001, menu_item_id, 400086004001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004012, 400086004, cd.canonical_dish_id, 'Sada Dosa', 'sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004012, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004012, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004013, 400086004, cd.canonical_dish_id, 'Cheese Sada Dosa', 'cheese sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004013, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004013, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004014, 400086004, cd.canonical_dish_id, 'Ghee Roast Sada Dosa', 'ghee roast sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ghee roast sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004014, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004014, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004015, 400086004, cd.canonical_dish_id, 'Mysore Sada Dosa', 'mysore sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mysore sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004015, variant_id, 145, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004015, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004016, 400086004, cd.canonical_dish_id, 'Rawa Sada Dosa', 'rawa sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawa sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004016, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004016, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004017, 400086004, cd.canonical_dish_id, 'Ghee Rawa Sada Dosa', 'ghee rawa sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ghee rawa sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004017, variant_id, 185, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004017, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004018, 400086004, cd.canonical_dish_id, 'Onion Rawa Sada Dosa', 'onion rawa sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'onion rawa sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004018, variant_id, 165, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004018, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004019, 400086004, cd.canonical_dish_id, 'Butter Sada Dosa', 'butter sada dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter sada dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004019, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004019, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004020, 400086004, cd.canonical_dish_id, 'Masala Dosa', 'masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004020, variant_id, 155, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004020, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004021, 400086004, cd.canonical_dish_id, 'Ghee Roast Masala Dosa', 'ghee roast masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ghee roast masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004021, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004021, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004022, 400086004, cd.canonical_dish_id, 'Mysore Masala Dosa', 'mysore masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mysore masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004022, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004022, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004023, 400086004, cd.canonical_dish_id, 'Rawa Masala Dosa', 'rawa masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawa masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004023, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004023, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004024, 400086004, cd.canonical_dish_id, 'Ghee Rawa Masala Dosa', 'ghee rawa masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ghee rawa masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004024, variant_id, 205, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004024, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004025, 400086004, cd.canonical_dish_id, 'Onion Rawa Masala Dosa', 'onion rawa masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'onion rawa masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004025, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004025, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004026, 400086004, cd.canonical_dish_id, 'Ragi Dosa', 'ragi dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ragi dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004026, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004026, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004027, 400086004, cd.canonical_dish_id, 'Ragi Masala Dosa', 'ragi masala dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ragi masala dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004027, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004027, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004028, 400086004, cd.canonical_dish_id, 'Moong Dosa', 'moong dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'moong dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004028, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004028, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004029, 400086004, cd.canonical_dish_id, 'Malgudi Dosa', 'malgudi dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malgudi dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004029, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004029, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004030, 400086004, cd.canonical_dish_id, 'Set Dosa', 'set dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'set dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004030, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004030, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004031, 400086004, cd.canonical_dish_id, 'Crispy Schezwan Dosa', 'crispy schezwan dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'crispy schezwan dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004031, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004031, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004032, 400086004, cd.canonical_dish_id, 'Spl Mysore Masala (Soft)', 'spl mysore masala (soft)', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'spl mysore masala (soft)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004032, variant_id, 185, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004032, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004033, 400086004, cd.canonical_dish_id, 'Udupi Benne Dosa', 'udupi benne dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'udupi benne dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004033, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004033, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004034, 400086004, cd.canonical_dish_id, 'Plain Uttapam', 'plain uttapam', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain uttapam'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004034, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004034, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004035, 400086004, cd.canonical_dish_id, 'Onion Uttappam', 'onion uttappam', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'onion uttappam'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004035, variant_id, 165, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004035, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004036, 400086004, cd.canonical_dish_id, 'Tomato Uttappam', 'tomato uttappam', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tomato uttappam'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004036, variant_id, 165, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004036, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004037, 400086004, cd.canonical_dish_id, 'Masala Uttappam', 'masala uttappam', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala uttappam'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004037, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004037, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004038, 400086004, cd.canonical_dish_id, 'Mix Uttappam (Onion, Tomato, Masala)', 'mix uttappam (onion tomato masala)', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mix uttappam (onion tomato masala)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004038, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004038, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004039, 400086004, cd.canonical_dish_id, 'Tomato Omlet', 'tomato omlet', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tomato omlet'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004039, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004039, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004040, 400086004, cd.canonical_dish_id, 'Spring Dosa', 'spring dosa', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'spring dosa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004040, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004040, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004041, 400086004, cd.canonical_dish_id, 'All Dosa With Butter', 'all dosa with butter', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'all dosa with butter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004041, variant_id, 25, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004041, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DOSA & MORE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004042, 400086004, cd.canonical_dish_id, 'All Dosa With Cheese', 'all dosa with cheese', 'DOSA & MORE', 400086004002, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'all dosa with cheese'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004042, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004042, 400086004, 400086004001, menu_item_id, 400086004002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "UPVAS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004043, 400086004, cd.canonical_dish_id, 'Sabudana Wada', 'sabudana wada', 'UPVAS', 400086004003, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sabudana wada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004043, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004043, 400086004, 400086004001, menu_item_id, 400086004003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "UPVAS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004044, 400086004, cd.canonical_dish_id, 'Sabudana Khichdi', 'sabudana khichdi', 'UPVAS', 400086004003, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sabudana khichdi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004044, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004044, 400086004, 400086004001, menu_item_id, 400086004003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004045, 400086004, cd.canonical_dish_id, 'Pav Bhaji', 'pav bhaji', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pav bhaji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004045, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004045, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004046, 400086004, cd.canonical_dish_id, 'Jain Pav Bhaji', 'jain pav bhaji', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jain pav bhaji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004046, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004046, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004047, 400086004, cd.canonical_dish_id, 'Khada Pav Bhaji', 'khada pav bhaji', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'khada pav bhaji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004047, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004047, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004048, 400086004, cd.canonical_dish_id, 'Masala Pav Bhaji', 'masala pav bhaji', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala pav bhaji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004048, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004048, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004049, 400086004, cd.canonical_dish_id, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese pav bhaji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004049, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004049, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004050, 400086004, cd.canonical_dish_id, 'U2M Special Pav Bhaji', 'u2m special pav bhaji', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'u2m special pav bhaji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004050, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004050, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004051, 400086004, cd.canonical_dish_id, 'Chutney Masala Pav (2 Pcs)', 'chutney masala pav (2 pcs)', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chutney masala pav (2 pcs)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004051, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004051, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004052, 400086004, cd.canonical_dish_id, 'Spl Pav Sandwich', 'spl pav sandwich', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'spl pav sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004052, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004052, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004053, 400086004, cd.canonical_dish_id, 'Cheese Pav Sandwich', 'cheese pav sandwich', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese pav sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004053, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004053, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004054, 400086004, cd.canonical_dish_id, 'Masala Pav (2 Pcs)', 'masala pav (2 pcs)', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala pav (2 pcs)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004054, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004054, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004055, 400086004, cd.canonical_dish_id, 'Tawa Pulao', 'tawa pulao', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tawa pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004055, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004055, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004056, 400086004, cd.canonical_dish_id, 'Cheese Tawa Pulao', 'cheese tawa pulao', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese tawa pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004056, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004056, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004057, 400086004, cd.canonical_dish_id, 'Sada Pav', 'sada pav', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sada pav'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004057, variant_id, 10, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004057, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004058, 400086004, cd.canonical_dish_id, 'Kadak Sada Pav', 'kadak sada pav', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kadak sada pav'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004058, variant_id, 20, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004058, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004059, 400086004, cd.canonical_dish_id, 'Extra Butter Pav (Single)', 'extra butter pav (single)', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'extra butter pav (single)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004059, variant_id, 20, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004059, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PAV BHAJI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004060, 400086004, cd.canonical_dish_id, 'Butter Kadak Sada Pav (Single)', 'butter kadak sada pav (single)', 'PAV BHAJI', 400086004004, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter kadak sada pav (single)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004060, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004060, 400086004, 400086004001, menu_item_id, 400086004004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004061, 400086004, cd.canonical_dish_id, 'Pani Puri', 'pani puri', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pani puri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004061, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004061, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004062, 400086004, cd.canonical_dish_id, 'Puneri Bhel', 'puneri bhel', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'puneri bhel'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004062, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004062, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004063, 400086004, cd.canonical_dish_id, 'Kolhapuri Bhel', 'kolhapuri bhel', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kolhapuri bhel'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004063, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004063, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004064, 400086004, cd.canonical_dish_id, 'Sev Puri', 'sev puri', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sev puri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004064, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004064, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004065, 400086004, cd.canonical_dish_id, 'Dahi Batata Puri', 'dahi batata puri', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dahi batata puri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004065, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004065, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004066, 400086004, cd.canonical_dish_id, 'Ragda Pattice', 'ragda pattice', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ragda pattice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004066, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004066, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004067, 400086004, cd.canonical_dish_id, 'Samosa Chaat', 'samosa chaat', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'samosa chaat'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004067, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004067, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHAAT" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004068, 400086004, cd.canonical_dish_id, 'Rajkachori Chaat', 'rajkachori chaat', 'CHAAT', 400086004005, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rajkachori chaat'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004068, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004068, 400086004, 400086004001, menu_item_id, 400086004005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004069, 400086004, cd.canonical_dish_id, 'Vegetable Burger', 'vegetable burger', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable burger'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004069, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004069, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004070, 400086004, cd.canonical_dish_id, 'Cheese Burger', 'cheese burger', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese burger'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004070, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004070, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004071, 400086004, cd.canonical_dish_id, 'Vegetable Hot Dog', 'vegetable hot dog', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable hot dog'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004071, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004071, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004072, 400086004, cd.canonical_dish_id, 'Cheese Hot Dog', 'cheese hot dog', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese hot dog'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004072, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004072, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004073, 400086004, cd.canonical_dish_id, 'Cheese Chilly Toast', 'cheese chilly toast', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chilly toast'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004073, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004073, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004074, 400086004, cd.canonical_dish_id, 'Garlic Roll', 'garlic roll', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004074, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004074, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004075, 400086004, cd.canonical_dish_id, 'Garlic Cheese Roll', 'garlic cheese roll', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic cheese roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004075, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004075, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004076, 400086004, cd.canonical_dish_id, 'Cheese Roll', 'cheese roll', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004076, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004076, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BREAD ROLLS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004077, 400086004, cd.canonical_dish_id, 'Family Garlic Cheese Roll', 'family garlic cheese roll', 'BREAD ROLLS', 400086004006, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'family garlic cheese roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004077, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004077, 400086004, 400086004001, menu_item_id, 400086004006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004078, 400086004, cd.canonical_dish_id, 'Vegetable Sandwich', 'vegetable sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004078, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004078, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004079, 400086004, cd.canonical_dish_id, 'Vegetable Cheese Sandwich', 'vegetable cheese sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable cheese sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004079, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004079, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004080, 400086004, cd.canonical_dish_id, 'Only Cheese Sandwich', 'only cheese sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'only cheese sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004080, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004080, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004081, 400086004, cd.canonical_dish_id, 'Vegetable Toast Sandwich', 'vegetable toast sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable toast sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004081, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004081, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004082, 400086004, cd.canonical_dish_id, 'Cheese Toast Sandwich', 'cheese toast sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese toast sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004082, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004082, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004083, 400086004, cd.canonical_dish_id, 'Masala Toast Sandwich', 'masala toast sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala toast sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004083, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004083, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004084, 400086004, cd.canonical_dish_id, 'Cheese Masala Toast Sandwich', 'cheese masala toast sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese masala toast sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004084, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004084, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004085, 400086004, cd.canonical_dish_id, 'Club Sandwich', 'club sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'club sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004085, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004085, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004086, 400086004, cd.canonical_dish_id, 'Bread Butter', 'bread butter', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bread butter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004086, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004086, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004087, 400086004, cd.canonical_dish_id, 'Toast Butter', 'toast butter', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'toast butter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004087, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004087, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004088, 400086004, cd.canonical_dish_id, 'Jam Bread Butter', 'jam bread butter', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jam bread butter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004088, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004088, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SANDWICHS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004089, 400086004, cd.canonical_dish_id, 'Chutney Sandwich', 'chutney sandwich', 'SANDWICHS', 400086004007, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chutney sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004089, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004089, 400086004, 400086004001, menu_item_id, 400086004007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004090, 400086004, cd.canonical_dish_id, 'Vegetable Grill Sandwich', 'vegetable grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004090, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004090, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004091, 400086004, cd.canonical_dish_id, 'Vegetable Cheese Grill Sandwich', 'vegetable cheese grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable cheese grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004091, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004091, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004092, 400086004, cd.canonical_dish_id, 'Only Cheese Grill Sandwich', 'only cheese grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'only cheese grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004092, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004092, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004093, 400086004, cd.canonical_dish_id, 'Masala Grill Sandwich', 'masala grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004093, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004093, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004094, 400086004, cd.canonical_dish_id, 'Garlic Cheese Grill Sandwich', 'garlic cheese grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic cheese grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004094, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004094, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004095, 400086004, cd.canonical_dish_id, 'Corn Capsicum Grill Sandwich', 'corn capsicum grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'corn capsicum grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004095, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004095, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004096, 400086004, cd.canonical_dish_id, 'Mushroom Cheese Grill Sandwich', 'mushroom cheese grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom cheese grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004096, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004096, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "GRILL SANDWICHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004097, 400086004, cd.canonical_dish_id, 'Masala Cheese Grill Sandwich', 'masala cheese grill sandwich', 'GRILL SANDWICHES', 400086004008, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala cheese grill sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004097, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004097, 400086004, 400086004001, menu_item_id, 400086004008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN PIZZA (6 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004098, 400086004, cd.canonical_dish_id, 'Vegetable Cheese Pizza', 'vegetable cheese pizza', 'INDIAN PIZZA (6 INCH)', 400086004009, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable cheese pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004098, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004098, 400086004, 400086004001, menu_item_id, 400086004009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN PIZZA (6 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004099, 400086004, cd.canonical_dish_id, 'Only Cheese Pizza', 'only cheese pizza', 'INDIAN PIZZA (6 INCH)', 400086004009, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'only cheese pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004099, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004099, 400086004, 400086004001, menu_item_id, 400086004009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN PIZZA (6 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004100, 400086004, cd.canonical_dish_id, 'Crispy Schezwan Pizza', 'crispy schezwan pizza', 'INDIAN PIZZA (6 INCH)', 400086004009, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'crispy schezwan pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004100, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004100, 400086004, 400086004001, menu_item_id, 400086004009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN PIZZA (6 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004101, 400086004, cd.canonical_dish_id, 'Corn Cheese Pizza', 'corn cheese pizza', 'INDIAN PIZZA (6 INCH)', 400086004009, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'corn cheese pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004101, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004101, 400086004, 400086004001, menu_item_id, 400086004009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN PIZZA (6 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004102, 400086004, cd.canonical_dish_id, 'Mushroom Pizza', 'mushroom pizza', 'INDIAN PIZZA (6 INCH)', 400086004009, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004102, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004102, 400086004, 400086004001, menu_item_id, 400086004009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL PIZZA (10 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004103, 400086004, cd.canonical_dish_id, 'Margherita', 'margherita', 'CONTINENTAL PIZZA (10 INCH)', 400086004010, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'margherita'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004103, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004103, 400086004, 400086004001, menu_item_id, 400086004010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL PIZZA (10 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004104, 400086004, cd.canonical_dish_id, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'CONTINENTAL PIZZA (10 INCH)', 400086004010, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004104, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004104, 400086004, 400086004001, menu_item_id, 400086004010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL PIZZA (10 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004105, 400086004, cd.canonical_dish_id, 'Paneer Perika Pizza', 'paneer perika pizza', 'CONTINENTAL PIZZA (10 INCH)', 400086004010, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer perika pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004105, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004105, 400086004, 400086004001, menu_item_id, 400086004010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL PIZZA (10 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004106, 400086004, cd.canonical_dish_id, 'Americano', 'americano', 'CONTINENTAL PIZZA (10 INCH)', 400086004010, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'americano'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004106, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004106, 400086004, 400086004001, menu_item_id, 400086004010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL PIZZA (10 INCH)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004107, 400086004, cd.canonical_dish_id, 'Fresh Farmhouse Pizza', 'fresh farmhouse pizza', 'CONTINENTAL PIZZA (10 INCH)', 400086004010, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fresh farmhouse pizza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004107, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004107, 400086004, 400086004001, menu_item_id, 400086004010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PASTA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004108, 400086004, cd.canonical_dish_id, 'Arrabiata Pasta', 'arrabiata pasta', 'PASTA', 400086004011, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'arrabiata pasta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004108, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004108, 400086004, 400086004001, menu_item_id, 400086004011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PASTA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004109, 400086004, cd.canonical_dish_id, 'Alfredo Pasta', 'alfredo pasta', 'PASTA', 400086004011, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'alfredo pasta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004109, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004109, 400086004, 400086004001, menu_item_id, 400086004011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PASTA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004110, 400086004, cd.canonical_dish_id, 'Green Pesto Pasta', 'green pesto pasta', 'PASTA', 400086004011, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'green pesto pasta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004110, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004110, 400086004, 400086004001, menu_item_id, 400086004011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PASTA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004111, 400086004, cd.canonical_dish_id, 'Handmade Ravoli Pasta', 'handmade ravoli pasta', 'PASTA', 400086004011, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'handmade ravoli pasta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004111, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004111, 400086004, 400086004001, menu_item_id, 400086004011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PASTA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004112, 400086004, cd.canonical_dish_id, 'Spaghetti Aglio E Olio', 'spaghetti aglio e olio', 'PASTA', 400086004011, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'spaghetti aglio e olio'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004112, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004112, 400086004, 400086004001, menu_item_id, 400086004011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "PASTA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004113, 400086004, cd.canonical_dish_id, 'Lasagna', 'lasagna', 'PASTA', 400086004011, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lasagna'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004113, variant_id, 420, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004113, 400086004, 400086004001, menu_item_id, 400086004011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL & MEXICAN RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004114, 400086004, cd.canonical_dish_id, 'Mexican Tit Bit Rice', 'mexican tit bit rice', 'CONTINENTAL & MEXICAN RICE', 400086004012, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mexican tit bit rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004114, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004114, 400086004, 400086004001, menu_item_id, 400086004012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL & MEXICAN RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004115, 400086004, cd.canonical_dish_id, 'Risotto', 'risotto', 'CONTINENTAL & MEXICAN RICE', 400086004012, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'risotto'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004115, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004115, 400086004, 400086004001, menu_item_id, 400086004012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004116, 400086004, cd.canonical_dish_id, 'Cream Of Broccoli Soup', 'cream of broccoli soup', 'CONTINENTAL SOUP', 400086004013, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream of broccoli soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004116, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004116, 400086004, 400086004001, menu_item_id, 400086004013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004117, 400086004, cd.canonical_dish_id, 'Cream Of Tomato Soup', 'cream of tomato soup', 'CONTINENTAL SOUP', 400086004013, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream of tomato soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004117, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004117, 400086004, 400086004001, menu_item_id, 400086004013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004118, 400086004, cd.canonical_dish_id, 'Cream Of Mushroom', 'cream of mushroom', 'CONTINENTAL SOUP', 400086004013, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream of mushroom'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004118, variant_id, 175, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004118, 400086004, 400086004001, menu_item_id, 400086004013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004119, 400086004, cd.canonical_dish_id, 'Tomato Basil Soup', 'tomato basil soup', 'CONTINENTAL SOUP', 400086004013, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tomato basil soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004119, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004119, 400086004, 400086004001, menu_item_id, 400086004013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004120, 400086004, cd.canonical_dish_id, 'Manchow Soup', 'manchow soup', 'CHINESE SOUP', 400086004014, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'manchow soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004120, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004120, 400086004, 400086004001, menu_item_id, 400086004014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004121, 400086004, cd.canonical_dish_id, 'Hot & Sour Soup', 'hot & sour soup', 'CHINESE SOUP', 400086004014, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot & sour soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004121, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004121, 400086004, 400086004001, menu_item_id, 400086004014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004122, 400086004, cd.canonical_dish_id, 'Sweet Corn Soup', 'sweet corn soup', 'CHINESE SOUP', 400086004014, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sweet corn soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004122, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004122, 400086004, 400086004001, menu_item_id, 400086004014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004123, 400086004, cd.canonical_dish_id, 'Vegetable Clear Soup', 'vegetable clear soup', 'CHINESE SOUP', 400086004014, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable clear soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004123, variant_id, 135, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004123, 400086004, 400086004001, menu_item_id, 400086004014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004124, 400086004, cd.canonical_dish_id, 'Lemon Coriander Soup', 'lemon coriander soup', 'CHINESE SOUP', 400086004014, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lemon coriander soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004124, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004124, 400086004, 400086004001, menu_item_id, 400086004014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004125, 400086004, cd.canonical_dish_id, 'Mushroom Soup', 'mushroom soup', 'CHINESE SOUP', 400086004014, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004125, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004125, 400086004, 400086004001, menu_item_id, 400086004014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPECIAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004126, 400086004, cd.canonical_dish_id, 'Vegetable Burnt Garlic Soup', 'vegetable burnt garlic soup', 'CHEF SPECIAL SOUP', 400086004015, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable burnt garlic soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004126, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004126, 400086004, 400086004001, menu_item_id, 400086004015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPECIAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004127, 400086004, cd.canonical_dish_id, 'Hot Garlic Noodle Soup', 'hot garlic noodle soup', 'CHEF SPECIAL SOUP', 400086004015, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot garlic noodle soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004127, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004127, 400086004, 400086004001, menu_item_id, 400086004015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPECIAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004128, 400086004, cd.canonical_dish_id, 'Thai Vegetable Soup (Red/Green)', 'thai vegetable soup (red/green)', 'CHEF SPECIAL SOUP', 400086004015, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'thai vegetable soup (red/green)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004128, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004128, 400086004, 400086004001, menu_item_id, 400086004015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPECIAL SOUP" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004129, 400086004, cd.canonical_dish_id, 'Cheesling Rice Soup', 'cheesling rice soup', 'CHEF SPECIAL SOUP', 400086004015, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheesling rice soup'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004129, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004129, 400086004, 400086004001, menu_item_id, 400086004015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004130, 400086004, cd.canonical_dish_id, 'Cheese Corn Balls', 'cheese corn balls', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese corn balls'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004130, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004130, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004131, 400086004, cd.canonical_dish_id, 'Garlic Bread', 'garlic bread', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic bread'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004131, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004131, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004132, 400086004, cd.canonical_dish_id, 'Cheese Garlic Bread', 'cheese garlic bread', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese garlic bread'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004132, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004132, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004133, 400086004, cd.canonical_dish_id, 'Nachos With Cheese & Salsa Dip', 'nachos with cheese & salsa dip', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'nachos with cheese & salsa dip'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004133, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004133, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004134, 400086004, cd.canonical_dish_id, 'Stir Fried Exotic Vegetables', 'stir fried exotic vegetables', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'stir fried exotic vegetables'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004134, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004134, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004135, 400086004, cd.canonical_dish_id, 'Bruschetta', 'bruschetta', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bruschetta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004135, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004135, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004136, 400086004, cd.canonical_dish_id, 'French Fries', 'french fries', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'french fries'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004136, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004136, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004137, 400086004, cd.canonical_dish_id, 'Peri Peri French Fries', 'peri peri french fries', 'CONTINENTAL STARTERS', 400086004016, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peri peri french fries'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004137, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004137, 400086004, 400086004001, menu_item_id, 400086004016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004138, 400086004, cd.canonical_dish_id, 'Grill Chipotle Paneer', 'grill chipotle paneer', 'CHEF SPL CONTINENTAL STARTERS', 400086004017, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'grill chipotle paneer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004138, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004138, 400086004, 400086004001, menu_item_id, 400086004017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004139, 400086004, cd.canonical_dish_id, 'Malaysian Paneer', 'malaysian paneer', 'CHEF SPL CONTINENTAL STARTERS', 400086004017, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malaysian paneer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004139, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004139, 400086004, 400086004001, menu_item_id, 400086004017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CONTINENTAL STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004140, 400086004, cd.canonical_dish_id, 'Cheese Volcano Balls', 'cheese volcano balls', 'CHEF SPL CONTINENTAL STARTERS', 400086004017, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese volcano balls'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004140, variant_id, 410, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004140, 400086004, 400086004001, menu_item_id, 400086004017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004141, 400086004, cd.canonical_dish_id, 'Hara Bara Kebab', 'hara bara kebab', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hara bara kebab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004141, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004141, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004142, 400086004, cd.canonical_dish_id, 'Vegetable Seekh Kebab', 'vegetable seekh kebab', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable seekh kebab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004142, variant_id, 295, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004142, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004143, 400086004, cd.canonical_dish_id, 'Cheese Chilly Kebab', 'cheese chilly kebab', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chilly kebab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004143, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004143, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004144, 400086004, cd.canonical_dish_id, 'Aloo Angare', 'aloo angare', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'aloo angare'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004144, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004144, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004145, 400086004, cd.canonical_dish_id, 'Paneer Tikka', 'paneer tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004145, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004145, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004146, 400086004, cd.canonical_dish_id, 'Paneer Pahadi Tikka', 'paneer pahadi tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pahadi tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004146, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004146, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004147, 400086004, cd.canonical_dish_id, 'Paneer Kalimiri Tikka', 'paneer kalimiri tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer kalimiri tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004147, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004147, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004148, 400086004, cd.canonical_dish_id, 'Paneer Malai Tikka', 'paneer malai tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer malai tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004148, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004148, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004149, 400086004, cd.canonical_dish_id, 'Paneer Pudina Tikka', 'paneer pudina tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pudina tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004149, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004149, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004149, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004150, 400086004, cd.canonical_dish_id, 'Paneer Lasooni Tikka', 'paneer lasooni tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lasooni tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004150, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004150, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004151, 400086004, cd.canonical_dish_id, 'Paneer Achari Tikka', 'paneer achari tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer achari tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004151, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004151, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004152, 400086004, cd.canonical_dish_id, 'Tandoori Malai Broccoli', 'tandoori malai broccoli', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori malai broccoli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004152, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004152, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004153, 400086004, cd.canonical_dish_id, 'Mushroom Achari Tikka', 'mushroom achari tikka', 'INDIAN TANDOOR', 400086004018, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom achari tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004153, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004153, 400086004, 400086004001, menu_item_id, 400086004018 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004154, 400086004, cd.canonical_dish_id, 'Paneer Makhmali Roll', 'paneer makhmali roll', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer makhmali roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004154, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004154, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004155, 400086004, cd.canonical_dish_id, 'Paneer Ghee Roast Tikka', 'paneer ghee roast tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer ghee roast tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004155, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004155, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004156, 400086004, cd.canonical_dish_id, 'Paneer Hadippa Tikka', 'paneer hadippa tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hadippa tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004156, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004156, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004157, 400086004, cd.canonical_dish_id, 'Bharwan Aloo', 'bharwan aloo', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bharwan aloo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004157, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004157, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004158, 400086004, cd.canonical_dish_id, 'Kasthuri Paneer Tikka', 'kasthuri paneer tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kasthuri paneer tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004158, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004158, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004159, 400086004, cd.canonical_dish_id, 'Paneer Peri-Peri Tikka', 'paneer peri-peri tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer peri-peri tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004159, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004159, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004160, 400086004, cd.canonical_dish_id, 'Soya Chaap Tikka', 'soya chaap tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'soya chaap tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004160, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004160, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004161, 400086004, cd.canonical_dish_id, 'Khaas Seekh Kebab', 'khaas seekh kebab', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'khaas seekh kebab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004161, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004161, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004162, 400086004, cd.canonical_dish_id, 'Paneer Angara Tikka', 'paneer angara tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer angara tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004162, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004162, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004163, 400086004, cd.canonical_dish_id, 'Basil Garlic Paneer Tikka', 'basil garlic paneer tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'basil garlic paneer tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004163, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004163, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN TANDOOR" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004164, 400086004, cd.canonical_dish_id, 'Paneer Hilltop Tikka', 'paneer hilltop tikka', 'CHEF SPL INDIAN TANDOOR', 400086004019, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hilltop tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004164, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004164, 400086004, 400086004001, menu_item_id, 400086004019 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004165, 400086004, cd.canonical_dish_id, 'Vegetable Manchurian Dry', 'vegetable manchurian dry', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable manchurian dry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004165, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004165, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004166, 400086004, cd.canonical_dish_id, 'Vegetable Schezwan Dry', 'vegetable schezwan dry', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable schezwan dry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004166, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004166, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004167, 400086004, cd.canonical_dish_id, 'Vegetable 65', 'vegetable 65', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable 65'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004167, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004167, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004168, 400086004, cd.canonical_dish_id, 'Vegetable Balls Hot Garlic Dry', 'vegetable balls hot garlic dry', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable balls hot garlic dry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004168, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004168, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004169, 400086004, cd.canonical_dish_id, 'Crispy Vegetable', 'crispy vegetable', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'crispy vegetable'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004169, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004169, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004170, 400086004, cd.canonical_dish_id, 'Spring Roll', 'spring roll', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'spring roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004170, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004170, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004171, 400086004, cd.canonical_dish_id, 'Mushroom Burnt Garlic', 'mushroom burnt garlic', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom burnt garlic'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004171, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004171, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004172, 400086004, cd.canonical_dish_id, 'Paneer Chilly Dry', 'paneer chilly dry', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer chilly dry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004172, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004172, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004173, 400086004, cd.canonical_dish_id, 'Paneer Black Pepper', 'paneer black pepper', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer black pepper'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004173, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004173, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004174, 400086004, cd.canonical_dish_id, 'Paneer Schezwan Dry', 'paneer schezwan dry', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer schezwan dry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004174, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004174, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004175, 400086004, cd.canonical_dish_id, 'Paneer 65', 'paneer 65', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004175, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004175, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004176, 400086004, cd.canonical_dish_id, 'Crispy Paneer', 'crispy paneer', 'CHINESE STARTERS', 400086004020, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'crispy paneer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004176, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004176, 400086004, 400086004001, menu_item_id, 400086004020 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004177, 400086004, cd.canonical_dish_id, 'Kungpao Potato', 'kungpao potato', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kungpao potato'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004177, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004177, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004178, 400086004, cd.canonical_dish_id, 'Mushroom Hot Basil', 'mushroom hot basil', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom hot basil'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004178, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004178, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004179, 400086004, cd.canonical_dish_id, 'Paneer Thai Chilly', 'paneer thai chilly', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer thai chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004179, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004179, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004179, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004180, 400086004, cd.canonical_dish_id, 'Paneer Hot Pan', 'paneer hot pan', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hot pan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004180, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004180, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004181, 400086004, cd.canonical_dish_id, 'Paneer Burnt Garlic', 'paneer burnt garlic', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer burnt garlic'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004181, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004181, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004182, 400086004, cd.canonical_dish_id, 'Paneer Black Bean', 'paneer black bean', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer black bean'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004182, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004182, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004183, 400086004, cd.canonical_dish_id, 'Paneer Hot Basil', 'paneer hot basil', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hot basil'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004183, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004183, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004184, 400086004, cd.canonical_dish_id, 'Paneer Shanghai', 'paneer shanghai', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer shanghai'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004184, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004184, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004185, 400086004, cd.canonical_dish_id, 'Chilly Garlic Patrani Dry', 'chilly garlic patrani dry', 'CHEF SPL CHINESE STARTERS', 400086004021, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilly garlic patrani dry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004185, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004185, 400086004, 400086004001, menu_item_id, 400086004021 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004186, 400086004, cd.canonical_dish_id, 'Vegetable Korma', 'vegetable korma', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable korma'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004186, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004186, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004187, 400086004, cd.canonical_dish_id, 'Vegetable Kadai/ Handi', 'vegetable kadai/ handi', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable kadai/ handi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004187, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004187, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004188, 400086004, cd.canonical_dish_id, 'Vegetable Makhanwala', 'vegetable makhanwala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable makhanwala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004188, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004188, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004189, 400086004, cd.canonical_dish_id, 'Tawa Vegetable', 'tawa vegetable', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tawa vegetable'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004189, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004189, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004190, 400086004, cd.canonical_dish_id, 'Baby Corn Mushroom Masala', 'baby corn mushroom masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baby corn mushroom masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004190, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004190, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004191, 400086004, cd.canonical_dish_id, 'Vegetable Maharaja', 'vegetable maharaja', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable maharaja'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004191, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004191, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004192, 400086004, cd.canonical_dish_id, 'Vegetable Chilly Milli', 'vegetable chilly milli', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable chilly milli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004192, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004192, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004193, 400086004, cd.canonical_dish_id, 'Vegetable Seekh Kebab Masala', 'vegetable seekh kebab masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable seekh kebab masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004193, variant_id, 285, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004193, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004194, 400086004, cd.canonical_dish_id, 'Vegetable Lohori Kofta', 'vegetable lohori kofta', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable lohori kofta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004194, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004194, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004195, 400086004, cd.canonical_dish_id, 'Vegetable Makhmali', 'vegetable makhmali', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable makhmali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004195, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004195, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004196, 400086004, cd.canonical_dish_id, 'Mushroom Methi Mutter', 'mushroom methi mutter', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom methi mutter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004196, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004196, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004197, 400086004, cd.canonical_dish_id, 'Vegetable Kofta', 'vegetable kofta', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable kofta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004197, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004197, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004198, 400086004, cd.canonical_dish_id, 'Chole Bhature', 'chole bhature', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chole bhature'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004198, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004198, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004199, 400086004, cd.canonical_dish_id, 'Kadai Paneer', 'kadai paneer', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kadai paneer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004199, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004199, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004200, 400086004, cd.canonical_dish_id, 'Paneer Makai', 'paneer makai', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer makai'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004200, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004200, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004201, 400086004, cd.canonical_dish_id, 'Mushroom Tawa', 'mushroom tawa', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom tawa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004201, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004201, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004202, 400086004, cd.canonical_dish_id, 'Vegetable Bhuna Ball Masala', 'vegetable bhuna ball masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable bhuna ball masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004202, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004202, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004203, 400086004, cd.canonical_dish_id, 'Kaju Curry / Masala', 'kaju curry / masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kaju curry / masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004203, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004203, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004204, 400086004, cd.canonical_dish_id, 'Kaju Paneer Masala', 'kaju paneer masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kaju paneer masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004204, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004204, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004205, 400086004, cd.canonical_dish_id, 'Paneer Methi Chaman', 'paneer methi chaman', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer methi chaman'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004205, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004205, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004206, 400086004, cd.canonical_dish_id, 'Paneer Tikka Masala', 'paneer tikka masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004206, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004206, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004207, 400086004, cd.canonical_dish_id, 'Paneer Tawa', 'paneer tawa', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tawa'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004207, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004207, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004208, 400086004, cd.canonical_dish_id, 'Palak Paneer', 'palak paneer', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'palak paneer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004208, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004208, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004209, 400086004, cd.canonical_dish_id, 'Paneer Lohori', 'paneer lohori', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lohori'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004209, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004209, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004210, 400086004, cd.canonical_dish_id, 'Paneer Butter Masala', 'paneer butter masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer butter masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004210, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004210, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004211, 400086004, cd.canonical_dish_id, 'Paneer Kolhapuri', 'paneer kolhapuri', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer kolhapuri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004211, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004211, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004212, 400086004, cd.canonical_dish_id, 'Paneer Peshawari', 'paneer peshawari', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer peshawari'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004212, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004212, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004213, 400086004, cd.canonical_dish_id, 'Malai Methi Mutter', 'malai methi mutter', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai methi mutter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004213, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004213, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004214, 400086004, cd.canonical_dish_id, 'Navratan Korma', 'navratan korma', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'navratan korma'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004214, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004214, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004215, 400086004, cd.canonical_dish_id, 'Malai Kofta', 'malai kofta', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai kofta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004215, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004215, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004216, 400086004, cd.canonical_dish_id, 'Vegetable Chop Masala', 'vegetable chop masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable chop masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004216, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004216, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004217, 400086004, cd.canonical_dish_id, 'Vegetable Koliwada Masala', 'vegetable koliwada masala', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable koliwada masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004217, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004217, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004218, 400086004, cd.canonical_dish_id, 'Vegetable Hydrabadi', 'vegetable hydrabadi', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable hydrabadi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004218, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004218, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004219, 400086004, cd.canonical_dish_id, 'Dum Aloo Punjabi', 'dum aloo punjabi', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dum aloo punjabi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004219, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004219, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004220, 400086004, cd.canonical_dish_id, 'Bhindi Dahiwali', 'bhindi dahiwali', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bhindi dahiwali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004220, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004220, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004221, 400086004, cd.canonical_dish_id, 'Chole Delhiwale', 'chole delhiwale', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chole delhiwale'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004221, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004221, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004222, 400086004, cd.canonical_dish_id, 'Paneer Cheese Kofta', 'paneer cheese kofta', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer cheese kofta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004222, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004222, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004223, 400086004, cd.canonical_dish_id, 'Alu Gobi Hariyali', 'alu gobi hariyali', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'alu gobi hariyali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004223, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004223, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004224, 400086004, cd.canonical_dish_id, 'Vegetable Diwani Handi', 'vegetable diwani handi', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable diwani handi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004224, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004224, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004225, 400086004, cd.canonical_dish_id, 'Malwani Aloo', 'malwani aloo', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malwani aloo'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004225, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004225, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004226, 400086004, cd.canonical_dish_id, 'Lasooni Paneer', 'lasooni paneer', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lasooni paneer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004226, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004226, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004227, 400086004, cd.canonical_dish_id, 'Lasooni Palak', 'lasooni palak', 'MAIN COURSE', 400086004022, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lasooni palak'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004227, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004227, 400086004, 400086004001, menu_item_id, 400086004022 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004228, 400086004, cd.canonical_dish_id, 'Vilayati Sabzi', 'vilayati sabzi', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vilayati sabzi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004228, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004228, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004229, 400086004, cd.canonical_dish_id, 'Multani Paneer Tikka Masala', 'multani paneer tikka masala', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'multani paneer tikka masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004229, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004229, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004230, 400086004, cd.canonical_dish_id, 'Paneer Char Minar', 'paneer char minar', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer char minar'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004230, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004230, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004231, 400086004, cd.canonical_dish_id, 'Broccoli Kofta Hariyali', 'broccoli kofta hariyali', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'broccoli kofta hariyali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004231, variant_id, 355, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004231, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004232, 400086004, cd.canonical_dish_id, 'Vegetable Kofta Karishma', 'vegetable kofta karishma', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable kofta karishma'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004232, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004232, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004233, 400086004, cd.canonical_dish_id, 'Zafrani Paneer Tikka Lazeez', 'zafrani paneer tikka lazeez', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'zafrani paneer tikka lazeez'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004233, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004233, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004234, 400086004, cd.canonical_dish_id, 'Paneer Khurchan', 'paneer khurchan', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer khurchan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004234, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004234, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004235, 400086004, cd.canonical_dish_id, 'Paneer Dhuladi', 'paneer dhuladi', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer dhuladi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004235, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004235, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004236, 400086004, cd.canonical_dish_id, 'Vegetable Haveli', 'vegetable haveli', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable haveli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004236, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004236, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004237, 400086004, cd.canonical_dish_id, 'Cheese Chilly Kebab Masala', 'cheese chilly kebab masala', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chilly kebab masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004237, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004237, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004238, 400086004, cd.canonical_dish_id, 'Paneer Lababdar', 'paneer lababdar', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lababdar'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004238, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004238, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004239, 400086004, cd.canonical_dish_id, 'Paneer Koliwada Masala', 'paneer koliwada masala', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer koliwada masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004239, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004239, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004240, 400086004, cd.canonical_dish_id, 'Anglo Indian Bahar', 'anglo indian bahar', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'anglo indian bahar'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004240, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004240, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004241, 400086004, cd.canonical_dish_id, 'Paneer Lajawab', 'paneer lajawab', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lajawab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004241, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004241, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004242, 400086004, cd.canonical_dish_id, 'Soya Chaap Tikka Masala', 'soya chaap tikka masala', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'soya chaap tikka masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004242, variant_id, 385, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004242, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004243, 400086004, cd.canonical_dish_id, 'Veg Rajdhani', 'veg rajdhani', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg rajdhani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004243, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004243, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL INDIAN MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004244, 400086004, cd.canonical_dish_id, 'Sabzi Uttaranchali', 'sabzi uttaranchali', 'CHEF SPL INDIAN MAIN COURSE', 400086004023, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sabzi uttaranchali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004244, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004244, 400086004, 400086004001, menu_item_id, 400086004023 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004245, 400086004, cd.canonical_dish_id, 'Tandoori Roti', 'tandoori roti', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori roti'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004245, variant_id, 45, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004245, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004246, 400086004, cd.canonical_dish_id, 'Butter Roti', 'butter roti', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004246, variant_id, 65, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004246, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004247, 400086004, cd.canonical_dish_id, 'Lachewala Paratha', 'lachewala paratha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lachewala paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004247, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004247, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004248, 400086004, cd.canonical_dish_id, 'Butter Lachewala Paratha', 'butter lachewala paratha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter lachewala paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004248, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004248, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004249, 400086004, cd.canonical_dish_id, 'Kulcha', 'kulcha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kulcha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004249, variant_id, 80, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004249, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004250, 400086004, cd.canonical_dish_id, 'Butter Kulcha', 'butter kulcha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter kulcha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004250, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004250, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004251, 400086004, cd.canonical_dish_id, 'Naan', 'naan', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004251, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004251, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004252, 400086004, cd.canonical_dish_id, 'Butter Naan', 'butter naan', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004252, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004252, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004252, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004253, 400086004, cd.canonical_dish_id, 'Butter Garlic Naan', 'butter garlic naan', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter garlic naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004253, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004253, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004253, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004254, 400086004, cd.canonical_dish_id, 'Butter Cheese Naan', 'butter cheese naan', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter cheese naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004254, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004254, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004255, 400086004, cd.canonical_dish_id, 'Butter Cheese Garlic Naan', 'butter cheese garlic naan', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter cheese garlic naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004255, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004255, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004256, 400086004, cd.canonical_dish_id, 'Butter Aloo Paratha', 'butter aloo paratha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter aloo paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004256, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004256, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004257, 400086004, cd.canonical_dish_id, 'Butter Stuffed Paratha', 'butter stuffed paratha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter stuffed paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004257, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004257, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004258, 400086004, cd.canonical_dish_id, 'Butter Onion Kulcha', 'butter onion kulcha', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter onion kulcha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004258, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004258, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004258, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004259, 400086004, cd.canonical_dish_id, 'Butter With Breads Extra', 'butter with breads extra', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter with breads extra'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004259, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004259, variant_id, 20, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004259, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "INDIAN BREADS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004260, 400086004, cd.canonical_dish_id, 'Cheese With Breads Extra', 'cheese with breads extra', 'INDIAN BREADS', 400086004024, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese with breads extra'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004260, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004260, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004260, 400086004, 400086004001, menu_item_id, 400086004024 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DAL" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004261, 400086004, cd.canonical_dish_id, 'Dal Fry', 'dal fry', 'DAL', 400086004025, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004261, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004261, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004261, 400086004, 400086004001, menu_item_id, 400086004025 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DAL" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004262, 400086004, cd.canonical_dish_id, 'Dal Tadka', 'dal tadka', 'DAL', 400086004025, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004262, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004262, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004262, 400086004, 400086004001, menu_item_id, 400086004025 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DAL" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004263, 400086004, cd.canonical_dish_id, 'Dal Kolhapuri', 'dal kolhapuri', 'DAL', 400086004025, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal kolhapuri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004263, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004263, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004263, 400086004, 400086004001, menu_item_id, 400086004025 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DAL" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004264, 400086004, cd.canonical_dish_id, 'Dal Palak', 'dal palak', 'DAL', 400086004025, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal palak'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004264, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004264, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004264, 400086004, 400086004001, menu_item_id, 400086004025 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DAL" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004265, 400086004, cd.canonical_dish_id, 'Dal Makhani', 'dal makhani', 'DAL', 400086004025, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal makhani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004265, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004265, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004265, 400086004, 400086004001, menu_item_id, 400086004025 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004266, 400086004, cd.canonical_dish_id, 'Steam Rice', 'steam rice', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'steam rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004266, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004266, variant_id, 185, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004266, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004267, 400086004, cd.canonical_dish_id, 'Jeera Rice', 'jeera rice', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004267, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004267, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004267, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004268, 400086004, cd.canonical_dish_id, 'Dal Khichdi', 'dal khichdi', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004268, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004268, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004268, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004269, 400086004, cd.canonical_dish_id, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal khichdi tadka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004269, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004269, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004269, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004270, 400086004, cd.canonical_dish_id, 'Palak Khichdi', 'palak khichdi', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'palak khichdi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004270, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004270, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004270, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004271, 400086004, cd.canonical_dish_id, 'Curd Rice', 'curd rice', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'curd rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004271, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004271, variant_id, 215, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004271, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004272, 400086004, cd.canonical_dish_id, 'Vegetable Pulao', 'vegetable pulao', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004272, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004272, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004272, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004273, 400086004, cd.canonical_dish_id, 'Kashmiri Pulao', 'kashmiri pulao', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kashmiri pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004273, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004273, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004273, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004274, 400086004, cd.canonical_dish_id, 'Corn Pulao', 'corn pulao', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'corn pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004274, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004274, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004274, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004275, 400086004, cd.canonical_dish_id, 'Cheese Pulao', 'cheese pulao', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004275, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004275, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004275, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004276, 400086004, cd.canonical_dish_id, 'Paneer Pulao', 'paneer pulao', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004276, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004276, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004276, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004277, 400086004, cd.canonical_dish_id, 'Vegetable Biryani', 'vegetable biryani', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004277, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004277, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004277, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004278, 400086004, cd.canonical_dish_id, 'Vegetable Hydrabadi Biryani', 'vegetable hydrabadi biryani', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable hydrabadi biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004278, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004278, variant_id, 305, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004278, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004279, 400086004, cd.canonical_dish_id, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004279, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004279, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004279, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004280, 400086004, cd.canonical_dish_id, 'Mushroom Tikka Biryani', 'mushroom tikka biryani', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom tikka biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004280, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004280, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004280, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004281, 400086004, cd.canonical_dish_id, 'Vegetable & Paneer Handi Biryani', 'vegetable & paneer handi biryani', 'RICE', 400086004026, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable & paneer handi biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004281, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004281, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004281, 400086004, 400086004001, menu_item_id, 400086004026 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004282, 400086004, cd.canonical_dish_id, 'Green Salad', 'green salad', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004282, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004282, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004282, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004283, 400086004, cd.canonical_dish_id, 'Raita (Vegetable/ Boondi/Pineapple/Mint)', 'raita (vegetable/ boondi/pineapple/mint)', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'raita (vegetable/ boondi/pineapple/mint)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004283, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004283, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004283, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004284, 400086004, cd.canonical_dish_id, 'Fruit & Dry Fruit Raita', 'fruit & dry fruit raita', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fruit & dry fruit raita'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004284, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004284, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004284, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004285, 400086004, cd.canonical_dish_id, 'Plain Curd', 'plain curd', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain curd'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004285, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004285, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004285, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004286, 400086004, cd.canonical_dish_id, 'Roasted/ Fried Papad', 'roasted/ fried papad', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'roasted/ fried papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004286, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004286, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004286, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004287, 400086004, cd.canonical_dish_id, 'Masala Papad', 'masala papad', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004287, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004287, variant_id, 60, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004287, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004288, 400086004, cd.canonical_dish_id, 'Masala Khichiya Papad', 'masala khichiya papad', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala khichiya papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004288, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004288, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004288, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004289, 400086004, cd.canonical_dish_id, 'Khichiya Masala Papad With Cheese', 'khichiya masala papad with cheese', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'khichiya masala papad with cheese'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004289, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004289, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004289, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "SALAD, RAITA & PAPAD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004290, 400086004, cd.canonical_dish_id, 'Cheese Grilled Papad', 'cheese grilled papad', 'SALAD, RAITA & PAPAD', 400086004027, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese grilled papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004290, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004290, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004290, 400086004, 400086004001, menu_item_id, 400086004027 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004291, 400086004, cd.canonical_dish_id, 'Vegetable In Manchurian Gravy', 'vegetable in manchurian gravy', 'CHINESE MAIN COURSE', 400086004028, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable in manchurian gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004291, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004291, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004291, 400086004, 400086004001, menu_item_id, 400086004028 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004292, 400086004, cd.canonical_dish_id, 'Vegetable In Hot Garlic Gravy', 'vegetable in hot garlic gravy', 'CHINESE MAIN COURSE', 400086004028, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable in hot garlic gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004292, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004292, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004292, 400086004, 400086004001, menu_item_id, 400086004028 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004293, 400086004, cd.canonical_dish_id, 'Paneer In Hot Garlic Gravy', 'paneer in hot garlic gravy', 'CHINESE MAIN COURSE', 400086004028, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer in hot garlic gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004293, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004293, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004293, 400086004, 400086004001, menu_item_id, 400086004028 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004294, 400086004, cd.canonical_dish_id, 'Paneer In Manchurian Gravy', 'paneer in manchurian gravy', 'CHINESE MAIN COURSE', 400086004028, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer in manchurian gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004294, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004294, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004294, 400086004, 400086004001, menu_item_id, 400086004028 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004295, 400086004, cd.canonical_dish_id, 'Paneer In Schezwan Gravy', 'paneer in schezwan gravy', 'CHINESE MAIN COURSE', 400086004028, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer in schezwan gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004295, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004295, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004295, 400086004, 400086004001, menu_item_id, 400086004028 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004296, 400086004, cd.canonical_dish_id, 'Mushroom In Manchurian Gravy', 'mushroom in manchurian gravy', 'CHINESE MAIN COURSE', 400086004028, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom in manchurian gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004296, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004296, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004296, 400086004, 400086004001, menu_item_id, 400086004028 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004297, 400086004, cd.canonical_dish_id, 'Vegetable In Black Bean Gravy', 'vegetable in black bean gravy', 'CHEF SPL CHINESE MAIN COURSE', 400086004029, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable in black bean gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004297, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004297, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004297, 400086004, 400086004001, menu_item_id, 400086004029 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004298, 400086004, cd.canonical_dish_id, 'Mushroom In Hotpan Gravy', 'mushroom in hotpan gravy', 'CHEF SPL CHINESE MAIN COURSE', 400086004029, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom in hotpan gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004298, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004298, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004298, 400086004, 400086004001, menu_item_id, 400086004029 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004299, 400086004, cd.canonical_dish_id, 'Paneer In Oyster Gravy', 'paneer in oyster gravy', 'CHEF SPL CHINESE MAIN COURSE', 400086004029, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer in oyster gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004299, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004299, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004299, 400086004, 400086004001, menu_item_id, 400086004029 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHEF SPL CHINESE MAIN COURSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004300, 400086004, cd.canonical_dish_id, 'Paneer In Hot Basil Gravy', 'paneer in hot basil gravy', 'CHEF SPL CHINESE MAIN COURSE', 400086004029, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer in hot basil gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004300, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004300, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004300, 400086004, 400086004001, menu_item_id, 400086004029 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004301, 400086004, cd.canonical_dish_id, 'Vegetable Fried Rice', 'vegetable fried rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004301, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004301, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004301, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004302, 400086004, cd.canonical_dish_id, 'Vegetable Schezwan Fried Rice', 'vegetable schezwan fried rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable schezwan fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004302, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004302, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004302, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004303, 400086004, cd.canonical_dish_id, 'Hong Kong Fried Rice', 'hong kong fried rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hong kong fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004303, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004303, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004303, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004304, 400086004, cd.canonical_dish_id, 'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'burnt garlic fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004304, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004304, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004304, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004305, 400086004, cd.canonical_dish_id, 'Vegetable Triple Schezwan Rice', 'vegetable triple schezwan rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable triple schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004305, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004305, variant_id, 360, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004305, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004306, 400086004, cd.canonical_dish_id, 'Vegetable Combination Rice', 'vegetable combination rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable combination rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004306, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004306, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004306, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004307, 400086004, cd.canonical_dish_id, 'Exotic Pot Rice', 'exotic pot rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'exotic pot rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004307, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004307, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004307, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004308, 400086004, cd.canonical_dish_id, 'Thai Curry With Steam Rice', 'thai curry with steam rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'thai curry with steam rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004308, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004308, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004308, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004309, 400086004, cd.canonical_dish_id, 'Vegetable Hakka Noodles', 'vegetable hakka noodles', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable hakka noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004309, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004309, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004309, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004310, 400086004, cd.canonical_dish_id, 'Vegetable Schezwan Hakka Noodles', 'vegetable schezwan hakka noodles', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable schezwan hakka noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004310, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004310, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004310, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004311, 400086004, cd.canonical_dish_id, 'American Choupsey', 'american choupsey', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'american choupsey'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004311, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004311, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004311, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004312, 400086004, cd.canonical_dish_id, 'Chinese Choupsey', 'chinese choupsey', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chinese choupsey'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004312, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004312, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004312, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004313, 400086004, cd.canonical_dish_id, 'Chilli Garlic Noodles', 'chilli garlic noodles', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilli garlic noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004313, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004313, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004313, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004314, 400086004, cd.canonical_dish_id, 'Vegetable Singapore Noodles', 'vegetable singapore noodles', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable singapore noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004314, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004314, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004314, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE & NOODLES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004315, 400086004, cd.canonical_dish_id, 'Vegetable Malaysian Pot Rice', 'vegetable malaysian pot rice', 'RICE & NOODLES', 400086004030, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'vegetable malaysian pot rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004315, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004315, variant_id, 390, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004315, 400086004, 400086004001, menu_item_id, 400086004030 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004316, 400086004, cd.canonical_dish_id, 'Mosambi', 'mosambi', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mosambi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004316, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004316, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004316, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004317, 400086004, cd.canonical_dish_id, 'Orange', 'orange', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'orange'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004317, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004317, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004317, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004318, 400086004, cd.canonical_dish_id, 'Ganga Jamuna', 'ganga jamuna', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ganga jamuna'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004318, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004318, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004318, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004319, 400086004, cd.canonical_dish_id, 'Mara Mari', 'mara mari', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mara mari'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004319, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004319, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004319, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004320, 400086004, cd.canonical_dish_id, 'Ganga Jamuna Saraswati', 'ganga jamuna saraswati', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ganga jamuna saraswati'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004320, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004320, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004320, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004321, 400086004, cd.canonical_dish_id, 'Pineapple', 'pineapple', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pineapple'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004321, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004321, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004321, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004322, 400086004, cd.canonical_dish_id, 'Apple', 'apple', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'apple'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004322, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004322, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004322, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004323, 400086004, cd.canonical_dish_id, 'Grapes', 'grapes', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'grapes'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004323, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004323, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004323, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004324, 400086004, cd.canonical_dish_id, 'Water Melon', 'water melon', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'water melon'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004324, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004324, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004324, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004325, 400086004, cd.canonical_dish_id, 'Anar', 'anar', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'anar'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004325, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004325, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004325, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004326, 400086004, cd.canonical_dish_id, 'Fresh Lime Juice', 'fresh lime juice', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fresh lime juice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004326, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004326, variant_id, 80, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004326, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004327, 400086004, cd.canonical_dish_id, 'Fresh Lime Soda', 'fresh lime soda', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fresh lime soda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004327, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004327, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004327, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "JUICES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004328, 400086004, cd.canonical_dish_id, 'Ginger Lemon Soda', 'ginger lemon soda', 'JUICES', 400086004031, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ginger lemon soda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004328, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004328, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004328, 400086004, 400086004001, menu_item_id, 400086004031 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004329, 400086004, cd.canonical_dish_id, 'Watermelon Blossom', 'watermelon blossom', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'watermelon blossom'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004329, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004329, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004329, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004330, 400086004, cd.canonical_dish_id, 'Pineapple Blossom', 'pineapple blossom', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pineapple blossom'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004330, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004330, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004330, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004331, 400086004, cd.canonical_dish_id, 'Orange Blossom', 'orange blossom', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'orange blossom'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004331, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004331, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004331, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004332, 400086004, cd.canonical_dish_id, 'Cocktail', 'cocktail', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cocktail'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004332, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004332, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004332, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004333, 400086004, cd.canonical_dish_id, 'Black Currant', 'black currant', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'black currant'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004333, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004333, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004333, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004334, 400086004, cd.canonical_dish_id, 'Special Grape', 'special grape', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'special grape'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004334, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004334, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004334, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BLOSSOMS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004335, 400086004, cd.canonical_dish_id, 'Thandai Milk Shake', 'thandai milk shake', 'BLOSSOMS', 400086004032, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'thandai milk shake'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004335, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004335, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004335, 400086004, 400086004001, menu_item_id, 400086004032 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004336, 400086004, cd.canonical_dish_id, 'Mint Mojito', 'mint mojito', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mint mojito'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004336, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004336, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004336, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004337, 400086004, cd.canonical_dish_id, 'Blue Heaven', 'blue heaven', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'blue heaven'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004337, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004337, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004337, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004338, 400086004, cd.canonical_dish_id, 'Mango Delight', 'mango delight', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mango delight'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004338, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004338, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004338, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004339, 400086004, cd.canonical_dish_id, 'Kiwi Mojito', 'kiwi mojito', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kiwi mojito'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004339, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004339, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004339, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004340, 400086004, cd.canonical_dish_id, 'Litchi Grasshopper', 'litchi grasshopper', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'litchi grasshopper'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004340, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004340, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004340, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004341, 400086004, cd.canonical_dish_id, 'Kiwi High', 'kiwi high', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kiwi high'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004341, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004341, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004341, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004342, 400086004, cd.canonical_dish_id, 'Golden Glow', 'golden glow', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'golden glow'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004342, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004342, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004342, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004343, 400086004, cd.canonical_dish_id, 'Blue Berry', 'blue berry', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'blue berry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004343, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004343, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004343, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004344, 400086004, cd.canonical_dish_id, 'Black Currant', 'black currant', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'black currant'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004344, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004344, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004344, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004345, 400086004, cd.canonical_dish_id, 'Pinacolada', 'pinacolada', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pinacolada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004345, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004345, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004345, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004346, 400086004, cd.canonical_dish_id, 'Fruit Punch', 'fruit punch', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fruit punch'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004346, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004346, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004346, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004347, 400086004, cd.canonical_dish_id, 'Litchi Mojito', 'litchi mojito', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'litchi mojito'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004347, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004347, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004347, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004348, 400086004, cd.canonical_dish_id, 'Lemon Ice Tea', 'lemon ice tea', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lemon ice tea'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004348, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004348, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004348, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MOCKTAILS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004349, 400086004, cd.canonical_dish_id, 'Peach Ice Tea', 'peach ice tea', 'MOCKTAILS', 400086004033, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'peach ice tea'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004349, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004349, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004349, 400086004, 400086004001, menu_item_id, 400086004033 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004350, 400086004, cd.canonical_dish_id, 'Chikku', 'chikku', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chikku'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004350, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004350, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004350, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004351, 400086004, cd.canonical_dish_id, 'Chikku Chocolate', 'chikku chocolate', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chikku chocolate'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004351, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004351, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004351, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004352, 400086004, cd.canonical_dish_id, 'Apple', 'apple', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'apple'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004352, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004352, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004352, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004353, 400086004, cd.canonical_dish_id, 'Chocolate / Vanilla', 'chocolate / vanilla', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chocolate / vanilla'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004353, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004353, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004353, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004354, 400086004, cd.canonical_dish_id, 'Cold Coffee', 'cold coffee', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cold coffee'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004354, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004354, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004354, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004355, 400086004, cd.canonical_dish_id, 'Butterscotch', 'butterscotch', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butterscotch'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004355, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004355, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004355, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004356, 400086004, cd.canonical_dish_id, 'Brownie', 'brownie', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'brownie'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004356, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004356, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004356, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004357, 400086004, cd.canonical_dish_id, 'Oreo / Kitkat', 'oreo / kitkat', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'oreo / kitkat'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004357, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004357, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004357, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004358, 400086004, cd.canonical_dish_id, 'Sitafal / Mango / Strawberry (Seasonal)', 'sitafal / mango / strawberry (seasonal)', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sitafal / mango / strawberry (seasonal)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004358, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004358, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004358, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004359, 400086004, cd.canonical_dish_id, 'Extra Scoops With Ice Cream', 'extra scoops with ice cream', 'MILK SHAKES', 400086004034, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'extra scoops with ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004359, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004359, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004359, 400086004, 400086004001, menu_item_id, 400086004034 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004360, 400086004, cd.canonical_dish_id, 'Chocolate With Nuts', 'chocolate with nuts', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chocolate with nuts'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004360, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004360, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004360, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004361, 400086004, cd.canonical_dish_id, 'Kaju Milk Shake', 'kaju milk shake', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kaju milk shake'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004361, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004361, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004361, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004362, 400086004, cd.canonical_dish_id, 'Date & Kaju', 'date & kaju', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'date & kaju'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004362, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004362, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004362, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004363, 400086004, cd.canonical_dish_id, 'Kaju Anjeer', 'kaju anjeer', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kaju anjeer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004363, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004363, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004363, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004364, 400086004, cd.canonical_dish_id, 'Badam Pista', 'badam pista', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'badam pista'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004364, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004364, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004364, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004365, 400086004, cd.canonical_dish_id, 'Chikku Chocolate With Nuts', 'chikku chocolate with nuts', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chikku chocolate with nuts'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004365, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004365, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004365, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004366, 400086004, cd.canonical_dish_id, 'Anjeer', 'anjeer', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'anjeer'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004366, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004366, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004366, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DRY FRUITS MILK SHAKES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004367, 400086004, cd.canonical_dish_id, 'Dry Fruit Mix', 'dry fruit mix', 'DRY FRUITS MILK SHAKES', 400086004035, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dry fruit mix'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004367, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004367, variant_id, 430, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004367, 400086004, 400086004001, menu_item_id, 400086004035 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004368, 400086004, cd.canonical_dish_id, 'Beverages', 'beverages', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'beverages'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004368, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004368, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004368, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004369, 400086004, cd.canonical_dish_id, 'Butter Milk', 'butter milk', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter milk'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004369, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004369, variant_id, 80, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004369, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004370, 400086004, cd.canonical_dish_id, 'Sweet Lassi', 'sweet lassi', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sweet lassi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004370, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004370, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004370, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004371, 400086004, cd.canonical_dish_id, 'Kesar Lassi', 'kesar lassi', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kesar lassi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004371, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004371, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004371, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004372, 400086004, cd.canonical_dish_id, 'Strawberry Lassi', 'strawberry lassi', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'strawberry lassi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004372, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004372, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004372, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004373, 400086004, cd.canonical_dish_id, 'Mango Lassi', 'mango lassi', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mango lassi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004373, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004373, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004373, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "COLD BEVERAGES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004374, 400086004, cd.canonical_dish_id, 'Dry Fruit Lassi', 'dry fruit lassi', 'COLD BEVERAGES', 400086004036, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dry fruit lassi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004374, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004374, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004374, 400086004, 400086004001, menu_item_id, 400086004036 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FALOODA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004375, 400086004, cd.canonical_dish_id, 'Royal Falooda', 'royal falooda', 'FALOODA', 400086004037, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'royal falooda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004375, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004375, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004375, 400086004, 400086004001, menu_item_id, 400086004037 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FALOODA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004376, 400086004, cd.canonical_dish_id, 'Kesar Falooda', 'kesar falooda', 'FALOODA', 400086004037, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kesar falooda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004376, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004376, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004376, 400086004, 400086004001, menu_item_id, 400086004037 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FALOODA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004377, 400086004, cd.canonical_dish_id, 'Chocolate Falooda', 'chocolate falooda', 'FALOODA', 400086004037, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chocolate falooda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004377, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004377, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004377, 400086004, 400086004001, menu_item_id, 400086004037 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FALOODA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004378, 400086004, cd.canonical_dish_id, 'Kulfi Falooda', 'kulfi falooda', 'FALOODA', 400086004037, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kulfi falooda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004378, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004378, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004378, 400086004, 400086004001, menu_item_id, 400086004037 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FALOODA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004379, 400086004, cd.canonical_dish_id, 'Special Dry Fruit Falooda', 'special dry fruit falooda', 'FALOODA', 400086004037, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'special dry fruit falooda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004379, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004379, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004379, 400086004, 400086004001, menu_item_id, 400086004037 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004380, 400086004, cd.canonical_dish_id, 'Plain Jelly', 'plain jelly', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain jelly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004380, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004380, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004380, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004381, 400086004, cd.canonical_dish_id, 'Jelly With Ice Cream', 'jelly with ice cream', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jelly with ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004381, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004381, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004381, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004382, 400086004, cd.canonical_dish_id, 'Fruit Salad', 'fruit salad', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fruit salad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004382, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004382, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004382, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004383, 400086004, cd.canonical_dish_id, 'Fruit Salad With Jelly', 'fruit salad with jelly', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fruit salad with jelly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004383, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004383, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004383, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004384, 400086004, cd.canonical_dish_id, 'Fruit Salad With Ice Cream', 'fruit salad with ice cream', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fruit salad with ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004384, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004384, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004384, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004385, 400086004, cd.canonical_dish_id, 'Fruit Salad With Jelly & Ice Cream', 'fruit salad with jelly & ice cream', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fruit salad with jelly & ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004385, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004385, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004385, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004386, 400086004, cd.canonical_dish_id, 'Brownie With Ice Cream', 'brownie with ice cream', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'brownie with ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004386, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004386, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004386, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004387, 400086004, cd.canonical_dish_id, 'Hot Gulab Jamun', 'hot gulab jamun', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hot gulab jamun'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004387, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004387, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004387, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004388, 400086004, cd.canonical_dish_id, 'Gulab Jamun With Vanilla Ice Cream', 'gulab jamun with vanilla ice cream', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'gulab jamun with vanilla ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004388, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004388, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004388, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004389, 400086004, cd.canonical_dish_id, 'Gulab Jamun With Rabdi', 'gulab jamun with rabdi', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'gulab jamun with rabdi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004389, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004389, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004389, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004390, 400086004, cd.canonical_dish_id, 'Rabdi', 'rabdi', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rabdi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004390, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004390, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004390, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004391, 400086004, cd.canonical_dish_id, 'Gadbad Ice Cream', 'gadbad ice cream', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'gadbad ice cream'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004391, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004391, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004391, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004392, 400086004, cd.canonical_dish_id, 'Malai Kulfi', 'malai kulfi', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai kulfi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004392, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004392, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004392, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004393, 400086004, cd.canonical_dish_id, 'Kesar Pista Kulfi', 'kesar pista kulfi', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kesar pista kulfi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004393, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004393, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004393, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004394, 400086004, cd.canonical_dish_id, 'Cool Scoops', 'cool scoops', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cool scoops'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004394, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004394, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004394, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "DESSERTS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, verification_status_code)
  SELECT 400086004395, 400086004, cd.canonical_dish_id, 'Premium Scoops', 'premium scoops', 'DESSERTS', 400086004038, 'veg', 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'premium scoops'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086004395, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086004395, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086004, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086004395, 400086004, 400086004001, menu_item_id, 400086004038 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086004, 400086004500, 0.95, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086004, 400086004500, 0.95 FROM (SELECT price_id FROM np_1) AS ap;

COMMIT;

-- Summary: 1 restaurant, 38 categories, 395 menu items, 393 canonical dishes.