
BEGIN;

DO $do$
DECLARE v_max BIGINT:= 400086003000;
BEGIN
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS rohini_other_id_seq START WITH %s', v_max + 1);
END $do$;

DO $do$
DECLARE v_already_done BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400086003
    AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Rohini_Restaurant_Menu_OCR.json')
    AND status_code = 'completed') INTO v_already_done;
  IF v_already_done THEN RAISE EXCEPTION 'Already loaded for restaurant 400086003.'; END IF;
END $do$;

INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, city, state, country_code, postal_code, latitude, longitude)
VALUES (400086003, 'Rohini Restaurant & Bar', 'rohini restaurant & bar', 'Opp. Railway Station Vidyavihar West, Mumbai - 400 086', 'Vidyavihar (West)', 'Mumbai', 'Maharashtra', 'IN', '400086', 19.080499684519776, 72.89591954609324);

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, has_bar, bar_license_type)
VALUES (400086003, 400086003, 'Rohini Restaurant & Bar', 'rohini restaurant & bar', TRUE, 'full_bar');

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400086003, 'ai_menu_extraction', 'Rohini_Restaurant_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
VALUES (400086003500, 400086003, 400086003, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary, is_personal_number)
VALUES (nextval('rohini_other_id_seq'), 400086003, '9321144792', TRUE, FALSE);

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, currency_code)
VALUES (400086003, TRUE, TRUE, 'INR');

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, notes)
VALUES (400086003, 1, 'Dine-in inferred: sit-down thali/tandoor/bar menu structure'), (400086003, 3, NULL), (400086003, 4, 'Free delivery stated; no named aggregator partner in the JSON');

INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
SELECT nextval('rohini_other_id_seq'), 400086003, dow, 1, '10:30'::time, '23:59:59'::time FROM generate_series(1,7) AS dow;
-- Timing stated as "10:30 am-12:00 am" (i.e. past midnight) -- closes_at stored as 23:59:59
-- rather than '00:00' to avoid implying a zero-length or next-day-ambiguous window; see UNMAPPED.

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code) VALUES (400086003001, 400086003, 'Rohini Restaurant & Bar Menu', 'a_la_carte');

INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence) VALUES
  (400086003001, 400086003, 'Non Veg Dishes', 1),
  (400086003002, 400086003, 'Thali Non Veg / Sea Food', 2),
  (400086003003, 400086003, 'Tawa Fry Sea Food', 3),
  (400086003004, 400086003, 'Kori Roti', 4),
  (400086003005, 400086003, 'Chesse', 5),
  (400086003006, 400086003, 'Tandoor Roti', 6),
  (400086003007, 400086003, 'Tandoori Starters', 7),
  (400086003008, 400086003, 'Rohini Snacks', 8),
  (400086003009, 400086003, 'Veg Dishes', 9),
  (400086003010, 400086003, 'Fish', 10),
  (400086003011, 400086003, 'Rice', 11),
  (400086003012, 400086003, 'Biryani', 12),
  (400086003013, 400086003, 'Egg Dishes', 13),
  (400086003014, 400086003, 'Veg Chinese', 14),
  (400086003015, 400086003, 'Chicken Chinese', 15),
  (400086003016, 400086003, 'Chinese Rice', 16),
  (400086003017, 400086003, 'Raita', 17);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
  (400086003, 400086003001, 400086003001, 1),
  (400086003, 400086003001, 400086003002, 2),
  (400086003, 400086003001, 400086003003, 3),
  (400086003, 400086003001, 400086003004, 4),
  (400086003, 400086003001, 400086003005, 5),
  (400086003, 400086003001, 400086003006, 6),
  (400086003, 400086003001, 400086003007, 7),
  (400086003, 400086003001, 400086003008, 8),
  (400086003, 400086003001, 400086003009, 9),
  (400086003, 400086003001, 400086003010, 10),
  (400086003, 400086003001, 400086003011, 11),
  (400086003, 400086003001, 400086003012, 12),
  (400086003, 400086003001, 400086003013, 13),
  (400086003, 400086003001, 400086003014, 14),
  (400086003, 400086003001, 400086003015, 15),
  (400086003, 400086003001, 400086003016, 16),
  (400086003, 400086003001, 400086003017, 17);

WITH nd_11638704 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Diwani Handi (H)', 'chi diwani handi (h)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi diwani handi (h)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Diwani Handi (H)', 'chi diwani handi (h)', 'primary' FROM nd_11638704;

WITH nd_28837079 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Diwani Handi (F)', 'chi diwani handi (f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi diwani handi (f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Diwani Handi (F)', 'chi diwani handi (f)', 'primary' FROM nd_28837079;

WITH nd_12576738 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Murg Musollam (H)', 'murg musollam (h)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg musollam (h)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Murg Musollam (H)', 'murg musollam (h)', 'primary' FROM nd_12576738;

WITH nd_34914581 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Murg Musollam (F)', 'murg musollam (f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg musollam (f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Murg Musollam (F)', 'murg musollam (f)', 'primary' FROM nd_34914581;

WITH nd_55792384 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Do Pyaza', 'chicken do pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken do pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Do Pyaza', 'chicken do pyaza', 'primary' FROM nd_55792384;

WITH nd_23127155 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Potiyala', 'chi potiyala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi potiyala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Potiyala', 'chi potiyala', 'primary' FROM nd_23127155;

WITH nd_32315068 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Diwani Handi', 'mutton diwani handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton diwani handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Diwani Handi', 'mutton diwani handi', 'primary' FROM nd_32315068;

WITH nd_44334980 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Rogan Josh', 'mutton rogan josh'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rogan josh')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Rogan Josh', 'mutton rogan josh', 'primary' FROM nd_44334980;

WITH nd_83022475 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Do Pyaza', 'mutton do pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton do pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Do Pyaza', 'mutton do pyaza', 'primary' FROM nd_83022475;

WITH nd_37425049 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Haryali', 'mutton haryali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton haryali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Haryali', 'mutton haryali', 'primary' FROM nd_37425049;

WITH nd_9096468 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Sukka Chicken', 'sukka chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sukka chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Sukka Chicken', 'sukka chicken', 'primary' FROM nd_9096468;

WITH nd_4552808 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Sukka Mutton', 'sukka mutton'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sukka mutton')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Sukka Mutton', 'sukka mutton', 'primary' FROM nd_4552808;

WITH nd_23790632 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Masala / Masala Fry', 'chicken masala / masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala / masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Masala / Masala Fry', 'chicken masala / masala fry', 'primary' FROM nd_23790632;

WITH nd_61218505 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Masala Boneless', 'chicken masala boneless'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala boneless')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Masala Boneless', 'chicken masala boneless', 'primary' FROM nd_61218505;

WITH nd_85931286 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Kolhapuri', 'chicken kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kolhapuri', 'chicken kolhapuri', 'primary' FROM nd_85931286;

WITH nd_50926558 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Handi (Full)', 'chicken handi (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Handi (Full)', 'chicken handi (full)', 'primary' FROM nd_50926558;

WITH nd_47352951 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Handi (Half)', 'chicken handi (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Handi (Half)', 'chicken handi (half)', 'primary' FROM nd_47352951;

WITH nd_82996961 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Tikka Masala', 'chicken tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Masala', 'chicken tikka masala', 'primary' FROM nd_82996961;

WITH nd_1281972 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Butter Chicken (Full)', 'butter chicken (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Butter Chicken (Full)', 'butter chicken (full)', 'primary' FROM nd_1281972;

WITH nd_29171351 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Butter Chicken (Half)', 'butter chicken (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Butter Chicken (Half)', 'butter chicken (half)', 'primary' FROM nd_29171351;

WITH nd_2759410 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Masala', 'mutton masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Masala', 'mutton masala', 'primary' FROM nd_2759410;

WITH nd_11526136 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Kolhapuri', 'mutton kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Kolhapuri', 'mutton kolhapuri', 'primary' FROM nd_11526136;

WITH nd_35452033 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Masala Fry', 'mutton masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Masala Fry', 'mutton masala fry', 'primary' FROM nd_35452033;

WITH nd_35511507 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Malvani', 'mutton malvani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton malvani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Malvani', 'mutton malvani', 'primary' FROM nd_35511507;

WITH nd_24353741 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Handi (Full)', 'mutton handi (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Handi (Full)', 'mutton handi (full)', 'primary' FROM nd_24353741;

WITH nd_14515154 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Handi (Half)', 'mutton handi (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Handi (Half)', 'mutton handi (half)', 'primary' FROM nd_14515154;

WITH nd_57421275 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Leg Peas Masala', 'chicken leg peas masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken leg peas masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Leg Peas Masala', 'chicken leg peas masala', 'primary' FROM nd_57421275;

WITH nd_88904858 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Gravy', 'chicken gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Gravy', 'chicken gravy', 'primary' FROM nd_88904858;

WITH nd_13136391 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Kofta (Full)', 'chicken kofta (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kofta (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kofta (Full)', 'chicken kofta (full)', 'primary' FROM nd_13136391;

WITH nd_38281265 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Kofta (Half)', 'chicken kofta (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kofta (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Kofta (Half)', 'chicken kofta (half)', 'primary' FROM nd_38281265;

WITH nd_17931924 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Moghlai', 'chicken moghlai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken moghlai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Moghlai', 'chicken moghlai', 'primary' FROM nd_17931924;

WITH nd_57942557 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Masala / Fry', 'egg masala / fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala / fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Masala / Fry', 'egg masala / fry', 'primary' FROM nd_57942557;

WITH nd_1923073 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Handi Boneless (Full)', 'chicken handi boneless (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi boneless (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Handi Boneless (Full)', 'chicken handi boneless (full)', 'primary' FROM nd_1923073;

WITH nd_77068160 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Handi Boneless (Half)', 'chicken handi boneless (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi boneless (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Handi Boneless (Half)', 'chicken handi boneless (half)', 'primary' FROM nd_77068160;

WITH nd_82152302 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Thali', 'chi thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Thali', 'chi thali', 'primary' FROM nd_82152302;

WITH nd_69557773 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Komdi Wade', 'chi komdi wade'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi komdi wade')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Komdi Wade', 'chi komdi wade', 'primary' FROM nd_69557773;

WITH nd_21398607 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Thali', 'mutton thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Thali', 'mutton thali', 'primary' FROM nd_21398607;

WITH nd_79011878 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Thali', 'egg thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Thali', 'egg thali', 'primary' FROM nd_79011878;

WITH nd_50128526 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Surmai Thali', 'surmai thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Surmai Thali', 'surmai thali', 'primary' FROM nd_50128526;

WITH nd_84671461 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pomfret Thali', 'pomfret thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pomfret Thali', 'pomfret thali', 'primary' FROM nd_84671461;

WITH nd_6505445 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Thali', 'prawns thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Thali', 'prawns thali', 'primary' FROM nd_6505445;

WITH nd_10040397 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bombil Thali', 'bombil thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bombil thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bombil Thali', 'bombil thali', 'primary' FROM nd_10040397;

WITH nd_29729186 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mandeli Thali', 'mandeli thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mandeli thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mandeli Thali', 'mandeli thali', 'primary' FROM nd_29729186;

WITH nd_99275710 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Roavas Thali', 'roavas thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roavas thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Roavas Thali', 'roavas thali', 'primary' FROM nd_99275710;

WITH nd_94240878 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bangda Thali', 'bangda thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bangda Thali', 'bangda thali', 'primary' FROM nd_94240878;

WITH nd_12331712 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fish Fry', 'fish fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fish Fry', 'fish fry', 'primary' FROM nd_12331712;

WITH nd_78576980 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Surmai', 'surmai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Surmai', 'surmai', 'primary' FROM nd_78576980;

WITH nd_38914477 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pomfret', 'pomfret'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pomfret', 'pomfret', 'primary' FROM nd_38914477;

WITH nd_15135953 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns', 'prawns'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns', 'prawns', 'primary' FROM nd_15135953;

WITH nd_89172864 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bombil', 'bombil'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bombil')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bombil', 'bombil', 'primary' FROM nd_89172864;

WITH nd_6185490 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mandeli', 'mandeli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mandeli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mandeli', 'mandeli', 'primary' FROM nd_6185490;

WITH nd_74738325 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Raawas', 'raawas'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raawas')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Raawas', 'raawas', 'primary' FROM nd_74738325;

WITH nd_57329023 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bangda', 'bangda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bangda', 'bangda', 'primary' FROM nd_57329023;

WITH nd_80188880 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fish Fully Manchi', 'fish fully manchi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish fully manchi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fish Fully Manchi', 'fish fully manchi', 'primary' FROM nd_80188880;

WITH nd_66332177 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Kori Roti', 'chi kori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi kori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Kori Roti', 'chi kori roti', 'primary' FROM nd_66332177;

WITH nd_63385210 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chesse Corn Ball', 'chesse corn ball'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chesse corn ball')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chesse Corn Ball', 'chesse corn ball', 'primary' FROM nd_63385210;

WITH nd_9419211 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chesse Corn Tikki', 'chesse corn tikki'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chesse corn tikki')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chesse Corn Tikki', 'chesse corn tikki', 'primary' FROM nd_9419211;

WITH nd_79337129 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Tandoori Roti', 'tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Tandoori Roti', 'tandoori roti', 'primary' FROM nd_79337129;

WITH nd_74318263 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Butter Roti', 'butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Butter Roti', 'butter roti', 'primary' FROM nd_74318263;

WITH nd_79524219 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paratha', 'paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paratha', 'paratha', 'primary' FROM nd_79524219;

WITH nd_1064747 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Butter Paratha', 'butter paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Butter Paratha', 'butter paratha', 'primary' FROM nd_1064747;

WITH nd_35875262 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Naan', 'naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Naan', 'naan', 'primary' FROM nd_35875262;

WITH nd_69249143 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Butter Naan', 'butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary' FROM nd_69249143;

WITH nd_17464754 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Stuff Paratha', 'stuff paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'stuff paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Stuff Paratha', 'stuff paratha', 'primary' FROM nd_17464754;

WITH nd_28748334 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Aloo Paratha', 'aloo paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Aloo Paratha', 'aloo paratha', 'primary' FROM nd_28748334;

WITH nd_12103903 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Kulcha', 'kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Kulcha', 'kulcha', 'primary' FROM nd_12103903;

WITH nd_76913658 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Masala Kulcha', 'masala kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Masala Kulcha', 'masala kulcha', 'primary' FROM nd_76913658;

WITH nd_86050969 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Garlic Naan', 'garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Garlic Naan', 'garlic naan', 'primary' FROM nd_86050969;

WITH nd_39960325 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Non Veg Platter', 'non veg platter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'non veg platter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Non Veg Platter', 'non veg platter', 'primary' FROM nd_39960325;

WITH nd_25768457 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Platter', 'veg platter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg platter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Platter', 'veg platter', 'primary' FROM nd_25768457;

WITH nd_6044003 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Sea Food Platter', 'sea food platter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sea food platter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Sea Food Platter', 'sea food platter', 'primary' FROM nd_6044003;

WITH nd_19312711 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Tandoori (Full)', 'chicken tandoori (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori (Full)', 'chicken tandoori (full)', 'primary' FROM nd_19312711;

WITH nd_25402213 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Tandoori (Half)', 'chicken tandoori (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori (Half)', 'chicken tandoori (half)', 'primary' FROM nd_25402213;

WITH nd_27451215 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fish Tandoori', 'fish tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fish Tandoori', 'fish tandoori', 'primary' FROM nd_27451215;

WITH nd_87970267 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fish Tikka', 'fish tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fish Tikka', 'fish tikka', 'primary' FROM nd_87970267;

WITH nd_84253793 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bangda Tandoori', 'bangda tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bangda Tandoori', 'bangda tandoori', 'primary' FROM nd_84253793;

WITH nd_18685109 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Tikka', 'chicken tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka', 'chicken tikka', 'primary' FROM nd_18685109;

WITH nd_68854508 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Seekh Kabab', 'chicken seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Seekh Kabab', 'chicken seekh kabab', 'primary' FROM nd_68854508;

WITH nd_95527577 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Rozaali Kabab', 'rozaali kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rozaali kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Rozaali Kabab', 'rozaali kabab', 'primary' FROM nd_95527577;

WITH nd_9933543 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Angara Kabab', 'chi angara kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi angara kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Angara Kabab', 'chi angara kabab', 'primary' FROM nd_9933543;

WITH nd_1127314 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Tiranga Kabab', 'chi tiranga kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi tiranga kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Tiranga Kabab', 'chi tiranga kabab', 'primary' FROM nd_1127314;

WITH nd_82891993 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Dilkhush Kabab', 'chi dilkhush kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi dilkhush kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Dilkhush Kabab', 'chi dilkhush kabab', 'primary' FROM nd_82891993;

WITH nd_49436842 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Kalmi Kabab', 'chi kalmi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi kalmi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Kalmi Kabab', 'chi kalmi kabab', 'primary' FROM nd_49436842;

WITH nd_14329002 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Pahadi Kabab', 'chicken pahadi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Pahadi Kabab', 'chicken pahadi kabab', 'primary' FROM nd_14329002;

WITH nd_14687595 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Tangdi Kabab', 'chicken tangdi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tangdi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tangdi Kabab', 'chicken tangdi kabab', 'primary' FROM nd_14687595;

WITH nd_68943608 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Aloo Tandoori', 'aloo tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Aloo Tandoori', 'aloo tandoori', 'primary' FROM nd_68943608;

WITH nd_83997193 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Tikka', 'paneer tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka', 'paneer tikka', 'primary' FROM nd_83997193;

WITH nd_93872916 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Pahadi Tikka', 'paneer pahadi tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pahadi tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Pahadi Tikka', 'paneer pahadi tikka', 'primary' FROM nd_93872916;

WITH nd_51146820 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mushroom Tikka', 'mushroom tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Tikka', 'mushroom tikka', 'primary' FROM nd_51146820;

WITH nd_48465288 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Seekh Kabab', 'veg seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Seekh Kabab', 'veg seekh kabab', 'primary' FROM nd_48465288;

WITH nd_6444477 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Hara Bhara Kabab', 'chicken hara bhara kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hara bhara kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Hara Bhara Kabab', 'chicken hara bhara kabab', 'primary' FROM nd_6444477;

WITH nd_17650847 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Resha Kabab', 'chicken resha kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken resha kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Resha Kabab', 'chicken resha kabab', 'primary' FROM nd_17650847;

WITH nd_53248454 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Liver Tandoori', 'liver tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'liver tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Liver Tandoori', 'liver tandoori', 'primary' FROM nd_53248454;

WITH nd_35541788 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Sadabahar Kabab', 'sadabahar kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sadabahar kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Sadabahar Kabab', 'sadabahar kabab', 'primary' FROM nd_35541788;

WITH nd_25744651 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Snacks', 'snacks'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'snacks')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Snacks', 'snacks', 'primary' FROM nd_25744651;

WITH nd_89400603 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Special Channa Dal', 'special channa dal'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special channa dal')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Special Channa Dal', 'special channa dal', 'primary' FROM nd_89400603;

WITH nd_72949124 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Plain Moong Dal', 'plain moong dal'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain moong dal')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Plain Moong Dal', 'plain moong dal', 'primary' FROM nd_72949124;

WITH nd_28539363 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Special Moong Dal', 'special moong dal'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special moong dal')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Special Moong Dal', 'special moong dal', 'primary' FROM nd_28539363;

WITH nd_80011944 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Roasted Papad', 'roasted papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roasted papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Roasted Papad', 'roasted papad', 'primary' FROM nd_80011944;

WITH nd_94122165 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fried Papad', 'fried papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fried papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fried Papad', 'fried papad', 'primary' FROM nd_94122165;

WITH nd_94140654 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Masala Papad', 'masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary' FROM nd_94140654;

WITH nd_61970829 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Pakoda', 'veg pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Pakoda', 'veg pakoda', 'primary' FROM nd_61970829;

WITH nd_5439096 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Cheese Pakoda', 'cheese pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Cheese Pakoda', 'cheese pakoda', 'primary' FROM nd_5439096;

WITH nd_31375816 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Pakoda', 'paneer pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Pakoda', 'paneer pakoda', 'primary' FROM nd_31375816;

WITH nd_34775302 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Channa Oil Fry', 'channa oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'channa oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Channa Oil Fry', 'channa oil fry', 'primary' FROM nd_34775302;

WITH nd_39867879 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Channa Garlic Oil Fry', 'channa garlic oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'channa garlic oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Channa Garlic Oil Fry', 'channa garlic oil fry', 'primary' FROM nd_39867879;

WITH nd_24075189 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Waffers', 'waffers'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'waffers')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Waffers', 'waffers', 'primary' FROM nd_24075189;

WITH nd_27870941 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Green Salad', 'green salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Green Salad', 'green salad', 'primary' FROM nd_27870941;

WITH nd_13745847 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Aloo Chat', 'aloo chat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo chat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Aloo Chat', 'aloo chat', 'primary' FROM nd_13745847;

WITH nd_88018458 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Garlic Oil Fry', 'garlic oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Garlic Oil Fry', 'garlic oil fry', 'primary' FROM nd_88018458;

WITH nd_80783321 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Finger Chips', 'finger chips'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'finger chips')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Finger Chips', 'finger chips', 'primary' FROM nd_80783321;

WITH nd_76874159 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Cheese Cherry Pineapple', 'cheese cherry pineapple'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese cherry pineapple')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Cheese Cherry Pineapple', 'cheese cherry pineapple', 'primary' FROM nd_76874159;

WITH nd_65509477 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Cheese Plain', 'cheese plain'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese plain')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Cheese Plain', 'cheese plain', 'primary' FROM nd_65509477;

WITH nd_82037881 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Plain', 'paneer plain'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer plain')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Plain', 'paneer plain', 'primary' FROM nd_82037881;

WITH nd_68898395 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Onion Bhajiya', 'onion bhajiya'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion bhajiya')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Onion Bhajiya', 'onion bhajiya', 'primary' FROM nd_68898395;

WITH nd_92443693 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Extras', 'extras'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extras')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Extras', 'extras', 'primary' FROM nd_92443693;

WITH nd_41949237 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Channa Koliwada', 'channa koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'channa koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Channa Koliwada', 'channa koliwada', 'primary' FROM nd_41949237;

WITH nd_79371889 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Channa Garlic Koliwada', 'channa garlic koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'channa garlic koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Channa Garlic Koliwada', 'channa garlic koliwada', 'primary' FROM nd_79371889;

WITH nd_50327529 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Diwani Handi', 'veg diwani handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg diwani handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Diwani Handi', 'veg diwani handi', 'primary' FROM nd_50327529;

WITH nd_97115596 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Makhanwala', 'veg makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Makhanwala', 'veg makhanwala', 'primary' FROM nd_97115596;

WITH nd_38366755 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Kofta', 'veg kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Kofta', 'veg kofta', 'primary' FROM nd_38366755;

WITH nd_70154086 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Hydrabadi', 'panner hydrabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner hydrabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Hydrabadi', 'panner hydrabadi', 'primary' FROM nd_70154086;

WITH nd_8163397 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Lasooni', 'panner lasooni'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner lasooni')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Lasooni', 'panner lasooni', 'primary' FROM nd_8163397;

WITH nd_18400801 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Malai Mehti Matar', 'malai mehti matar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai mehti matar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Malai Mehti Matar', 'malai mehti matar', 'primary' FROM nd_18400801;

WITH nd_89159343 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Dal Fry', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary' FROM nd_89159343;

WITH nd_41545219 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Dal Tadka', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary' FROM nd_41545219;

WITH nd_94728029 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Dal Tadka Kolhapuri', 'dal tadka kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Dal Tadka Kolhapuri', 'dal tadka kolhapuri', 'primary' FROM nd_94728029;

WITH nd_55608445 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Aloo Gobi / Aloo Mutter', 'aloo gobi / aloo mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo gobi / aloo mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Aloo Gobi / Aloo Mutter', 'aloo gobi / aloo mutter', 'primary' FROM nd_55608445;

WITH nd_36550731 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Aloo Palak', 'aloo palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Aloo Palak', 'aloo palak', 'primary' FROM nd_36550731;

WITH nd_7903685 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Plain Palak', 'plain palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Plain Palak', 'plain palak', 'primary' FROM nd_7903685;

WITH nd_68553425 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Palak', 'panner palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Palak', 'panner palak', 'primary' FROM nd_68553425;

WITH nd_19961913 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Channa Masala / Fry / Mix Veg.', 'channa masala / fry / mix veg'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'channa masala / fry / mix veg')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Channa Masala / Fry / Mix Veg.', 'channa masala / fry / mix veg', 'primary' FROM nd_19961913;

WITH nd_79266959 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Masala / Panner Makhan.', 'panner masala / panner makhan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner masala / panner makhan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Masala / Panner Makhan.', 'panner masala / panner makhan', 'primary' FROM nd_79266959;

WITH nd_84702640 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Handi (Full)', 'panner handi (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner handi (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Handi (Full)', 'panner handi (full)', 'primary' FROM nd_84702640;

WITH nd_84386818 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Handi (Half)', 'panner handi (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner handi (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Handi (Half)', 'panner handi (half)', 'primary' FROM nd_84386818;

WITH nd_65303495 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Kurma', 'panner kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Kurma', 'panner kurma', 'primary' FROM nd_65303495;

WITH nd_76138067 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Tikka Masala', 'panner tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Tikka Masala', 'panner tikka masala', 'primary' FROM nd_76138067;

WITH nd_27152476 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mushroom Masala', 'mushroom masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Masala', 'mushroom masala', 'primary' FROM nd_27152476;

WITH nd_83887474 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mushroom Tikka Masala', 'mushroom tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Tikka Masala', 'mushroom tikka masala', 'primary' FROM nd_83887474;

WITH nd_6119271 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Kolhapuri', 'veg kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Kolhapuri', 'veg kolhapuri', 'primary' FROM nd_6119271;

WITH nd_42548411 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Handi (Full)', 'veg handi (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg handi (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Handi (Full)', 'veg handi (full)', 'primary' FROM nd_42548411;

WITH nd_15438307 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Kadai (Half)', 'veg kadai (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kadai (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Kadai (Half)', 'veg kadai (half)', 'primary' FROM nd_15438307;

WITH nd_66518924 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panneer Mutter', 'panneer mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panneer mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panneer Mutter', 'panneer mutter', 'primary' FROM nd_66518924;

WITH nd_79756739 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Gravy / Plain Dal', 'veg gravy / plain dal'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg gravy / plain dal')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Gravy / Plain Dal', 'veg gravy / plain dal', 'primary' FROM nd_79756739;

WITH nd_94859744 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Kurma', 'veg kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Kurma', 'veg kurma', 'primary' FROM nd_94859744;

WITH nd_2750161 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Kadai (Full)', 'panner kadai (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner kadai (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Kadai (Full)', 'panner kadai (full)', 'primary' FROM nd_2750161;

WITH nd_618118 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Kadai (Half)', 'panner kadai (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner kadai (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Kadai (Half)', 'panner kadai (half)', 'primary' FROM nd_618118;

WITH nd_82416059 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Bhurji', 'panner bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Bhurji', 'panner bhurji', 'primary' FROM nd_82416059;

WITH nd_51345192 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Chilly', 'prawns chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Chilly', 'prawns chilly', 'primary' FROM nd_51345192;

WITH nd_74438762 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Crispy', 'prawns crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Crispy', 'prawns crispy', 'primary' FROM nd_74438762;

WITH nd_17061466 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Koliwada', 'prawns koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Koliwada', 'prawns koliwada', 'primary' FROM nd_17061466;

WITH nd_8148392 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns 65 / Prawns Manchurian', 'prawns 65 / prawns manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns 65 / prawns manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns 65 / Prawns Manchurian', 'prawns 65 / prawns manchurian', 'primary' FROM nd_8148392;

WITH nd_1616603 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fish Chilly / Fish Manchurian', 'fish chilly / fish manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish chilly / fish manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fish Chilly / Fish Manchurian', 'fish chilly / fish manchurian', 'primary' FROM nd_1616603;

WITH nd_60930611 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fish Finger', 'fish finger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish finger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fish Finger', 'fish finger', 'primary' FROM nd_60930611;

WITH nd_57003098 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bangda Fry', 'bangda fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bangda Fry', 'bangda fry', 'primary' FROM nd_57003098;

WITH nd_38860242 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bangda Masala / Fry', 'bangda masala / fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda masala / fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bangda Masala / Fry', 'bangda masala / fry', 'primary' FROM nd_38860242;

WITH nd_34614620 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pomfret Fry', 'pomfret fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pomfret Fry', 'pomfret fry', 'primary' FROM nd_34614620;

WITH nd_62457041 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pomfret Masala Fry', 'pomfret masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pomfret Masala Fry', 'pomfret masala fry', 'primary' FROM nd_62457041;

WITH nd_34044965 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Masala / Fry', 'prawns masala / fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns masala / fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Masala / Fry', 'prawns masala / fry', 'primary' FROM nd_34044965;

WITH nd_83085029 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pomfret Tawa Fry', 'pomfret tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pomfret Tawa Fry', 'pomfret tawa fry', 'primary' FROM nd_83085029;

WITH nd_30464884 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bangda Tawa Fry', 'bangda tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bangda Tawa Fry', 'bangda tawa fry', 'primary' FROM nd_30464884;

WITH nd_7907269 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mandeli Fry', 'mandeli fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mandeli fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mandeli Fry', 'mandeli fry', 'primary' FROM nd_7907269;

WITH nd_73073275 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mandeli Rawas', 'mandeli rawas'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mandeli rawas')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mandeli Rawas', 'mandeli rawas', 'primary' FROM nd_73073275;

WITH nd_38622456 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Pulav', 'veg pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Pulav', 'veg pulav', 'primary' FROM nd_38622456;

WITH nd_70416730 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Biryani', 'veg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Biryani', 'veg biryani', 'primary' FROM nd_70416730;

WITH nd_70489665 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Biryani Rice / Jeera Rice', 'biryani rice / jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'biryani rice / jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Biryani Rice / Jeera Rice', 'biryani rice / jeera rice', 'primary' FROM nd_70489665;

WITH nd_70901002 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Steam Rice', 'steam rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Steam Rice', 'steam rice', 'primary' FROM nd_70901002;

WITH nd_8910193 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Plain Rice', 'plain rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Plain Rice', 'plain rice', 'primary' FROM nd_8910193;

WITH nd_65123931 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Jeera Rice (Half)', 'jeera rice (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Jeera Rice (Half)', 'jeera rice (half)', 'primary' FROM nd_65123931;

WITH nd_6997911 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Biryani Rice (Half)', 'biryani rice (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'biryani rice (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Biryani Rice (Half)', 'biryani rice (half)', 'primary' FROM nd_6997911;

WITH nd_54324554 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Steam Rice (Half)', 'steam rice (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Steam Rice (Half)', 'steam rice (half)', 'primary' FROM nd_54324554;

WITH nd_43041882 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Plain Rice (Half)', 'plain rice (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain rice (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Plain Rice (Half)', 'plain rice (half)', 'primary' FROM nd_43041882;

WITH nd_90678540 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Curd Rice', 'curd rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Curd Rice', 'curd rice', 'primary' FROM nd_90678540;

WITH nd_89418780 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panner Biryani', 'panner biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panner Biryani', 'panner biryani', 'primary' FROM nd_89418780;

WITH nd_25080904 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Panneer Pulav', 'panneer pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panneer pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Panneer Pulav', 'panneer pulav', 'primary' FROM nd_25080904;

WITH nd_56755544 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Doi Khichdi', 'doi khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'doi khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Doi Khichdi', 'doi khichdi', 'primary' FROM nd_56755544;

WITH nd_54901284 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Doi Khichdi Tadka', 'doi khichdi tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'doi khichdi tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Doi Khichdi Tadka', 'doi khichdi tadka', 'primary' FROM nd_54901284;

WITH nd_87518063 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Surmai Biryani', 'surmai biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Surmai Biryani', 'surmai biryani', 'primary' FROM nd_87518063;

WITH nd_67265915 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Biryani', 'prawns biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Biryani', 'prawns biryani', 'primary' FROM nd_67265915;

WITH nd_80985761 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pomfret Biryani', 'pomfret biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pomfret Biryani', 'pomfret biryani', 'primary' FROM nd_80985761;

WITH nd_31547513 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Dum Biryani', 'chi dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Dum Biryani', 'chi dum biryani', 'primary' FROM nd_31547513;

WITH nd_68291964 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Dum Biryani', 'mutton dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Dum Biryani', 'mutton dum biryani', 'primary' FROM nd_68291964;

WITH nd_69046882 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chi Hyderabadi Biryani', 'chi hyderabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi hyderabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chi Hyderabadi Biryani', 'chi hyderabadi biryani', 'primary' FROM nd_69046882;

WITH nd_71489381 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hyderabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani', 'primary' FROM nd_71489381;

WITH nd_30734637 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Biryani Boneless', 'chicken biryani boneless'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani boneless')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani Boneless', 'chicken biryani boneless', 'primary' FROM nd_30734637;

WITH nd_15440781 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Roast', 'chicken roast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken roast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Roast', 'chicken roast', 'primary' FROM nd_15440781;

WITH nd_36012500 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Pulao', 'chicken pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Pulao', 'chicken pulao', 'primary' FROM nd_36012500;

WITH nd_6621406 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Biryani', 'mutton biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Biryani', 'mutton biryani', 'primary' FROM nd_6621406;

WITH nd_62375010 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Biryani', 'egg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Biryani', 'egg biryani', 'primary' FROM nd_62375010;

WITH nd_9539645 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Leg Biryani', 'chicken leg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken leg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Leg Biryani', 'chicken leg biryani', 'primary' FROM nd_9539645;

WITH nd_278245 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Tikka Biryani', 'chicken tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Biryani', 'chicken tikka biryani', 'primary' FROM nd_278245;

WITH nd_29936534 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Boiled Egg', 'boiled egg'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boiled egg')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Boiled Egg', 'boiled egg', 'primary' FROM nd_29936534;

WITH nd_62723478 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Onion', 'egg onion'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg onion')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Onion', 'egg onion', 'primary' FROM nd_62723478;

WITH nd_7266792 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Half Fry', 'half fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'half fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Half Fry', 'half fry', 'primary' FROM nd_7266792;

WITH nd_18866236 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Pakoda', 'egg pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Pakoda', 'egg pakoda', 'primary' FROM nd_18866236;

WITH nd_59310333 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Fry Egg', 'fry egg'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fry egg')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Fry Egg', 'fry egg', 'primary' FROM nd_59310333;

WITH nd_32922137 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Bhurji', 'egg bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Bhurji', 'egg bhurji', 'primary' FROM nd_32922137;

WITH nd_51786322 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Boiled Egg Sandwich', 'boiled egg sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boiled egg sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Boiled Egg Sandwich', 'boiled egg sandwich', 'primary' FROM nd_51786322;

WITH nd_76526331 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Omelette Sandwich', 'omelette sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omelette sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Omelette Sandwich', 'omelette sandwich', 'primary' FROM nd_76526331;

WITH nd_72457360 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Boiled Bhurji', 'boiled bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boiled bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Boiled Bhurji', 'boiled bhurji', 'primary' FROM nd_72457360;

WITH nd_86783917 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Toast Bread Butter', 'toast bread butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'toast bread butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Toast Bread Butter', 'toast bread butter', 'primary' FROM nd_86783917;

WITH nd_20365046 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Sandwich', 'veg sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Sandwich', 'veg sandwich', 'primary' FROM nd_20365046;

WITH nd_41472140 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Sandwich', 'chicken sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Sandwich', 'chicken sandwich', 'primary' FROM nd_41472140;

WITH nd_97984993 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bread Slice', 'bread slice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bread slice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bread Slice', 'bread slice', 'primary' FROM nd_97984993;

WITH nd_80931356 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Cheese Sandwich', 'cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Cheese Sandwich', 'cheese sandwich', 'primary' FROM nd_80931356;

WITH nd_72110059 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Bread Butter', 'bread butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bread butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Bread Butter', 'bread butter', 'primary' FROM nd_72110059;

WITH nd_5768029 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Schezwan Fried Rice', 'veg schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'primary' FROM nd_5768029;

WITH nd_94213138 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Fried Rice', 'veg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Fried Rice', 'veg fried rice', 'primary' FROM nd_94213138;

WITH nd_41991171 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Schezwan Triple Fried Rice', 'veg schezwan triple fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan triple fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Triple Fried Rice', 'veg schezwan triple fried rice', 'primary' FROM nd_41991171;

WITH nd_87062553 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Manchurian Rice', 'veg manchurian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Manchurian Rice', 'veg manchurian rice', 'primary' FROM nd_87062553;

WITH nd_93803082 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Noodles', 'veg noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Noodles', 'veg noodles', 'primary' FROM nd_93803082;

WITH nd_76497367 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Schezwan Noodles', 'veg schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Noodles', 'veg schezwan noodles', 'primary' FROM nd_76497367;

WITH nd_57477545 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Schezwan Triple Noodles', 'veg schezwan triple noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan triple noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Triple Noodles', 'veg schezwan triple noodles', 'primary' FROM nd_57477545;

WITH nd_28640003 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Manchurian Noodles', 'veg manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Manchurian Noodles', 'veg manchurian noodles', 'primary' FROM nd_28640003;

WITH nd_61491985 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Fried Rice', 'paneer fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Fried Rice', 'paneer fried rice', 'primary' FROM nd_61491985;

WITH nd_85988305 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Schezwan Rice', 'paneer schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Schezwan Rice', 'paneer schezwan rice', 'primary' FROM nd_85988305;

WITH nd_55537667 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Triple Rice', 'paneer triple rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer triple rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Triple Rice', 'paneer triple rice', 'primary' FROM nd_55537667;

WITH nd_79110336 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Comon Rice', 'veg comon rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg comon rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Comon Rice', 'veg comon rice', 'primary' FROM nd_79110336;

WITH nd_90409181 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Schezwan Comon Rice', 'veg schezwan comon rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan comon rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Comon Rice', 'veg schezwan comon rice', 'primary' FROM nd_90409181;

WITH nd_58168929 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Chilly', 'veg chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Chilly', 'veg chilly', 'primary' FROM nd_58168929;

WITH nd_76507138 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Manchurian', 'veg manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Manchurian', 'veg manchurian', 'primary' FROM nd_76507138;

WITH nd_75035080 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Crispy', 'veg crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Crispy', 'veg crispy', 'primary' FROM nd_75035080;

WITH nd_49094858 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Chinese Bhel', 'veg chinese bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chinese bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Chinese Bhel', 'veg chinese bhel', 'primary' FROM nd_49094858;

WITH nd_91951927 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mushroom Chilly', 'mushroom chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Chilly', 'mushroom chilly', 'primary' FROM nd_91951927;

WITH nd_60450297 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mushroom Manchurian', 'mushroom manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Manchurian', 'mushroom manchurian', 'primary' FROM nd_60450297;

WITH nd_77582423 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mushroom Crispy', 'mushroom crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mushroom Crispy', 'mushroom crispy', 'primary' FROM nd_77582423;

WITH nd_74934452 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Chilly', 'paneer chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Chilly', 'paneer chilly', 'primary' FROM nd_74934452;

WITH nd_82938174 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Manchurian', 'paneer manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Manchurian', 'paneer manchurian', 'primary' FROM nd_82938174;

WITH nd_48692422 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer 65', 'paneer 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer 65', 'paneer 65', 'primary' FROM nd_48692422;

WITH nd_32966474 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Paneer Crispy', 'paneer crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Paneer Crispy', 'paneer crispy', 'primary' FROM nd_32966474;

WITH nd_85203938 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Gold Coins', 'veg gold coins'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg gold coins')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Gold Coins', 'veg gold coins', 'primary' FROM nd_85203938;

WITH nd_15606725 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Spring Roll', 'veg spring roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg spring roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Spring Roll', 'veg spring roll', 'primary' FROM nd_15606725;

WITH nd_17286420 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Hara Bhara Kabab', 'veg hara bhara kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hara bhara kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Hara Bhara Kabab', 'veg hara bhara kabab', 'primary' FROM nd_17286420;

WITH nd_8240216 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg 65', 'veg 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg 65', 'veg 65', 'primary' FROM nd_8240216;

WITH nd_67808624 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Lolypop', 'veg lolypop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg lolypop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Lolypop', 'veg lolypop', 'primary' FROM nd_67808624;

WITH nd_32044086 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Schezwan Triple Nooldes', 'veg schezwan triple nooldes'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan triple nooldes')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Schezwan Triple Nooldes', 'veg schezwan triple nooldes', 'primary' FROM nd_32044086;

WITH nd_22086381 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Chilly', 'chicken chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly', 'chicken chilly', 'primary' FROM nd_22086381;

WITH nd_39932909 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken 65', 'chicken 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken 65', 'chicken 65', 'primary' FROM nd_39932909;

WITH nd_1677647 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Lolypop', 'chicken lolypop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lolypop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Lolypop', 'chicken lolypop', 'primary' FROM nd_1677647;

WITH nd_66563081 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Ginger', 'chicken ginger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken ginger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Ginger', 'chicken ginger', 'primary' FROM nd_66563081;

WITH nd_30869389 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Garlic', 'chicken garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Garlic', 'chicken garlic', 'primary' FROM nd_30869389;

WITH nd_52733842 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Crispy', 'chicken crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Crispy', 'chicken crispy', 'primary' FROM nd_52733842;

WITH nd_737949 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Manchurian', 'chicken manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Manchurian', 'chicken manchurian', 'primary' FROM nd_737949;

WITH nd_31286740 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Oil Fry', 'chicken oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Oil Fry', 'chicken oil fry', 'primary' FROM nd_31286740;

WITH nd_51323484 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Spring Roll', 'chicken spring roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken spring roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Spring Roll', 'chicken spring roll', 'primary' FROM nd_51323484;

WITH nd_43290514 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Chinese Bhel', 'chicken chinese bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chinese bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Chinese Bhel', 'chicken chinese bhel', 'primary' FROM nd_43290514;

WITH nd_45026966 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Pakoda', 'chicken pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Pakoda', 'chicken pakoda', 'primary' FROM nd_45026966;

WITH nd_81032848 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Gold Coin', 'chicken gold coin'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken gold coin')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Gold Coin', 'chicken gold coin', 'primary' FROM nd_81032848;

WITH nd_86522391 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Chilly', 'egg chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Chilly', 'egg chilly', 'primary' FROM nd_86522391;

WITH nd_58471526 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Manchurian', 'egg manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Manchurian', 'egg manchurian', 'primary' FROM nd_58471526;

WITH nd_79074071 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mutton Oil Fry', 'mutton oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mutton Oil Fry', 'mutton oil fry', 'primary' FROM nd_79074071;

WITH nd_95089384 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Fry', 'chicken fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Fry', 'chicken fry', 'primary' FROM nd_95089384;

WITH nd_26090972 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Liver Oil Fry / Mix Fry', 'prawns liver oil fry / mix fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns liver oil fry / mix fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Liver Oil Fry / Mix Fry', 'prawns liver oil fry / mix fry', 'primary' FROM nd_26090972;

WITH nd_13999381 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Lolypop', 'prawns lolypop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns lolypop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Lolypop', 'prawns lolypop', 'primary' FROM nd_13999381;

WITH nd_23011572 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Manchurian', 'prawns manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Manchurian', 'prawns manchurian', 'primary' FROM nd_23011572;

WITH nd_27547859 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Garlic Fry', 'prawns garlic fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns garlic fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Garlic Fry', 'prawns garlic fry', 'primary' FROM nd_27547859;

WITH nd_18596677 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Fry Rice', 'chicken fry rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fry rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Fry Rice', 'chicken fry rice', 'primary' FROM nd_18596677;

WITH nd_22772323 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Schezwan Rice', 'chicken schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Rice', 'chicken schezwan rice', 'primary' FROM nd_22772323;

WITH nd_87775299 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Triple Schezwan Rice', 'chicken triple schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken triple schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Triple Schezwan Rice', 'chicken triple schezwan rice', 'primary' FROM nd_87775299;

WITH nd_35909531 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Fry Rice', 'prawns fry rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns fry rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Fry Rice', 'prawns fry rice', 'primary' FROM nd_35909531;

WITH nd_59398261 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Schezwan Rice', 'prawns schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Schezwan Rice', 'prawns schezwan rice', 'primary' FROM nd_59398261;

WITH nd_25824219 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Triple Schezwan Rice', 'prawns triple schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns triple schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Triple Schezwan Rice', 'prawns triple schezwan rice', 'primary' FROM nd_25824219;

WITH nd_50405518 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Manchurian Rice', 'chicken manchurian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Manchurian Rice', 'chicken manchurian rice', 'primary' FROM nd_50405518;

WITH nd_11517984 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Manchurian Rice', 'prawns manchurian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Manchurian Rice', 'prawns manchurian rice', 'primary' FROM nd_11517984;

WITH nd_32931642 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Noodles', 'chicken noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Noodles', 'chicken noodles', 'primary' FROM nd_32931642;

WITH nd_54701432 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Schezwan Noodles', 'chicken schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'primary' FROM nd_54701432;

WITH nd_7037967 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Triple Schezwan Noodles', 'chicken triple schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken triple schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Triple Schezwan Noodles', 'chicken triple schezwan noodles', 'primary' FROM nd_7037967;

WITH nd_37948503 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Manchurian Noodles', 'chicken manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Manchurian Noodles', 'chicken manchurian noodles', 'primary' FROM nd_37948503;

WITH nd_37580828 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Noodles', 'prawns noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Noodles', 'prawns noodles', 'primary' FROM nd_37580828;

WITH nd_45849500 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Schezwan Noodles', 'prawns schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'primary' FROM nd_45849500;

WITH nd_15108838 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Triple Noodles', 'prawns triple noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns triple noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Triple Noodles', 'prawns triple noodles', 'primary' FROM nd_15108838;

WITH nd_22897411 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Prawns Manchurian Noodles', 'prawns manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Prawns Manchurian Noodles', 'prawns manchurian noodles', 'primary' FROM nd_22897411;

WITH nd_17888315 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Fried Rice', 'egg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Fried Rice', 'egg fried rice', 'primary' FROM nd_17888315;

WITH nd_53063397 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Schezwan Rice', 'egg schezwan rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Schezwan Rice', 'egg schezwan rice', 'primary' FROM nd_53063397;

WITH nd_43974455 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mix Fried Rice', 'mix fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mix Fried Rice', 'mix fried rice', 'primary' FROM nd_43974455;

WITH nd_23879854 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mix Schezwan Fry Rice', 'mix schezwan fry rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix schezwan fry rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mix Schezwan Fry Rice', 'mix schezwan fry rice', 'primary' FROM nd_23879854;

WITH nd_12262414 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mix Noodles', 'mix noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mix Noodles', 'mix noodles', 'primary' FROM nd_12262414;

WITH nd_24260348 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Mix Schezwan Noodles', 'mix schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Mix Schezwan Noodles', 'mix schezwan noodles', 'primary' FROM nd_24260348;

WITH nd_43510291 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Egg Schezwan Triple Rice', 'egg schezwan triple rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan triple rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Egg Schezwan Triple Rice', 'egg schezwan triple rice', 'primary' FROM nd_43510291;

WITH nd_54395540 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Combination Rice', 'chicken combination rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken combination rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Combination Rice', 'chicken combination rice', 'primary' FROM nd_54395540;

WITH nd_32608171 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Chicken Combination Schezwan', 'chicken combination schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken combination schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Chicken Combination Schezwan', 'chicken combination schezwan', 'primary' FROM nd_32608171;

WITH nd_66564948 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Veg Raita (Mix Raita)', 'veg raita (mix raita)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg raita (mix raita)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Veg Raita (Mix Raita)', 'veg raita (mix raita)', 'primary' FROM nd_66564948;

WITH nd_3982107 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Boondi Raita', 'boondi raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boondi raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Boondi Raita', 'boondi raita', 'primary' FROM nd_3982107;

WITH nd_48418539 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Curd', 'curd'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Curd', 'curd', 'primary' FROM nd_48418539;

WITH nd_93916841 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('rohini_other_id_seq'), 'Pineapple Raita', 'pineapple raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('rohini_other_id_seq'), canonical_dish_id, 'en', 'Pineapple Raita', 'pineapple raita', 'primary' FROM nd_93916841;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003001, 400086003, cd.canonical_dish_id, 'Chi Diwani Handi (H)', 'chi diwani handi (h)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi diwani handi (h)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003001, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003001, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003002, 400086003, cd.canonical_dish_id, 'Chi Diwani Handi (F)', 'chi diwani handi (f)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi diwani handi (f)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003002, variant_id, 580, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003002, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003003, 400086003, cd.canonical_dish_id, 'Murg Musollam (H)', 'murg musollam (h)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'murg musollam (h)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003003, variant_id, 410, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003003, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003004, 400086003, cd.canonical_dish_id, 'Murg Musollam (F)', 'murg musollam (f)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'murg musollam (f)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003004, variant_id, 680, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003004, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003005, 400086003, cd.canonical_dish_id, 'Chicken Do Pyaza', 'chicken do pyaza', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken do pyaza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003005, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003005, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003006, 400086003, cd.canonical_dish_id, 'Chi Potiyala', 'chi potiyala', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi potiyala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003006, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003006, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003007, 400086003, cd.canonical_dish_id, 'Mutton Diwani Handi', 'mutton diwani handi', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton diwani handi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003007, variant_id, 500, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003007, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003008, 400086003, cd.canonical_dish_id, 'Mutton Rogan Josh', 'mutton rogan josh', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton rogan josh'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003008, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003008, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003009, 400086003, cd.canonical_dish_id, 'Mutton Do Pyaza', 'mutton do pyaza', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton do pyaza'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003009, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003009, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003010, 400086003, cd.canonical_dish_id, 'Mutton Haryali', 'mutton haryali', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton haryali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003010, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003010, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003011, 400086003, cd.canonical_dish_id, 'Sukka Chicken', 'sukka chicken', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sukka chicken'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003011, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003011, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003012, 400086003, cd.canonical_dish_id, 'Sukka Mutton', 'sukka mutton', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sukka mutton'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003012, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003012, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003013, 400086003, cd.canonical_dish_id, 'Chicken Masala / Masala Fry', 'chicken masala / masala fry', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken masala / masala fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003013, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003013, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003014, 400086003, cd.canonical_dish_id, 'Chicken Masala Boneless', 'chicken masala boneless', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken masala boneless'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003014, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003014, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003015, 400086003, cd.canonical_dish_id, 'Chicken Kolhapuri', 'chicken kolhapuri', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kolhapuri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003015, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003015, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003016, 400086003, cd.canonical_dish_id, 'Chicken Handi (Full)', 'chicken handi (full)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken handi (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003016, variant_id, 430, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003016, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003017, 400086003, cd.canonical_dish_id, 'Chicken Handi (Half)', 'chicken handi (half)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken handi (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003017, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003017, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003018, 400086003, cd.canonical_dish_id, 'Chicken Tikka Masala', 'chicken tikka masala', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003018, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003018, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003019, 400086003, cd.canonical_dish_id, 'Butter Chicken (Full)', 'butter chicken (full)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter chicken (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003019, variant_id, 440, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003019, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003020, 400086003, cd.canonical_dish_id, 'Butter Chicken (Half)', 'butter chicken (half)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter chicken (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003020, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003020, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003021, 400086003, cd.canonical_dish_id, 'Mutton Masala', 'mutton masala', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003021, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003021, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003022, 400086003, cd.canonical_dish_id, 'Mutton Kolhapuri', 'mutton kolhapuri', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton kolhapuri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003022, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003022, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003023, 400086003, cd.canonical_dish_id, 'Mutton Masala Fry', 'mutton masala fry', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton masala fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003023, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003023, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003024, 400086003, cd.canonical_dish_id, 'Mutton Malvani', 'mutton malvani', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton malvani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003024, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003024, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003025, 400086003, cd.canonical_dish_id, 'Mutton Handi (Full)', 'mutton handi (full)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton handi (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003025, variant_id, 580, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003025, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003026, 400086003, cd.canonical_dish_id, 'Mutton Handi (Half)', 'mutton handi (half)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton handi (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003026, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003026, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003027, 400086003, cd.canonical_dish_id, 'Chicken Leg Peas Masala', 'chicken leg peas masala', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken leg peas masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003027, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003027, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003028, 400086003, cd.canonical_dish_id, 'Chicken Gravy', 'chicken gravy', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken gravy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003028, variant_id, 80, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003028, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003029, 400086003, cd.canonical_dish_id, 'Chicken Kofta (Full)', 'chicken kofta (full)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kofta (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003029, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003029, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003030, 400086003, cd.canonical_dish_id, 'Chicken Kofta (Half)', 'chicken kofta (half)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kofta (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003030, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003030, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003031, 400086003, cd.canonical_dish_id, 'Chicken Moghlai', 'chicken moghlai', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken moghlai'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003031, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003031, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003032, 400086003, cd.canonical_dish_id, 'Egg Masala / Fry', 'egg masala / fry', 'NON VEG. DISHES', 400086003001, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg masala / fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003032, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003032, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003033, 400086003, cd.canonical_dish_id, 'Chicken Handi Boneless (Full)', 'chicken handi boneless (full)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken handi boneless (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003033, variant_id, 450, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003033, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "NON VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003034, 400086003, cd.canonical_dish_id, 'Chicken Handi Boneless (Half)', 'chicken handi boneless (half)', 'NON VEG. DISHES', 400086003001, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken handi boneless (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003034, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003034, 400086003, 400086003001, menu_item_id, 400086003001 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003035, 400086003, cd.canonical_dish_id, 'Chi Thali', 'chi thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003035, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003035, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003036, 400086003, cd.canonical_dish_id, 'Chi Komdi Wade', 'chi komdi wade', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi komdi wade'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003036, variant_id, 340, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003036, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003037, 400086003, cd.canonical_dish_id, 'Mutton Thali', 'mutton thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003037, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003037, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003038, 400086003, cd.canonical_dish_id, 'Egg Thali', 'egg thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003038, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003038, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003039, 400086003, cd.canonical_dish_id, 'Surmai Thali', 'surmai thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'surmai thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003039, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003039, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003039, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003040, 400086003, cd.canonical_dish_id, 'Pomfret Thali', 'pomfret thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003040, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003040, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003040, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003041, 400086003, cd.canonical_dish_id, 'Prawns Thali', 'prawns thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003041, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003041, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003041, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003042, 400086003, cd.canonical_dish_id, 'Bombil Thali', 'bombil thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bombil thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003042, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003042, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003042, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003043, 400086003, cd.canonical_dish_id, 'Mandeli Thali', 'mandeli thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mandeli thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003043, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003043, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003043, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003044, 400086003, cd.canonical_dish_id, 'Roavas Thali', 'roavas thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'roavas thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003044, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003044, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003044, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "THALI NON VEG / SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003045, 400086003, cd.canonical_dish_id, 'Bangda Thali', 'bangda thali', 'THALI NON VEG / SEA FOOD', 400086003002, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda thali'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003045, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003045, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003045, 400086003, 400086003001, menu_item_id, 400086003002 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003046, 400086003, cd.canonical_dish_id, 'Fish Fry', 'fish fry', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003046, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003046, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003046, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003047, 400086003, cd.canonical_dish_id, 'Surmai', 'surmai', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'surmai'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003047, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003047, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003047, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003048, 400086003, cd.canonical_dish_id, 'Pomfret', 'pomfret', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003048, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003048, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003048, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003049, 400086003, cd.canonical_dish_id, 'Prawns', 'prawns', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003049, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003049, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003049, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003050, 400086003, cd.canonical_dish_id, 'Bombil', 'bombil', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bombil'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003050, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003050, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003050, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003051, 400086003, cd.canonical_dish_id, 'Mandeli', 'mandeli', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mandeli'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003051, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003051, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003051, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003052, 400086003, cd.canonical_dish_id, 'Raawas', 'raawas', 'TAWA FRY SEA FOOD', 400086003003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'raawas'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003052, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003052, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003052, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003053, 400086003, cd.canonical_dish_id, 'Bangda', 'bangda', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003053, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003053, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003053, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TAWA FRY SEA FOOD" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003054, 400086003, cd.canonical_dish_id, 'Fish Fully Manchi', 'fish fully manchi', 'TAWA FRY SEA FOOD', 400086003003, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish fully manchi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003054, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003054, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003054, 400086003, 400086003001, menu_item_id, 400086003003 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "KORI ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003055, 400086003, cd.canonical_dish_id, 'Chi Kori Roti', 'chi kori roti', 'KORI ROTI', 400086003004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi kori roti'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003055, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003055, 400086003, 400086003001, menu_item_id, 400086003004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "KORI ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003056, 400086003, cd.canonical_dish_id, 'Chi Komdi Wade', 'chi komdi wade', 'KORI ROTI', 400086003004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi komdi wade'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003056, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003056, 400086003, 400086003001, menu_item_id, 400086003004 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHESSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003057, 400086003, cd.canonical_dish_id, 'Chesse Corn Ball', 'chesse corn ball', 'CHESSE', 400086003005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chesse corn ball'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003057, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003057, 400086003, 400086003001, menu_item_id, 400086003005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHESSE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003058, 400086003, cd.canonical_dish_id, 'Chesse Corn Tikki', 'chesse corn tikki', 'CHESSE', 400086003005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chesse corn tikki'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003058, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003058, 400086003, 400086003001, menu_item_id, 400086003005 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003059, 400086003, cd.canonical_dish_id, 'Tandoori Roti', 'tandoori roti', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori roti'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003059, variant_id, 25, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003059, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003060, 400086003, cd.canonical_dish_id, 'Butter Roti', 'butter roti', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003060, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003060, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003061, 400086003, cd.canonical_dish_id, 'Paratha', 'paratha', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003061, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003061, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003062, 400086003, cd.canonical_dish_id, 'Butter Paratha', 'butter paratha', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003062, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003062, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003063, 400086003, cd.canonical_dish_id, 'Naan', 'naan', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003063, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003063, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003064, 400086003, cd.canonical_dish_id, 'Butter Naan', 'butter naan', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003064, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003064, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003065, 400086003, cd.canonical_dish_id, 'Stuff Paratha', 'stuff paratha', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'stuff paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003065, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003065, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003066, 400086003, cd.canonical_dish_id, 'Aloo Paratha', 'aloo paratha', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'aloo paratha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003066, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003066, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003067, 400086003, cd.canonical_dish_id, 'Kulcha', 'kulcha', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kulcha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003067, variant_id, 60, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003067, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003068, 400086003, cd.canonical_dish_id, 'Masala Kulcha', 'masala kulcha', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala kulcha'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003068, variant_id, 80, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003068, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003069, 400086003, cd.canonical_dish_id, 'Garlic Naan', 'garlic naan', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003069, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003069, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003070, 400086003, cd.canonical_dish_id, 'Non Veg Platter', 'non veg platter', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'non veg platter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003070, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003070, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003070, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003071, 400086003, cd.canonical_dish_id, 'Veg Platter', 'veg platter', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg platter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003071, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003071, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003071, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOOR ROTI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003072, 400086003, cd.canonical_dish_id, 'Sea Food Platter', 'sea food platter', 'TANDOOR ROTI', 400086003006, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sea food platter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003072, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003072, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003072, 400086003, 400086003001, menu_item_id, 400086003006 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003073, 400086003, cd.canonical_dish_id, 'Chicken Tandoori (Full)', 'chicken tandoori (full)', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003073, variant_id, 380, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003073, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003074, 400086003, cd.canonical_dish_id, 'Chicken Tandoori (Half)', 'chicken tandoori (half)', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003074, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003074, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003075, 400086003, cd.canonical_dish_id, 'Fish Tandoori', 'fish tandoori', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish tandoori'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003075, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003075, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003076, 400086003, cd.canonical_dish_id, 'Fish Tikka', 'fish tikka', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003076, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003076, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003077, 400086003, cd.canonical_dish_id, 'Bangda Tandoori', 'bangda tandoori', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda tandoori'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003077, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003077, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003078, 400086003, cd.canonical_dish_id, 'Chicken Tikka', 'chicken tikka', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003078, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003078, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003079, 400086003, cd.canonical_dish_id, 'Chicken Seekh Kabab', 'chicken seekh kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken seekh kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003079, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003079, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003080, 400086003, cd.canonical_dish_id, 'Rozaali Kabab', 'rozaali kabab', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rozaali kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003080, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003080, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003081, 400086003, cd.canonical_dish_id, 'Chi Angara Kabab', 'chi angara kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi angara kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003081, variant_id, 430, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003081, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003082, 400086003, cd.canonical_dish_id, 'Chi Tiranga Kabab', 'chi tiranga kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi tiranga kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003082, variant_id, 370, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003082, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003083, 400086003, cd.canonical_dish_id, 'Chi Dilkhush Kabab', 'chi dilkhush kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi dilkhush kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003083, variant_id, 450, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003083, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003084, 400086003, cd.canonical_dish_id, 'Chi Kalmi Kabab', 'chi kalmi kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi kalmi kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003084, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003084, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003085, 400086003, cd.canonical_dish_id, 'Chicken Pahadi Kabab', 'chicken pahadi kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pahadi kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003085, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003085, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003086, 400086003, cd.canonical_dish_id, 'Chicken Tangdi Kabab', 'chicken tangdi kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tangdi kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003086, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003086, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003087, 400086003, cd.canonical_dish_id, 'Aloo Tandoori', 'aloo tandoori', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'aloo tandoori'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003087, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003087, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003088, 400086003, cd.canonical_dish_id, 'Paneer Tikka', 'paneer tikka', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003088, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003088, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003089, 400086003, cd.canonical_dish_id, 'Paneer Pahadi Tikka', 'paneer pahadi tikka', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pahadi tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003089, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003089, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003090, 400086003, cd.canonical_dish_id, 'Mushroom Tikka', 'mushroom tikka', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom tikka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003090, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003090, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003091, 400086003, cd.canonical_dish_id, 'Veg Seekh Kabab', 'veg seekh kabab', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg seekh kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003091, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003091, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003092, 400086003, cd.canonical_dish_id, 'Chicken Hara Bhara Kabab', 'chicken hara bhara kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hara bhara kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003092, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003092, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003093, 400086003, cd.canonical_dish_id, 'Chicken Resha Kabab', 'chicken resha kabab', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken resha kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003093, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003093, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003094, 400086003, cd.canonical_dish_id, 'Liver Tandoori', 'liver tandoori', 'TANDOORI STARTERS', 400086003007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'liver tandoori'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003094, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003094, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "TANDOORI STARTERS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003095, 400086003, cd.canonical_dish_id, 'Sadabahar Kabab', 'sadabahar kabab', 'TANDOORI STARTERS', 400086003007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'sadabahar kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003095, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003095, 400086003, 400086003001, menu_item_id, 400086003007 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003096, 400086003, cd.canonical_dish_id, 'Snacks', 'snacks', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'snacks'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003096, variant_id, 15, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003096, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003097, 400086003, cd.canonical_dish_id, 'Special Channa Dal', 'special channa dal', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'special channa dal'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003097, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003097, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003098, 400086003, cd.canonical_dish_id, 'Plain Moong Dal', 'plain moong dal', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain moong dal'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003098, variant_id, 15, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003098, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003099, 400086003, cd.canonical_dish_id, 'Special Moong Dal', 'special moong dal', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'special moong dal'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003099, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003099, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003100, 400086003, cd.canonical_dish_id, 'Roasted Papad', 'roasted papad', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'roasted papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003100, variant_id, 15, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003100, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003101, 400086003, cd.canonical_dish_id, 'Fried Papad', 'fried papad', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fried papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003101, variant_id, 20, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003101, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003102, 400086003, cd.canonical_dish_id, 'Masala Papad', 'masala papad', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala papad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003102, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003102, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003103, 400086003, cd.canonical_dish_id, 'Veg Pakoda', 'veg pakoda', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg pakoda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003103, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003103, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003104, 400086003, cd.canonical_dish_id, 'Cheese Pakoda', 'cheese pakoda', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese pakoda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003104, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003104, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003105, 400086003, cd.canonical_dish_id, 'Paneer Pakoda', 'paneer pakoda', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pakoda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003105, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003105, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003106, 400086003, cd.canonical_dish_id, 'Channa Oil Fry', 'channa oil fry', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'channa oil fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003106, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003106, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003107, 400086003, cd.canonical_dish_id, 'Channa Garlic Oil Fry', 'channa garlic oil fry', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'channa garlic oil fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003107, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003107, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003108, 400086003, cd.canonical_dish_id, 'Waffers', 'waffers', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'waffers'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003108, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003108, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003109, 400086003, cd.canonical_dish_id, 'Green Salad', 'green salad', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003109, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003109, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003110, 400086003, cd.canonical_dish_id, 'Aloo Chat', 'aloo chat', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'aloo chat'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003110, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003110, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003111, 400086003, cd.canonical_dish_id, 'Garlic Oil Fry', 'garlic oil fry', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic oil fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003111, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003111, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003112, 400086003, cd.canonical_dish_id, 'Finger Chips', 'finger chips', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'finger chips'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003112, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003112, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003113, 400086003, cd.canonical_dish_id, 'Cheese Cherry Pineapple', 'cheese cherry pineapple', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese cherry pineapple'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003113, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003113, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003114, 400086003, cd.canonical_dish_id, 'Cheese Plain', 'cheese plain', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese plain'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003114, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003114, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003115, 400086003, cd.canonical_dish_id, 'Paneer Plain', 'paneer plain', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer plain'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003115, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003115, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003116, 400086003, cd.canonical_dish_id, 'Onion Bhajiya', 'onion bhajiya', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'onion bhajiya'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003116, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003116, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003117, 400086003, cd.canonical_dish_id, 'Extras', 'extras', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'extras'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003117, variant_id, 20, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003117, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003118, 400086003, cd.canonical_dish_id, 'Channa Koliwada', 'channa koliwada', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'channa koliwada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003118, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003118, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "ROHINI SNACKS" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003119, 400086003, cd.canonical_dish_id, 'Channa Garlic Koliwada', 'channa garlic koliwada', 'ROHINI SNACKS', 400086003008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'channa garlic koliwada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003119, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003119, 400086003, 400086003001, menu_item_id, 400086003008 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003120, 400086003, cd.canonical_dish_id, 'Veg Diwani Handi', 'veg diwani handi', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg diwani handi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003120, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003120, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003121, 400086003, cd.canonical_dish_id, 'Veg Makhanwala', 'veg makhanwala', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg makhanwala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003121, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003121, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003122, 400086003, cd.canonical_dish_id, 'Veg Kofta', 'veg kofta', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kofta'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003122, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003122, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003123, 400086003, cd.canonical_dish_id, 'Panner Hydrabadi', 'panner hydrabadi', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner hydrabadi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003123, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003123, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003124, 400086003, cd.canonical_dish_id, 'Panner Lasooni', 'panner lasooni', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner lasooni'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003124, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003124, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003125, 400086003, cd.canonical_dish_id, 'Malai Mehti Matar', 'malai mehti matar', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malai mehti matar'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003125, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003125, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003126, 400086003, cd.canonical_dish_id, 'Dal Fry', 'dal fry', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003126, variant_id, 170, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003126, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003127, 400086003, cd.canonical_dish_id, 'Dal Tadka', 'dal tadka', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003127, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003127, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003128, 400086003, cd.canonical_dish_id, 'Dal Tadka Kolhapuri', 'dal tadka kolhapuri', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal tadka kolhapuri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003128, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003128, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003129, 400086003, cd.canonical_dish_id, 'Aloo Gobi / Aloo Mutter', 'aloo gobi / aloo mutter', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'aloo gobi / aloo mutter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003129, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003129, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003130, 400086003, cd.canonical_dish_id, 'Aloo Palak', 'aloo palak', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'aloo palak'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003130, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003130, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003131, 400086003, cd.canonical_dish_id, 'Plain Palak', 'plain palak', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain palak'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003131, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003131, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003132, 400086003, cd.canonical_dish_id, 'Panner Palak', 'panner palak', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner palak'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003132, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003132, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003133, 400086003, cd.canonical_dish_id, 'Channa Masala / Fry / Mix Veg.', 'channa masala / fry / mix veg', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'channa masala / fry / mix veg'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003133, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003133, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003134, 400086003, cd.canonical_dish_id, 'Panner Masala / Panner Makhan.', 'panner masala / panner makhan', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner masala / panner makhan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003134, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003134, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003135, 400086003, cd.canonical_dish_id, 'Panner Handi (Full)', 'panner handi (full)', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner handi (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003135, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003135, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003136, 400086003, cd.canonical_dish_id, 'Panner Handi (Half)', 'panner handi (half)', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner handi (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003136, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003136, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003137, 400086003, cd.canonical_dish_id, 'Panner Kurma', 'panner kurma', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner kurma'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003137, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003137, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003138, 400086003, cd.canonical_dish_id, 'Panner Tikka Masala', 'panner tikka masala', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner tikka masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003138, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003138, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003139, 400086003, cd.canonical_dish_id, 'Mushroom Masala', 'mushroom masala', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003139, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003139, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003140, 400086003, cd.canonical_dish_id, 'Mushroom Tikka Masala', 'mushroom tikka masala', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom tikka masala'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003140, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003140, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003141, 400086003, cd.canonical_dish_id, 'Veg Kolhapuri', 'veg kolhapuri', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kolhapuri'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003141, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003141, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003142, 400086003, cd.canonical_dish_id, 'Veg Handi (Full)', 'veg handi (full)', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg handi (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003142, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003142, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003143, 400086003, cd.canonical_dish_id, 'Veg Kadai (Half)', 'veg kadai (half)', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kadai (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003143, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003143, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003144, 400086003, cd.canonical_dish_id, 'Panneer Mutter', 'panneer mutter', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panneer mutter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003144, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003144, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003145, 400086003, cd.canonical_dish_id, 'Veg Gravy / Plain Dal', 'veg gravy / plain dal', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg gravy / plain dal'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003145, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003145, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003146, 400086003, cd.canonical_dish_id, 'Veg Kurma', 'veg kurma', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kurma'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003146, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003146, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003147, 400086003, cd.canonical_dish_id, 'Panner Kadai (Full)', 'panner kadai (full)', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner kadai (full)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003147, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003147, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003148, 400086003, cd.canonical_dish_id, 'Panner Kadai (Half)', 'panner kadai (half)', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner kadai (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003148, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003148, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003149, 400086003, cd.canonical_dish_id, 'Panner Bhurji', 'panner bhurji', 'VEG. DISHES', 400086003009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner bhurji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003149, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003149, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003149, 400086003, 400086003001, menu_item_id, 400086003009 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003150, 400086003, cd.canonical_dish_id, 'Prawns Chilly', 'prawns chilly', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003150, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003150, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003151, 400086003, cd.canonical_dish_id, 'Prawns Crispy', 'prawns crispy', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns crispy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003151, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003151, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003152, 400086003, cd.canonical_dish_id, 'Prawns Koliwada', 'prawns koliwada', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns koliwada'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003152, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003152, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003153, 400086003, cd.canonical_dish_id, 'Prawns 65 / Prawns Manchurian', 'prawns 65 / prawns manchurian', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns 65 / prawns manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003153, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003153, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003154, 400086003, cd.canonical_dish_id, 'Fish Chilly / Fish Manchurian', 'fish chilly / fish manchurian', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish chilly / fish manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003154, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003154, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003155, 400086003, cd.canonical_dish_id, 'Fish Finger', 'fish finger', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish finger'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003155, variant_id, 400, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003155, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003156, 400086003, cd.canonical_dish_id, 'Bangda Fry', 'bangda fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003156, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003156, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003157, 400086003, cd.canonical_dish_id, 'Bangda Masala / Fry', 'bangda masala / fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda masala / fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003157, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003157, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003158, 400086003, cd.canonical_dish_id, 'Pomfret Fry', 'pomfret fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003158, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003158, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003159, 400086003, cd.canonical_dish_id, 'Pomfret Masala Fry', 'pomfret masala fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret masala fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003159, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003159, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003160, 400086003, cd.canonical_dish_id, 'Prawns Masala / Fry', 'prawns masala / fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns masala / fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003160, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003160, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003161, 400086003, cd.canonical_dish_id, 'Pomfret Tawa Fry', 'pomfret tawa fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret tawa fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003161, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003161, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003162, 400086003, cd.canonical_dish_id, 'Bangda Tawa Fry', 'bangda tawa fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda tawa fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003162, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003162, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003163, 400086003, cd.canonical_dish_id, 'Mandeli Fry', 'mandeli fry', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mandeli fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003163, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003163, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "FISH" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003164, 400086003, cd.canonical_dish_id, 'Mandeli Rawas', 'mandeli rawas', 'FISH', 400086003010, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mandeli rawas'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003164, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003164, 400086003, 400086003001, menu_item_id, 400086003010 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003165, 400086003, cd.canonical_dish_id, 'Veg Pulav', 'veg pulav', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg pulav'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003165, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003165, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003166, 400086003, cd.canonical_dish_id, 'Veg Biryani', 'veg biryani', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003166, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003166, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003167, 400086003, cd.canonical_dish_id, 'Biryani Rice / Jeera Rice', 'biryani rice / jeera rice', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'biryani rice / jeera rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003167, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003167, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003168, 400086003, cd.canonical_dish_id, 'Steam Rice', 'steam rice', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'steam rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003168, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003168, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003169, 400086003, cd.canonical_dish_id, 'Plain Rice', 'plain rice', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003169, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003169, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003170, 400086003, cd.canonical_dish_id, 'Jeera Rice (Half)', 'jeera rice (half)', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jeera rice (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003170, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003170, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003171, 400086003, cd.canonical_dish_id, 'Biryani Rice (Half)', 'biryani rice (half)', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'biryani rice (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003171, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003171, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003172, 400086003, cd.canonical_dish_id, 'Steam Rice (Half)', 'steam rice (half)', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'steam rice (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003172, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003172, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003173, 400086003, cd.canonical_dish_id, 'Plain Rice (Half)', 'plain rice (half)', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'plain rice (half)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003173, variant_id, 60, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003173, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003174, 400086003, cd.canonical_dish_id, 'Curd Rice', 'curd rice', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'curd rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003174, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003174, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003175, 400086003, cd.canonical_dish_id, 'Panner Biryani', 'panner biryani', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panner biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003175, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003175, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003176, 400086003, cd.canonical_dish_id, 'Panneer Pulav', 'panneer pulav', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'panneer pulav'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003176, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003176, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003177, 400086003, cd.canonical_dish_id, 'Doi Khichdi', 'doi khichdi', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'doi khichdi'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003177, variant_id, 180, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003177, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003178, 400086003, cd.canonical_dish_id, 'Doi Khichdi Tadka', 'doi khichdi tadka', 'RICE', 400086003011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'doi khichdi tadka'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003178, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003178, 400086003, 400086003001, menu_item_id, 400086003011 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003179, 400086003, cd.canonical_dish_id, 'Surmai Biryani', 'surmai biryani', 'BIRYANI', 400086003012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'surmai biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003179, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003179, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003179, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003180, 400086003, cd.canonical_dish_id, 'Prawns Biryani', 'prawns biryani', 'BIRYANI', 400086003012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003180, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003180, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003180, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003181, 400086003, cd.canonical_dish_id, 'Pomfret Biryani', 'pomfret biryani', 'BIRYANI', 400086003012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003181, menu_item_id, 'As per size', 'market_price', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, effective_from, source_id, verification_status_code) SELECT 400086003181, variant_id, NULL::NUMERIC(12,2), TRUE, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003181, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003182, 400086003, cd.canonical_dish_id, 'Chi Dum Biryani', 'chi dum biryani', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi dum biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003182, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003182, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003183, 400086003, cd.canonical_dish_id, 'Mutton Dum Biryani', 'mutton dum biryani', 'BIRYANI', 400086003012, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton dum biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003183, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003183, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003184, 400086003, cd.canonical_dish_id, 'Chi Hyderabadi Biryani', 'chi hyderabadi biryani', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi hyderabadi biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003184, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003184, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003185, 400086003, cd.canonical_dish_id, 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani', 'BIRYANI', 400086003012, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton hyderabadi biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003185, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003185, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003186, 400086003, cd.canonical_dish_id, 'Chicken Biryani Boneless', 'chicken biryani boneless', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken biryani boneless'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003186, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003186, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003187, 400086003, cd.canonical_dish_id, 'Chicken Roast', 'chicken roast', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken roast'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003187, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003187, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003188, 400086003, cd.canonical_dish_id, 'Chicken Pulao', 'chicken pulao', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pulao'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003188, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003188, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003189, 400086003, cd.canonical_dish_id, 'Mutton Biryani', 'mutton biryani', 'BIRYANI', 400086003012, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003189, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003189, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003190, 400086003, cd.canonical_dish_id, 'Egg Biryani', 'egg biryani', 'BIRYANI', 400086003012, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003190, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003190, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003191, 400086003, cd.canonical_dish_id, 'Prawns Biryani', 'prawns biryani', 'BIRYANI', 400086003012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003191, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003191, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003192, 400086003, cd.canonical_dish_id, 'Chicken Leg Biryani', 'chicken leg biryani', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken leg biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003192, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003192, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "BIRYANI" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003193, 400086003, cd.canonical_dish_id, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'BIRYANI', 400086003012, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka biryani'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003193, variant_id, 350, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003193, 400086003, 400086003001, menu_item_id, 400086003012 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003194, 400086003, cd.canonical_dish_id, 'Egg Masala / Fry', 'egg masala / fry', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg masala / fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003194, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003194, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003195, 400086003, cd.canonical_dish_id, 'Boiled Egg', 'boiled egg', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'boiled egg'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003195, variant_id, 30, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003195, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003196, 400086003, cd.canonical_dish_id, 'Egg Onion', 'egg onion', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg onion'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003196, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003196, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003197, 400086003, cd.canonical_dish_id, 'Half Fry', 'half fry', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'half fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003197, variant_id, 40, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003197, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003198, 400086003, cd.canonical_dish_id, 'Egg Pakoda', 'egg pakoda', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg pakoda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003198, variant_id, 130, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003198, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003199, 400086003, cd.canonical_dish_id, 'Fry Egg', 'fry egg', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fry egg'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003199, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003199, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003200, 400086003, cd.canonical_dish_id, 'Egg Bhurji', 'egg bhurji', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg bhurji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003200, variant_id, 90, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003200, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003201, 400086003, cd.canonical_dish_id, 'Boiled Egg Sandwich', 'boiled egg sandwich', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'boiled egg sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003201, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003201, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003202, 400086003, cd.canonical_dish_id, 'Omelette Sandwich', 'omelette sandwich', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'omelette sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003202, variant_id, 120, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003202, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003203, 400086003, cd.canonical_dish_id, 'Boiled Bhurji', 'boiled bhurji', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'boiled bhurji'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003203, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003203, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003204, 400086003, cd.canonical_dish_id, 'Toast Bread Butter', 'toast bread butter', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'toast bread butter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003204, variant_id, 70, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003204, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003205, 400086003, cd.canonical_dish_id, 'Veg Sandwich', 'veg sandwich', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003205, variant_id, 80, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003205, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003206, 400086003, cd.canonical_dish_id, 'Chicken Sandwich', 'chicken sandwich', 'EGG DISHES', 400086003013, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003206, variant_id, 160, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003206, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003207, 400086003, cd.canonical_dish_id, 'Bread Slice', 'bread slice', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bread slice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003207, variant_id, 20, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003207, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003208, 400086003, cd.canonical_dish_id, 'Cheese Sandwich', 'cheese sandwich', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese sandwich'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003208, variant_id, 140, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003208, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "EGG DISHES" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003209, 400086003, cd.canonical_dish_id, 'Bread Butter', 'bread butter', 'EGG DISHES', 400086003013, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bread butter'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003209, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003209, 400086003, 400086003001, menu_item_id, 400086003013 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003210, 400086003, cd.canonical_dish_id, 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003210, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003210, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003211, 400086003, cd.canonical_dish_id, 'Veg Fried Rice', 'veg fried rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003211, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003211, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003212, 400086003, cd.canonical_dish_id, 'Veg Schezwan Triple Fried Rice', 'veg schezwan triple fried rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan triple fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003212, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003212, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003213, 400086003, cd.canonical_dish_id, 'Veg Manchurian Rice', 'veg manchurian rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg manchurian rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003213, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003213, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003214, 400086003, cd.canonical_dish_id, 'Veg Noodles', 'veg noodles', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003214, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003214, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003215, 400086003, cd.canonical_dish_id, 'Veg Schezwan Noodles', 'veg schezwan noodles', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003215, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003215, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003216, 400086003, cd.canonical_dish_id, 'Veg Schezwan Triple Noodles', 'veg schezwan triple noodles', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan triple noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003216, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003216, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003217, 400086003, cd.canonical_dish_id, 'Veg Manchurian Noodles', 'veg manchurian noodles', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg manchurian noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003217, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003217, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003218, 400086003, cd.canonical_dish_id, 'Paneer Fried Rice', 'paneer fried rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003218, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003218, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003219, 400086003, cd.canonical_dish_id, 'Paneer Schezwan Rice', 'paneer schezwan rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003219, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003219, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003220, 400086003, cd.canonical_dish_id, 'Paneer Triple Rice', 'paneer triple rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer triple rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003220, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003220, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003221, 400086003, cd.canonical_dish_id, 'Veg Comon Rice', 'veg comon rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg comon rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003221, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003221, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003222, 400086003, cd.canonical_dish_id, 'Veg Schezwan Comon Rice', 'veg schezwan comon rice', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan comon rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003222, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003222, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003223, 400086003, cd.canonical_dish_id, 'Veg Chilly', 'veg chilly', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003223, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003223, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003224, 400086003, cd.canonical_dish_id, 'Veg Manchurian', 'veg manchurian', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003224, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003224, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003225, 400086003, cd.canonical_dish_id, 'Veg Crispy', 'veg crispy', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg crispy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003225, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003225, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003226, 400086003, cd.canonical_dish_id, 'Veg Chinese Bhel', 'veg chinese bhel', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg chinese bhel'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003226, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003226, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003227, 400086003, cd.canonical_dish_id, 'Mushroom Chilly', 'mushroom chilly', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003227, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003227, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003228, 400086003, cd.canonical_dish_id, 'Mushroom Manchurian', 'mushroom manchurian', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003228, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003228, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003229, 400086003, cd.canonical_dish_id, 'Mushroom Crispy', 'mushroom crispy', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom crispy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003229, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003229, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003230, 400086003, cd.canonical_dish_id, 'Paneer Chilly', 'paneer chilly', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003230, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003230, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003231, 400086003, cd.canonical_dish_id, 'Paneer Manchurian', 'paneer manchurian', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003231, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003231, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003232, 400086003, cd.canonical_dish_id, 'Paneer 65', 'paneer 65', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003232, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003232, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003233, 400086003, cd.canonical_dish_id, 'Paneer Crispy', 'paneer crispy', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer crispy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003233, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003233, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003234, 400086003, cd.canonical_dish_id, 'Veg Gold Coins', 'veg gold coins', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg gold coins'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003234, variant_id, 240, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003234, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003235, 400086003, cd.canonical_dish_id, 'Veg Spring Roll', 'veg spring roll', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg spring roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003235, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003235, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003236, 400086003, cd.canonical_dish_id, 'Veg Hara Bhara Kabab', 'veg hara bhara kabab', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg hara bhara kabab'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003236, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003236, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003237, 400086003, cd.canonical_dish_id, 'Veg 65', 'veg 65', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg 65'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003237, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003237, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003238, 400086003, cd.canonical_dish_id, 'Veg Lolypop', 'veg lolypop', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg lolypop'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003238, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003238, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "VEG. CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003239, 400086003, cd.canonical_dish_id, 'Veg Schezwan Triple Nooldes', 'veg schezwan triple nooldes', 'VEG. CHINESE', 400086003014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan triple nooldes'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003239, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003239, 400086003, 400086003001, menu_item_id, 400086003014 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003240, 400086003, cd.canonical_dish_id, 'Chicken Chilly', 'chicken chilly', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003240, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003240, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003241, 400086003, cd.canonical_dish_id, 'Chicken 65', 'chicken 65', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken 65'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003241, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003241, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003242, 400086003, cd.canonical_dish_id, 'Chicken Lolypop', 'chicken lolypop', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lolypop'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003242, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003242, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003243, 400086003, cd.canonical_dish_id, 'Chicken Ginger', 'chicken ginger', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken ginger'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003243, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003243, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003244, 400086003, cd.canonical_dish_id, 'Chicken Garlic', 'chicken garlic', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken garlic'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003244, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003244, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003245, 400086003, cd.canonical_dish_id, 'Chicken Crispy', 'chicken crispy', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken crispy'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003245, variant_id, 210, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003245, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003246, 400086003, cd.canonical_dish_id, 'Chicken Manchurian', 'chicken manchurian', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003246, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003246, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003247, 400086003, cd.canonical_dish_id, 'Chicken Oil Fry', 'chicken oil fry', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken oil fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003247, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003247, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003248, 400086003, cd.canonical_dish_id, 'Chicken Spring Roll', 'chicken spring roll', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken spring roll'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003248, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003248, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003249, 400086003, cd.canonical_dish_id, 'Chicken Chinese Bhel', 'chicken chinese bhel', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken chinese bhel'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003249, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003249, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003250, 400086003, cd.canonical_dish_id, 'Chicken Pakoda', 'chicken pakoda', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pakoda'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003250, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003250, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003251, 400086003, cd.canonical_dish_id, 'Chicken Gold Coin', 'chicken gold coin', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken gold coin'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003251, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003251, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003252, 400086003, cd.canonical_dish_id, 'Egg Chilly', 'egg chilly', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg chilly'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003252, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003252, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003252, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003253, 400086003, cd.canonical_dish_id, 'Egg Manchurian', 'egg manchurian', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003253, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003253, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003253, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003254, 400086003, cd.canonical_dish_id, 'Mutton Oil Fry', 'mutton oil fry', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton oil fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003254, variant_id, 330, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003254, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003255, 400086003, cd.canonical_dish_id, 'Chicken Fry', 'chicken fry', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003255, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003255, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003256, 400086003, cd.canonical_dish_id, 'Prawns Liver Oil Fry / Mix Fry', 'prawns liver oil fry / mix fry', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns liver oil fry / mix fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003256, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003256, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003257, 400086003, cd.canonical_dish_id, 'Prawns Lolypop', 'prawns lolypop', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns lolypop'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003257, variant_id, 110, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003257, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003258, 400086003, cd.canonical_dish_id, 'Prawns Manchurian', 'prawns manchurian', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns manchurian'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003258, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003258, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003258, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHICKEN CHINESE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003259, 400086003, cd.canonical_dish_id, 'Prawns Garlic Fry', 'prawns garlic fry', 'CHICKEN CHINESE', 400086003015, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns garlic fry'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003259, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003259, variant_id, 230, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003259, 400086003, 400086003001, menu_item_id, 400086003015 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003260, 400086003, cd.canonical_dish_id, 'Chicken Fry Rice', 'chicken fry rice', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken fry rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003260, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003260, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003260, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003261, 400086003, cd.canonical_dish_id, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003261, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003261, variant_id, 220, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003261, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003262, 400086003, cd.canonical_dish_id, 'Chicken Triple Schezwan Rice', 'chicken triple schezwan rice', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken triple schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003262, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003262, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003262, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003263, 400086003, cd.canonical_dish_id, 'Prawns Fry Rice', 'prawns fry rice', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns fry rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003263, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003263, variant_id, 270, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003263, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003264, 400086003, cd.canonical_dish_id, 'Prawns Schezwan Rice', 'prawns schezwan rice', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003264, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003264, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003264, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003265, 400086003, cd.canonical_dish_id, 'Prawns Triple Schezwan Rice', 'prawns triple schezwan rice', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns triple schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003265, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003265, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003265, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003266, 400086003, cd.canonical_dish_id, 'Chicken Manchurian Rice', 'chicken manchurian rice', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken manchurian rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003266, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003266, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003266, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003267, 400086003, cd.canonical_dish_id, 'Prawns Manchurian Rice', 'prawns manchurian rice', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns manchurian rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003267, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003267, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003267, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003268, 400086003, cd.canonical_dish_id, 'Chicken Noodles', 'chicken noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003268, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003268, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003268, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003269, 400086003, cd.canonical_dish_id, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken schezwan noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003269, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003269, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003269, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003270, 400086003, cd.canonical_dish_id, 'Chicken Triple Schezwan Noodles', 'chicken triple schezwan noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken triple schezwan noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003270, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003270, variant_id, 290, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003270, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003271, 400086003, cd.canonical_dish_id, 'Chicken Manchurian Noodles', 'chicken manchurian noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken manchurian noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003271, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003271, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003271, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003272, 400086003, cd.canonical_dish_id, 'Prawns Noodles', 'prawns noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003272, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003272, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003272, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003273, 400086003, cd.canonical_dish_id, 'Prawns Schezwan Noodles', 'prawns schezwan noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns schezwan noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003273, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003273, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003273, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003274, 400086003, cd.canonical_dish_id, 'Prawns Triple Noodles', 'prawns triple noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns triple noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003274, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003274, variant_id, 310, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003274, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003275, 400086003, cd.canonical_dish_id, 'Prawns Manchurian Noodles', 'prawns manchurian noodles', 'CHINESE RICE', 400086003016, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns manchurian noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003275, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003275, variant_id, 320, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003275, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003276, 400086003, cd.canonical_dish_id, 'Egg Fried Rice', 'egg fried rice', 'CHINESE RICE', 400086003016, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003276, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003276, variant_id, 190, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003276, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003277, 400086003, cd.canonical_dish_id, 'Egg Schezwan Rice', 'egg schezwan rice', 'CHINESE RICE', 400086003016, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg schezwan rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003277, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003277, variant_id, 200, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003277, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003278, 400086003, cd.canonical_dish_id, 'Mix Fried Rice', 'mix fried rice', 'CHINESE RICE', 400086003016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mix fried rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003278, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003278, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003278, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003279, 400086003, cd.canonical_dish_id, 'Mix Schezwan Fry Rice', 'mix schezwan fry rice', 'CHINESE RICE', 400086003016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mix schezwan fry rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003279, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003279, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003279, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003280, 400086003, cd.canonical_dish_id, 'Mix Noodles', 'mix noodles', 'CHINESE RICE', 400086003016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mix noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003280, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003280, variant_id, 250, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003280, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003281, 400086003, cd.canonical_dish_id, 'Mix Schezwan Noodles', 'mix schezwan noodles', 'CHINESE RICE', 400086003016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mix schezwan noodles'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003281, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003281, variant_id, 260, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003281, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003282, 400086003, cd.canonical_dish_id, 'Egg Schezwan Triple Rice', 'egg schezwan triple rice', 'CHINESE RICE', 400086003016, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg schezwan triple rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003282, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003282, variant_id, 280, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003282, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003283, 400086003, cd.canonical_dish_id, 'Chicken Combination Rice', 'chicken combination rice', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken combination rice'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003283, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003283, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003283, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "CHINESE RICE" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003284, 400086003, cd.canonical_dish_id, 'Chicken Combination Schezwan', 'chicken combination schezwan', 'CHINESE RICE', 400086003016, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken combination schezwan'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003284, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003284, variant_id, 300, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003284, 400086003, 400086003001, menu_item_id, 400086003016 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RAITA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003285, 400086003, cd.canonical_dish_id, 'Veg Raita (Mix Raita)', 'veg raita (mix raita)', 'RAITA', 400086003017, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg raita (mix raita)'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003285, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003285, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003285, 400086003, 400086003001, menu_item_id, 400086003017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RAITA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003286, 400086003, cd.canonical_dish_id, 'Boondi Raita', 'boondi raita', 'RAITA', 400086003017, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'boondi raita'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003286, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003286, variant_id, 100, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003286, 400086003, 400086003001, menu_item_id, 400086003017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RAITA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003287, 400086003, cd.canonical_dish_id, 'Curd', 'curd', 'RAITA', 400086003017, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'curd'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003287, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003287, variant_id, 50, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003287, 400086003, 400086003001, menu_item_id, 400086003017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

-- Source: JSON, "RAITA" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400086003288, 400086003, cd.canonical_dish_id, 'Pineapple Raita', 'pineapple raita', 'RAITA', 400086003017, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pineapple raita'
  RETURNING menu_item_id
),
nv_1 AS (INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default) SELECT 400086003288, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item RETURNING variant_id),
np_1 AS (INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code) SELECT 400086003288, variant_id, 150, (clock_timestamp() AT TIME ZONE 'UTC'), 400086003, 'unverified' FROM nv_1 RETURNING price_id),
nbi AS (INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id) SELECT 400086003288, 400086003, 400086003001, menu_item_id, 400086003017 FROM new_item RETURNING menu_item_id),
isrc AS (INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) SELECT menu_item_id, 400086003, 400086003500, 0.9, 'unverified' FROM new_item RETURNING menu_item_id)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 400086003, 400086003500, 0.9 FROM (SELECT price_id FROM np_1) AS ap;

COMMIT;

-- UNMAPPED: exact closing time is past midnight ("12:00 am" i.e. the stroke
-- of midnight) -- stored as 23:59:59 rather than 00:00 to avoid implying a
-- zero-length window; confirm the intended encoding if this matters downstream.
-- Summary: 1 restaurant, 17 categories, 288 menu items, 285 canonical dishes.